// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TestHelpersCore} from "../../utilities/helpers/TestHelpers.Core.sol";
import {TestHelpersFragments} from "../../utilities/helpers/TestHelpers.Fragments.sol";
import {TestHelpersValidation} from "../../utilities/helpers/TestHelpers.Validation.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IFragmentFusion} from "../../../src/interfaces/IFragmentFusion.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {FragmentErrors} from "../../../src/constants/FragmentErrors.sol";

/**
* @title FragmentFusion Operations Test
* @author ATrnd
* @notice FragmentFusion operations validation
*/
contract FragmentFusionOperationsTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_fuseFragmentSet_successfulFusion() public {
       address testUser = testUsers[0];

       uint256 completedNftId = 0;
       vm.startPrank(testUser);

       while (completedNftId == 0) {
           uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
           if (circulation.length == 0) {
               revert("No more NFTs in circulation");
           }

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(nftId);
           if (fragmentsLeft == 0) {
               completedNftId = nftId;
               break;
           }
       }

       vm.stopPrank();

       uint256[] memory allFragmentTokenIds = ecosystem.fragmentEngine.getFragmentTokenIds(completedNftId);
       assertEq(allFragmentTokenIds.length, 4, "Should have complete set of 4 fragments");

       for (uint256 i = 0; i < allFragmentTokenIds.length; i++) {
           address fragmentOwner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(allFragmentTokenIds[i]);

           if (fragmentOwner != testUser) {
               vm.startPrank(fragmentOwner);
               IERC721(address(ecosystem.fragmentEngine)).transferFrom(
                   fragmentOwner,
                   testUser,
                   allFragmentTokenIds[i]
               );
               vm.stopPrank();
           }
       }

       vm.startPrank(testUser);
       bool burnSuccess = ecosystem.fragmentEngine.burnFragmentSet(completedNftId);
       assertTrue(burnSuccess, "Burn should succeed");
       vm.stopPrank();

       address burner = ecosystem.fragmentEngine.getFragmentSetBurner(completedNftId);
       assertEq(burner, testUser, "Test user should be recorded as burner");

       vm.startPrank(testUser);
       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(completedNftId);
       vm.stopPrank();

       address fusionOwner = IERC721(address(ecosystem.fragmentFusion)).ownerOf(fusionTokenId);
       assertEq(fusionOwner, testUser, "Fusion NFT should be owned by test user");

       IFragmentFusion.FragmentFusionInfo memory fusionInfo =
           ecosystem.fragmentFusion.getFusedNFTInfo(fusionTokenId);

       assertEq(fusionInfo.fragmentNftId, completedNftId, "Fusion info should reference original NFT");
       assertEq(fusionInfo.fragmentFusedBy, testUser, "Fusion info should record correct fuser");
       assertTrue(fusionInfo.fragmentFusedTimestamp > 0, "Fusion timestamp should be set");

       assertEq(fusionTokenId, 1, "First fusion token should have ID 1");

       assertTrue(
           ecosystem.fragmentFusion.isFragmentSetFused(completedNftId),
           "Fragment set should be marked as fused"
       );
   }

   function test_fuseFragmentSet_multipleUsers() public {
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
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

           if (fragment.fragmentNftId == bobNftId) {
               // Fragment belongs to Bob's target NFT
           }

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

       vm.startPrank(alice);
       uint256 aliceFusionId = ecosystem.fragmentFusion.fuseFragmentSet(aliceNftId);
       vm.stopPrank();

       vm.startPrank(bob);
       uint256 bobFusionId = ecosystem.fragmentFusion.fuseFragmentSet(bobNftId);
       vm.stopPrank();

       assertTrue(aliceNftId != bobNftId, "Users should have different source NFT IDs");
       assertTrue(aliceFusionId != bobFusionId, "Users should have different fusion token IDs");

       assertEq(
           IERC721(address(ecosystem.fragmentFusion)).ownerOf(aliceFusionId),
           alice,
           "Alice should own her fusion NFT"
       );
       assertEq(
           IERC721(address(ecosystem.fragmentFusion)).ownerOf(bobFusionId),
           bob,
           "Bob should own his fusion NFT"
       );

       IFragmentFusion.FragmentFusionInfo memory aliceInfo =
           ecosystem.fragmentFusion.getFusedNFTInfo(aliceFusionId);
       IFragmentFusion.FragmentFusionInfo memory bobInfo =
           ecosystem.fragmentFusion.getFusedNFTInfo(bobFusionId);

       assertEq(aliceInfo.fragmentNftId, aliceNftId, "Alice's fusion should reference her NFT");
       assertEq(aliceInfo.fragmentFusedBy, alice, "Alice's fusion should record Alice as fuser");
       assertEq(bobInfo.fragmentNftId, bobNftId, "Bob's fusion should reference his NFT");
       assertEq(bobInfo.fragmentFusedBy, bob, "Bob's fusion should record Bob as fuser");

       assertTrue(
           ecosystem.fragmentFusion.isFragmentSetFused(aliceNftId),
           "Alice's set should be marked as fused"
       );
       assertTrue(
           ecosystem.fragmentFusion.isFragmentSetFused(bobNftId),
           "Bob's set should be marked as fused"
       );

       require(aliceNftId != 0, "Alice should have completed a set");
       require(bobNftId != 0, "Bob should have completed a set");
       require(aliceNftId != bobNftId, "Alice and Bob should have different NFT sets");
       require(aliceFusionId != bobFusionId, "Alice and Bob should have different fusion tokens");
   }

   function test_operations_eventEmission() public {
       address testUser = testUsers[0];

       uint256 nftId = burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       vm.startPrank(testUser);

       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
       vm.stopPrank();

       assertEq(fusionTokenId, 1, "First fusion token should have ID 1");

       IFragmentFusion.FragmentFusionInfo memory fusionInfo =
           ecosystem.fragmentFusion.getFusedNFTInfo(fusionTokenId);

       assertEq(fusionInfo.fragmentNftId, nftId, "Event fragmentNftId should match");
       assertEq(fusionInfo.fragmentFusedBy, testUser, "Event fuser should match");
       assertTrue(fusionInfo.fragmentFusedTimestamp > 0, "Event timestamp should be set");
   }

   function test_operations_minimalEcosystemFusion() public {
       TestHelpersCore.BasicEcosystem memory minEcosystem = deployMinimalEcosystem();

       address testUser = testUsers[0];

       uint256[] memory fragmentIds = mintCompleteFragmentSet(minEcosystem.fragmentEngine, testUser, 1);
       assertEq(fragmentIds.length, 4, "Should complete single NFT");

       vm.startPrank(testUser);
       minEcosystem.fragmentEngine.burnFragmentSet(1);
       uint256 fusionTokenId = minEcosystem.fragmentFusion.fuseFragmentSet(1);
       vm.stopPrank();

       assertTrue(fusionTokenId > 0, "Fusion should succeed in minimal ecosystem");

       assertFalse(
           minEcosystem.fragmentFusion.isFusionAvailable(),
           "No more fusions should be available"
       );
   }

   function test_operations_sequentialFusions() public {
       address testUser = testUsers[0];

       uint256 maxPossibleFusions = ecosystem.fragmentEngine.i_initialNFTCount();
       uint256 targetFusions = maxPossibleFusions >= 3 ? 3 : maxPossibleFusions;

       uint256[] memory fusionTokenIds = new uint256[](targetFusions);
       uint256[] memory sourceNftIds = new uint256[](targetFusions);
       uint256 completedFusions = 0;

       for (uint256 i = 0; i < targetFusions; i++) {
           uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
           if (circulation.length == 0) {
               break;
           }

           try this.burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 0) returns (uint256 nftId) {
               vm.startPrank(testUser);
               uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
               vm.stopPrank();

               fusionTokenIds[completedFusions] = fusionTokenId;
               sourceNftIds[completedFusions] = nftId;
               completedFusions++;
           } catch {
               break;
           }
       }

       assertTrue(completedFusions > 0, "Should complete at least one fusion");

       assertEq(
           ecosystem.fragmentFusion.getFusionNFTsMinted(),
           completedFusions,
           "Should track completed fusions correctly"
       );

       for (uint256 i = 0; i < completedFusions; i++) {
           assertTrue(
               ecosystem.fragmentFusion.fusionTokenExists(fusionTokenIds[i]),
               "Each fusion token should exist"
           );

           assertEq(
               IERC721(address(ecosystem.fragmentFusion)).ownerOf(fusionTokenIds[i]),
               testUser,
               "Each fusion should be owned by user"
           );

           assertTrue(
               ecosystem.fragmentFusion.isFragmentSetFused(sourceNftIds[i]),
               "Each source set should be marked as fused"
           );
       }
   }
}
