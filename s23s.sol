//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {JustRentIt} from "src/JustRentIt.sol";
import {DeployJustRentIt} from "script/DeployJustRentIt.s.sol";

contract TestJustRentIt is Test{
    JustRentIt justRentIt;
    DeployJustRentIt deployer;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    string constant URI = "ipfs://tokenUri";

    function setUp() public{
        deployer = new DeployJustRentIt();
        justRentIt = deployer.run();

        vm.deal(owner, 100 ether);
        vm.deal(user, 100 ether);
    }

    function testMintNftTokenId() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        assert(tokenId == 1);
    }

    function testMintNftCheckItems() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        JustRentIt.Item memory i = justRentIt.getItem(tokenId);

        assert(i.owner == owner);
        assert(i.tokenId == 1);
        assert(i.pricePerHour == 1 ether);
        assert(i.status == JustRentIt.RentalStatus.Available);
        assert(i.listed == true);
        assert(i.rentedUntil == 0);
        assert(i.currentRental == address(0));
    }

    modifier mint(){
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);
        _;
    }

    function testListNft() public{
        vm.startPrank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);
        JustRentIt.Item memory i = justRentIt.getItem(tokenId);
        assert(i.pricePerHour == 1 ether);
        
        justRentIt.listItem(1, 2 ether);
        JustRentIt.Item memory j = justRentIt.getItem(tokenId);
        assert(j.pricePerHour == 2 ether);
        vm.stopPrank();
    }

    function testUnlistNft() public{
        vm.startPrank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        justRentIt.unlistNft(tokenId);
        JustRentIt.Item memory i = justRentIt.getItem(tokenId);
        assert(i.listed == false);
        vm.stopPrank();
    }

    function testRentNftRevertsForLessAmount() public mint{
        vm.startPrank(user);
        vm.expectRevert();
        justRentIt.rentNft(1, 2, 1 ether);
    }

    function testRentNftEverything() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);
        
        JustRentIt.Item memory i = justRentIt.getItem(tokenId);

        assert(i.currentRental == user);
        assert(i.status == JustRentIt.RentalStatus.Rented);
        assert(i.rentedUntil == (block.timestamp + 3 * 1 hours));
        assert(justRentIt.getEscrow(tokenId) == 3 ether);
        assert(justRentIt.getActiveRentals(0) == tokenId);
        assert(justRentIt.userOf(tokenId) == user);
    }

    function testCheckUpkeepReturnsTrue() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);
        
        JustRentIt.Item memory i = justRentIt.getItem(tokenId);

        vm.warp(block.timestamp + 3 hours + 1);
        vm.roll(block.number);

        (bool upkeepNeeded, ) = justRentIt.checkUpkeep("");

        assert(JustRentIt.RentalStatus.Rented == i.status);
        assert(block.timestamp > i.rentedUntil);
        assert(upkeepNeeded == true);
    }

    function testPerformUpkeepIsCalledWhenCheckupkeepIsTrue() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);

        vm.warp(block.timestamp + 3 hours + 1);
        vm.roll(block.number);

        justRentIt.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);

        vm.expectRevert();
        justRentIt.performUpkeep("");
    }

    function testPerformUpkeepEverything() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);

        vm.warp(block.timestamp + 3 hours + 1);
        vm.roll(block.number);

        justRentIt.performUpkeep("");

        JustRentIt.Item memory i = justRentIt.getItem(tokenId);

        assert(justRentIt.getEscrow(tokenId) == 0);
        assert(justRentIt.getOwnerEarnings(owner) == 3 ether);
        assert(justRentIt.isAvailable(tokenId));
        assert(i.status == JustRentIt.RentalStatus.Available);
        assert(i.rentedUntil == 0);
        assert(i.currentRental == address(0));
        assert(justRentIt.getActiveRentalsLength() == 0);
        assert(justRentIt.userOf(tokenId) == address(0));
    }

    function testWithdraw() public{
        vm.prank(owner);
        uint256 tokenId = justRentIt.mintNft(URI, 1 ether);

        vm.prank(user);
        justRentIt.rentNft{value: 3 ether}(tokenId, 3, 3 ether);

        vm.warp(block.timestamp + 3 hours + 1);
        vm.roll(block.number);

        justRentIt.performUpkeep("");

        vm.prank(owner);
        justRentIt.withdraw();

        assert(justRentIt.getOwnerEarnings(owner) == 0);
    }
}
