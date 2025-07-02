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
* @title FragmentFusion Validation Test
* @author ATrnd
* @notice FragmentFusion validation functions
*/
contract FragmentFusionValidationTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_verifyFragmentFusionAddress_validBurner() public {
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

       vm.startPrank(testUser);
       ecosystem.fragmentFusion.verifyFragmentFusionAddress(completedNftId);
       vm.stopPrank();
   }

   function test_verifyFragmentFusionAddress_invalidBurner() public {
       address originalBurner = testUsers[0];
       address wrongUser = testUsers[1];

       uint256 completedNftId = 0;
       vm.startPrank(originalBurner);

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

       for (uint256 i = 0; i < allFragmentTokenIds.length; i++) {
           address fragmentOwner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(allFragmentTokenIds[i]);

           if (fragmentOwner != originalBurner) {
               vm.startPrank(fragmentOwner);
               IERC721(address(ecosystem.fragmentEngine)).transferFrom(
                   fragmentOwner,
                   originalBurner,
                   allFragmentTokenIds[i]
               );
               vm.stopPrank();
           }
       }

       vm.startPrank(originalBurner);
       ecosystem.fragmentEngine.burnFragmentSet(completedNftId);
       vm.stopPrank();

       vm.startPrank(wrongUser);
       vm.expectRevert(FragmentErrors.FragmentFusion__NotBurner.selector);
       ecosystem.fragmentFusion.verifyFragmentFusionAddress(completedNftId);
       vm.stopPrank();
   }

   function test_verifyFragmentFusionAddress_unburnedSet() public {
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

       assertEq(
           ecosystem.fragmentEngine.getFragmentsLeftForNFT(completedNftId),
           0,
           "NFT should be complete"
       );
       assertEq(
           ecosystem.fragmentEngine.getFragmentSetBurner(completedNftId),
           address(0),
           "NFT should not be burned yet"
       );

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentFusion__SetNotBurned.selector);
       ecosystem.fragmentFusion.verifyFragmentFusionAddress(completedNftId);
       vm.stopPrank();
   }

   function test_verifyFragmentFusionSet_unfusedSet() public {
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
       ecosystem.fragmentEngine.burnFragmentSet(completedNftId);
       vm.stopPrank();

       assertTrue(
           ecosystem.fragmentEngine.getFragmentSetBurner(completedNftId) != address(0),
           "Set should be burned"
       );
       assertFalse(
           ecosystem.fragmentFusion.isFragmentSetFused(completedNftId),
           "Set should not be fused yet"
       );

       ecosystem.fragmentFusion.verifyFragmentFusionSet(completedNftId);
   }

   function test_verifyFragmentFusionSet_alreadyFused() public {
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
       ecosystem.fragmentEngine.burnFragmentSet(completedNftId);

       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(completedNftId);
       assertTrue(fusionTokenId > 0, "Fusion should succeed");
       vm.stopPrank();

       assertTrue(
           ecosystem.fragmentFusion.isFragmentSetFused(completedNftId),
           "Set should be marked as fused"
       );

       vm.expectRevert(FragmentErrors.FragmentFusion__AlreadyFused.selector);
       ecosystem.fragmentFusion.verifyFragmentFusionSet(completedNftId);
   }

   function test_verifyFragmentFusionMax_belowLimit() public view {
       uint256 currentFusions = ecosystem.fragmentFusion.getFusionNFTsMinted();
       uint256 maxFusions = ecosystem.fragmentFusion.i_maxFragmentFusionNFTs();

       assertTrue(currentFusions < maxFusions, "Should be below fusion limit initially");
       assertTrue(ecosystem.fragmentFusion.isFusionAvailable(), "Fusion should be available");

       ecosystem.fragmentFusion.verifyFragmentFusionMax();
   }

   function test_verifyFragmentFusionMax_atLimit() public {
       uint256 maxFusions = ecosystem.fragmentFusion.i_maxFragmentFusionNFTs();

       uint256 fusionsCompleted = 0;

       for (uint256 userIndex = 0; userIndex < maxFusions && fusionsCompleted < maxFusions; userIndex++) {
           address currentUser = testUsers[userIndex % testUsers.length];

           uint256 completedNftId = 0;
           vm.startPrank(currentUser);

           while (completedNftId == 0) {
               uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
               if (circulation.length == 0) {
                   break;
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

           if (completedNftId == 0) {
               break;
           }

           uint256[] memory allFragmentTokenIds = ecosystem.fragmentEngine.getFragmentTokenIds(completedNftId);

           for (uint256 i = 0; i < allFragmentTokenIds.length; i++) {
               address fragmentOwner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(allFragmentTokenIds[i]);

               if (fragmentOwner != currentUser) {
                   vm.startPrank(fragmentOwner);
                   IERC721(address(ecosystem.fragmentEngine)).transferFrom(
                       fragmentOwner,
                       currentUser,
                       allFragmentTokenIds[i]
                   );
                   vm.stopPrank();
               }
           }

           vm.startPrank(currentUser);
           ecosystem.fragmentEngine.burnFragmentSet(completedNftId);
           ecosystem.fragmentFusion.fuseFragmentSet(completedNftId);
           vm.stopPrank();

           fusionsCompleted++;
       }

       if (fusionsCompleted == maxFusions) {
           assertFalse(
               ecosystem.fragmentFusion.isFusionAvailable(),
               "Fusion should no longer be available"
           );

           assertEq(
               ecosystem.fragmentFusion.getFusionNFTsRemaining(),
               0,
               "No fusion NFTs should remain"
           );

           vm.expectRevert(FragmentErrors.FragmentFusion__MaxFragmentFusionReached.selector);
           ecosystem.fragmentFusion.verifyFragmentFusionMax();
       }
   }

   function test_queryFunctions_fusionStatistics() public {
       address testUser = testUsers[0];

       (uint256 minted, uint256 remaining, uint256 maxAllowed, uint256 nextTokenId) =
           ecosystem.fragmentFusion.getFusionStatistics();

       assertEq(minted, 0, "Initial minted should be 0");
       assertEq(remaining, maxAllowed, "Initial remaining should equal max");
       assertEq(nextTokenId, 1, "Next token ID should start at 1");

       uint256 nftId = burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 0);

       vm.startPrank(testUser);
       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
       vm.stopPrank();

       (uint256 mintedAfter, uint256 remainingAfter, uint256 maxAllowedAfter, uint256 nextTokenIdAfter) =
           ecosystem.fragmentFusion.getFusionStatistics();

       assertEq(mintedAfter, 1, "Minted should increase to 1");
       assertEq(remainingAfter, maxAllowedAfter - 1, "Remaining should decrease by 1");
       assertEq(nextTokenIdAfter, fusionTokenId + 1, "Next token ID should increment");
   }

   function test_queryFunctions_fusionNFTInfo() public {
       address testUser = testUsers[0];

       uint256 nftId = burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 0);

       vm.startPrank(testUser);
       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
       vm.stopPrank();

       IFragmentFusion.FragmentFusionInfo memory fusionInfo =
           ecosystem.fragmentFusion.getFusedNFTInfo(fusionTokenId);

       assertEq(fusionInfo.fragmentNftId, nftId, "Original NFT ID should be correct");
       assertEq(fusionInfo.fragmentFusedBy, testUser, "Fuser address should be correct");
       assertTrue(fusionInfo.fragmentFusedTimestamp > 0, "Timestamp should be set");

       uint256 lookupFusionId = ecosystem.fragmentFusion.getFusedNftIdByFragmentNftId(nftId);
       assertEq(lookupFusionId, fusionTokenId, "Reverse lookup should work");
   }

   function test_queryFunctions_availabilityAndLimits() public view {
       assertTrue(ecosystem.fragmentFusion.isFusionAvailable(), "Should be available initially");

       uint256 remaining = ecosystem.fragmentFusion.getFusionNFTsRemaining();
       uint256 maxAllowed = ecosystem.fragmentFusion.i_maxFragmentFusionNFTs();
       assertEq(remaining, maxAllowed, "Remaining should equal max initially");

       uint256 minted = ecosystem.fragmentFusion.getFusionNFTsMinted();
       assertEq(minted, 0, "Minted should be 0 initially");

       uint256 nextId = ecosystem.fragmentFusion.getNextFusionTokenId();
       assertEq(nextId, 1, "Next ID should be 1 initially");
   }

   function test_queryFunctions_statusChecking() public {
       address testUser = testUsers[0];

       uint256 nftId = burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 0);

       assertFalse(
           ecosystem.fragmentFusion.isFragmentSetFused(nftId),
           "Set should not be fused initially"
       );

       vm.startPrank(testUser);
       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
       vm.stopPrank();

       assertTrue(
           ecosystem.fragmentFusion.isFragmentSetFused(nftId),
           "Set should be fused after fusion"
       );

       assertTrue(
           ecosystem.fragmentFusion.fusionTokenExists(fusionTokenId),
           "Fusion token should exist"
       );

       assertFalse(
           ecosystem.fragmentFusion.fusionTokenExists(999),
           "Non-existent token should not exist"
       );
   }

   function test_queryFunctions_safeQueries() public {
       address testUser = testUsers[0];

       (bool exists1, IFragmentFusion.FragmentFusionInfo memory info1) =
           ecosystem.fragmentFusion.getFusedNFTInfoSafe(999);

       assertFalse(exists1, "Non-existent token should not exist");
       assertEq(info1.fragmentNftId, 0, "Non-existent token info should be empty");

       uint256 nftId = burnCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 0);

       vm.startPrank(testUser);
       uint256 fusionTokenId = ecosystem.fragmentFusion.fuseFragmentSet(nftId);
       vm.stopPrank();

       (bool exists2, IFragmentFusion.FragmentFusionInfo memory info2) =
           ecosystem.fragmentFusion.getFusedNFTInfoSafe(fusionTokenId);

       assertTrue(exists2, "Existing token should exist");
       assertEq(info2.fragmentNftId, nftId, "Existing token info should be correct");
       assertEq(info2.fragmentFusedBy, testUser, "Existing token fuser should be correct");
   }
}
