// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TestHelpersCore} from "../../utilities/helpers/TestHelpers.Core.sol";
import {TestHelpersFragments} from "../../utilities/helpers/TestHelpers.Fragments.sol";
import {TestHelpersValidation} from "../../utilities/helpers/TestHelpers.Validation.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {FragmentEngine} from "../../../src/FragmentEngine.sol";
import {FragmentConstants} from "../../../src/constants/FragmentConstants.sol";
import {FragmentErrors} from "../../../src/constants/FragmentErrors.sol";

/**
* @title FragmentEngine Burning Test
* @author ATrnd
* @notice FragmentEngine burning operations validation
*/
contract FragmentEngineBurningTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_burn_completeSetValidation() public {
       address testUser = testUsers[0];

       uint256[] memory fragmentIds = mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);
       assertEq(fragmentIds.length, 4, "Should have complete set");

       vm.startPrank(testUser);
       uint256 gasBefore = gasleft();
       bool success = ecosystem.fragmentEngine.burnFragmentSet(1);
       uint256 gasUsed = gasBefore - gasleft();
       vm.stopPrank();

       assertTrue(success, "Burn should succeed for complete set");
       assertCustomGasLimit(gasUsed, BASIC_BURN_GAS_LIMIT, 10);

       for (uint256 i = 0; i < fragmentIds.length; i++) {
           vm.expectRevert();
           IERC721(address(ecosystem.fragmentEngine)).ownerOf(fragmentIds[i]);
       }
   }

   function test_burn_authorizationVerification() public {
       address owner = testUsers[0];
       address nonOwner = testUsers[1];

       mintCompleteFragmentSet(ecosystem.fragmentEngine, owner, 1);

       vm.startPrank(nonOwner);
       vm.expectRevert(FragmentErrors.FragmentEngine__NotOwnerOfAll.selector);
       ecosystem.fragmentEngine.burnFragmentSet(1);
       vm.stopPrank();

       vm.startPrank(owner);
       bool success = ecosystem.fragmentEngine.burnFragmentSet(1);
       assertTrue(success, "Owner should be able to burn");
       vm.stopPrank();
   }

   function test_burn_doubleBurnPrevention() public {
       address testUser = testUsers[0];

       mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       vm.startPrank(testUser);
       bool success = ecosystem.fragmentEngine.burnFragmentSet(1);
       assertTrue(success, "First burn should succeed");

       vm.expectRevert(FragmentErrors.FragmentEngine__SetAlreadyBurned.selector);
       ecosystem.fragmentEngine.burnFragmentSet(1);
       vm.stopPrank();
   }

   function test_burn_incompleteSetRejection() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);
       uint256 targetNftId = 0;
       uint256 fragmentCount = 0;

       while (fragmentCount < 3) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

           if (targetNftId == 0) {
               targetNftId = fragment.fragmentNftId;
               fragmentCount = 1;
           } else if (fragment.fragmentNftId == targetNftId) {
               fragmentCount++;
           }
       }

       vm.expectRevert(FragmentErrors.FragmentEngine__IncompleteSet.selector);
       ecosystem.fragmentEngine.burnFragmentSet(targetNftId);
       vm.stopPrank();
   }

   function test_burn_ownershipVerificationAccuracy() public {
       address alice = testUsers[0];
       address bob = testUsers[1];

       uint256[] memory fragmentIds = mintCompleteFragmentSet(ecosystem.fragmentEngine, alice, 1);

       vm.prank(alice);
       IERC721(address(ecosystem.fragmentEngine)).transferFrom(alice, bob, fragmentIds[0]);

       vm.startPrank(alice);
       vm.expectRevert(FragmentErrors.FragmentEngine__NotOwnerOfAll.selector);
       ecosystem.fragmentEngine.burnFragmentSet(1);
       vm.stopPrank();

       vm.prank(bob);
       IERC721(address(ecosystem.fragmentEngine)).transferFrom(bob, alice, fragmentIds[0]);

       vm.startPrank(alice);
       bool success = ecosystem.fragmentEngine.burnFragmentSet(1);
       assertTrue(success, "Alice should be able to burn after reacquiring all fragments");
       vm.stopPrank();
   }

   function test_burn_stateTracking() public {
       address testUser = testUsers[0];

       address burnerBefore = ecosystem.fragmentEngine.getFragmentSetBurner(1);
       assertEq(burnerBefore, address(0), "No burner should be recorded before burn");

       mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       vm.startPrank(testUser);
       ecosystem.fragmentEngine.burnFragmentSet(1);
       vm.stopPrank();

       address burnerAfter = ecosystem.fragmentEngine.getFragmentSetBurner(1);
       assertEq(burnerAfter, testUser, "Burner should be recorded after burn");

       IFragmentEngine.BurnInfo memory burnInfo = ecosystem.fragmentEngine.getFragmentSetBurnInfo(1);
       assertEq(burnInfo.burner, testUser, "Burn info should record correct burner");
       assertTrue(burnInfo.burnTimestamp > 0, "Burn timestamp should be set");
   }

   function test_burn_crossUserIsolation() public {
       address alice = testUsers[0];
       address bob = testUsers[1];

       uint256 aliceNftId = 0;
       vm.startPrank(alice);

       while (aliceNftId == 0) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(nftId);
           if (fragmentsLeft == 0) {
               aliceNftId = nftId;
               break;
           }
       }

       vm.stopPrank();

       vm.startPrank(bob);
       uint256 bobTokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory bobFragment = ecosystem.fragmentEngine.getFragmentData(bobTokenId);
       uint256 bobNftId = bobFragment.fragmentNftId;
       vm.stopPrank();

       transferAllFragmentsOfNFT(ecosystem.fragmentEngine, bobNftId, bob);

       vm.startPrank(bob);
       while (ecosystem.fragmentEngine.getFragmentsLeftForNFT(bobNftId) > 0) {
           ecosystem.fragmentEngine.mint();
           if (ecosystem.fragmentEngine.getFragmentsLeftForNFT(bobNftId) == 0) {
               break;
           }
       }
       vm.stopPrank();

       assertTrue(aliceNftId != 0, "Alice should have completed a set");
       assertTrue(bobNftId != 0, "Bob should have a target set");
       assertTrue(aliceNftId != bobNftId, "Alice and Bob should have different NFT sets");
       assertEq(ecosystem.fragmentEngine.getFragmentsLeftForNFT(bobNftId), 0, "Bob's set should be complete");

       vm.startPrank(alice);
       bool aliceSuccess = ecosystem.fragmentEngine.burnFragmentSet(aliceNftId);
       assertTrue(aliceSuccess, "Alice should be able to burn her set");
       vm.stopPrank();

       vm.startPrank(bob);
       bool bobSuccess = ecosystem.fragmentEngine.burnFragmentSet(bobNftId);
       assertTrue(bobSuccess, "Bob should be able to burn his set");
       vm.stopPrank();

       assertEq(
           ecosystem.fragmentEngine.getFragmentSetBurner(aliceNftId),
           alice,
           "Alice should be recorded as burner for her NFT"
       );
       assertEq(
           ecosystem.fragmentEngine.getFragmentSetBurner(bobNftId),
           bob,
           "Bob should be recorded as burner for his NFT"
       );

       assertFalse(
           ecosystem.fragmentEngine.isFragmentSetBurnedByAddress(aliceNftId, bob),
           "Bob should not be recorded as burner for Alice's NFT"
       );
       assertFalse(
           ecosystem.fragmentEngine.isFragmentSetBurnedByAddress(bobNftId, alice),
           "Alice should not be recorded as burner for Bob's NFT"
       );

       require(aliceNftId != 0, "Alice should have completed a set");
       require(bobNftId != 0, "Bob should have completed a set");
       require(aliceNftId != bobNftId, "Alice and Bob should have different NFT sets");
   }

   function test_burn_infoRecording() public {
       address testUser = testUsers[0];

       mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       uint256 beforeTimestamp = block.timestamp;

       vm.startPrank(testUser);
       ecosystem.fragmentEngine.burnFragmentSet(1);
       vm.stopPrank();

       IFragmentEngine.BurnInfo memory burnInfo = ecosystem.fragmentEngine.getFragmentSetBurnInfo(1);

       assertEq(burnInfo.burner, testUser, "Burn info should record correct burner");
       assertTrue(burnInfo.burnTimestamp >= beforeTimestamp, "Burn timestamp should be current or later");
       assertTrue(burnInfo.burnTimestamp <= block.timestamp, "Burn timestamp should not be in future");

       assertTrue(
           ecosystem.fragmentEngine.isFragmentSetBurnedByAddress(1, testUser),
           "Should confirm burn by specific address"
       );
       assertFalse(
           ecosystem.fragmentEngine.isFragmentSetBurnedByAddress(1, testUsers[1]),
           "Should reject burn by different address"
       );
   }

   function test_burn_fragmentSetVerification() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);
       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       vm.expectRevert(FragmentErrors.FragmentEngine__IncompleteSet.selector);
       ecosystem.fragmentEngine.verifyFragmentSet(fragment.fragmentNftId);
       vm.stopPrank();

       vm.startPrank(testUser);
       while (ecosystem.fragmentEngine.getFragmentsLeftForNFT(fragment.fragmentNftId) > 0) {
           uint256 newTokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory newFragment = ecosystem.fragmentEngine.getFragmentData(newTokenId);

           if (newFragment.fragmentNftId != fragment.fragmentNftId) {
               IERC721(address(ecosystem.fragmentEngine)).transferFrom(testUser, testUsers[1], newTokenId);
           }
       }
       vm.stopPrank();

       vm.startPrank(testUser);
       bool verified = ecosystem.fragmentEngine.verifyFragmentSet(fragment.fragmentNftId);
       assertTrue(verified, "Complete set should verify successfully");
       vm.stopPrank();
   }

   function test_burn_errorConditionHandling() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.burnFragmentSet(999);
       vm.stopPrank();

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.verifyFragmentSet(999);
       vm.stopPrank();
   }
}
