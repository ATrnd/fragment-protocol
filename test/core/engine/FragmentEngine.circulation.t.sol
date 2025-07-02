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
* @title FragmentEngine Circulation Test
* @author ATrnd
* @notice FragmentEngine circulation management validation
*/
contract FragmentEngineCirculationTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_circulation_initialAccuracy() public view {
       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();

       assertEq(circulation.length, ecosystem.nftCount, "Circulation count should match initial NFT count");

       for (uint256 i = 0; i < circulation.length; i++) {
           assertEq(circulation[i], i + 1, "NFT ID should be sequential starting from 1");
       }
   }

   function test_circulation_nftRemovalOnCompletion() public {
       address testUser = testUsers[0];
       uint256 initialCount = ecosystem.fragmentEngine.getNFTsInCirculation().length;

       uint256[] memory trackedNftIds = new uint256[](initialCount);
       uint256[] memory fragmentCounts = new uint256[](initialCount);
       uint256 trackedNftCount = 0;

       vm.startPrank(testUser);

       uint256 completedNftId = 0;
       uint256 totalFragmentsMinted = 0;

       while (true) {
           uint256 circulationBefore = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           totalFragmentsMinted++;

           bool found = false;
           for (uint256 i = 0; i < trackedNftCount; i++) {
               if (trackedNftIds[i] == nftId) {
                   fragmentCounts[i]++;
                   found = true;
                   break;
               }
           }

           if (!found) {
               trackedNftIds[trackedNftCount] = nftId;
               fragmentCounts[trackedNftCount] = 1;
               trackedNftCount++;
           }

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter < circulationBefore) {
               completedNftId = nftId;
               assertEq(circulationAfter, circulationBefore - 1, "Circulation should decrease by exactly 1");
               break;
           }

           if (totalFragmentsMinted > initialCount * 4) {
               revert("Test exceeded expected fragment count - possible infinite loop");
           }
       }

       vm.stopPrank();

       uint256[] memory finalCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();
       assertEq(finalCirculation.length, initialCount - 1, "Circulation should decrease by 1");

       for (uint256 i = 0; i < finalCirculation.length; i++) {
           assertTrue(finalCirculation[i] != completedNftId, "Completed NFT should not be in circulation");
       }

       uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(completedNftId);
       assertEq(fragmentsLeft, 0, "Completed NFT should have 0 fragments left");
   }

   function test_circulation_swapAndPopOperation() public {
       address testUser = testUsers[0];

       mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();

       assertTrue(circulation.length < ecosystem.nftCount, "Circulation should be reduced");

       for (uint256 i = 0; i < circulation.length; i++) {
           assertTrue(circulation[i] > 0, "All circulation elements should be valid NFT IDs");
       }
   }

   function test_circulation_indexMappingAccuracy() public {
       address testUser = testUsers[0];

       ecosystem.fragmentEngine.getNFTsInCirculation();

       mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       uint256[] memory newCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();

       assertNoDuplicates(newCirculation);

       for (uint256 i = 0; i < newCirculation.length; i++) {
           assertTrue(newCirculation[i] > 0, "Remaining NFT IDs should be positive");
           assertTrue(newCirculation[i] <= ecosystem.nftCount, "Remaining NFT IDs should be within range");
       }
   }

   function test_circulation_multipleCompletions() public {
       address testUser = testUsers[0];
       uint256 initialCount = ecosystem.fragmentEngine.getNFTsInCirculation().length;
       uint256 targetCompletions = 3;

       uint256[] memory trackedNftIds = new uint256[](initialCount);
       uint256[] memory fragmentCounts = new uint256[](initialCount);
       uint256 trackedNftCount = 0;

       vm.startPrank(testUser);

       uint256 nftsCompleted = 0;
       uint256 totalFragmentsMinted = 0;

       while (nftsCompleted < targetCompletions && ecosystem.fragmentEngine.getNFTsInCirculation().length > 0) {
           uint256 circulationBefore = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           totalFragmentsMinted++;

           bool found = false;
           for (uint256 i = 0; i < trackedNftCount; i++) {
               if (trackedNftIds[i] == nftId) {
                   fragmentCounts[i]++;
                   found = true;
                   break;
               }
           }

           if (!found) {
               trackedNftIds[trackedNftCount] = nftId;
               fragmentCounts[trackedNftCount] = 1;
               trackedNftCount++;
           }

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter < circulationBefore) {
               nftsCompleted++;
               assertEq(circulationAfter, circulationBefore - 1, "Each completion should decrease circulation by 1");

               uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(nftId);
               assertEq(fragmentsLeft, 0, "Completed NFT should have 0 fragments left");
           }

           if (totalFragmentsMinted > initialCount * 4) {
               break;
           }
       }

       vm.stopPrank();

       uint256 finalCount = ecosystem.fragmentEngine.getNFTsInCirculation().length;
       assertEq(finalCount, initialCount - nftsCompleted, "Circulation should decrease by completed count");

       if (finalCount > 0) {
           vm.startPrank(testUser);
           uint256 testTokenId = ecosystem.fragmentEngine.mint();
           assertTrue(testTokenId > 0, "Should be able to mint from remaining NFTs");
           vm.stopPrank();
       }
   }

   function test_circulation_depletionHandling() public {
       address testUser = testUsers[0];

       while (ecosystem.fragmentEngine.getNFTsInCirculation().length > 0) {
           uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
           uint256 targetNftId = circulation[0];

           vm.startPrank(testUser);
           while (ecosystem.fragmentEngine.getFragmentsLeftForNFT(targetNftId) > 0) {
               uint256 tokenId = ecosystem.fragmentEngine.mint();
               IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

               if (fragment.fragmentNftId != targetNftId) {
                   IERC721(address(ecosystem.fragmentEngine)).transferFrom(testUser, testUsers[1], tokenId);
               }
           }
           vm.stopPrank();
       }

       uint256[] memory finalCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();
       assertEq(finalCirculation.length, 0, "Circulation should be empty");

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable.selector);
       ecosystem.fragmentEngine.mint();
       vm.stopPrank();
   }

   function test_circulation_randomSelectionAfterRemovals() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);

       while (ecosystem.fragmentEngine.getFragmentsLeftForNFT(1) > 0) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

           if (fragment.fragmentNftId != 1) {
               IERC721(address(ecosystem.fragmentEngine)).transferFrom(testUser, testUsers[1], tokenId);
           }
       }

       vm.stopPrank();

       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
       bool nft1InCirculation = false;
       for (uint256 i = 0; i < circulation.length; i++) {
           if (circulation[i] == 1) {
               nft1InCirculation = true;
               break;
           }
       }
       assertFalse(nft1InCirculation, "NFT 1 should be removed from circulation");

       vm.startPrank(testUser);
       uint256 safeMintCount = 3;

       for (uint256 i = 0; i < safeMintCount; i++) {
           uint256[] memory currentCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();
           if (currentCirculation.length == 0) {
               break;
           }

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

           assertTrue(fragment.fragmentNftId != 1, "Should not select completed NFT");
       }

       vm.stopPrank();
   }

   function test_circulation_stateConsistency() public {
       address testUser = testUsers[0];
       uint256 initialCirculation = ecosystem.fragmentEngine.getNFTsInCirculation().length;

       vm.startPrank(testUser);

       uint256 safeFragmentCount = 3;
       for (uint256 i = 0; i < safeFragmentCount; i++) {
           uint256 circulationBefore = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           ecosystem.fragmentEngine.mint();

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           assertEq(circulationAfter, circulationBefore, "Circulation should be unchanged without completions");
       }

       uint256 afterPartialMints = ecosystem.fragmentEngine.getNFTsInCirculation().length;
       assertEq(afterPartialMints, initialCirculation, "Circulation should be unchanged after partial minting");

       uint256[] memory trackedNftIds = new uint256[](initialCirculation);
       uint256[] memory fragmentCounts = new uint256[](initialCirculation);
       uint256 trackedNftCount = 0;

       uint256 totalFragmentsMinted = safeFragmentCount;
       uint256 completedNftId = 0;

       while (true) {
           uint256 circulationBefore = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           totalFragmentsMinted++;

           bool found = false;
           for (uint256 i = 0; i < trackedNftCount; i++) {
               if (trackedNftIds[i] == nftId) {
                   fragmentCounts[i]++;
                   found = true;
                   break;
               }
           }

           if (!found) {
               trackedNftIds[trackedNftCount] = nftId;
               fragmentCounts[trackedNftCount] = 1;
               trackedNftCount++;
           }

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter < circulationBefore) {
               completedNftId = nftId;
               assertEq(circulationAfter, circulationBefore - 1, "Circulation should decrease by exactly 1");
               break;
           }

           if (totalFragmentsMinted > initialCirculation * 4) {
               revert("Test exceeded expected fragment count - possible infinite loop");
           }
       }

       vm.stopPrank();

       uint256 finalCirculation = ecosystem.fragmentEngine.getNFTsInCirculation().length;

       assertEq(finalCirculation, initialCirculation - 1, "Final circulation should be initial minus 1");

       uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(completedNftId);
       assertEq(fragmentsLeft, 0, "Completed NFT should have 0 fragments left");
   }

   function test_circulation_fragmentDistribution() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256[] memory nftFragmentCounts = new uint256[](ecosystem.nftCount + 1);

       for (uint256 i = 0; i < 15; i++) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           nftFragmentCounts[fragment.fragmentNftId]++;
       }

       vm.stopPrank();

       uint256 totalFragments = 0;
       for (uint256 i = 1; i <= ecosystem.nftCount; i++) {
           totalFragments += nftFragmentCounts[i];
           assertTrue(nftFragmentCounts[i] <= 4, "No NFT should have more than 4 fragments");
       }

       assertEq(totalFragments, 15, "Total fragments should match minted count");
   }

   function test_circulation_completeExhaustion() public {
       address testUser = testUsers[0];
       uint256 initialNftCount = ecosystem.fragmentEngine.getNFTsInCirculation().length;

       uint256[] memory trackedNftIds = new uint256[](initialNftCount);
       uint256[] memory fragmentCounts = new uint256[](initialNftCount);
       uint256 trackedNftCount = 0;

       vm.startPrank(testUser);

       uint256 nftsCompleted = 0;
       uint256 totalFragmentsMinted = 0;

       while (ecosystem.fragmentEngine.getNFTsInCirculation().length > 0) {
           uint256 circulationBefore = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           uint256 nftId = fragment.fragmentNftId;

           totalFragmentsMinted++;

           bool found = false;
           for (uint256 i = 0; i < trackedNftCount; i++) {
               if (trackedNftIds[i] == nftId) {
                   fragmentCounts[i]++;
                   found = true;
                   break;
               }
           }

           if (!found) {
               trackedNftIds[trackedNftCount] = nftId;
               fragmentCounts[trackedNftCount] = 1;
               trackedNftCount++;
           }

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter < circulationBefore) {
               nftsCompleted++;
               assertEq(circulationAfter, circulationBefore - 1, "Circulation should decrease by exactly 1 when NFT completes");

               uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(nftId);
               assertEq(fragmentsLeft, 0, "Completed NFT should have 0 fragments left");
           }

           if (totalFragmentsMinted > initialNftCount * 4 + 10) {
               revert("Test exceeded expected fragment count - possible infinite loop");
           }
       }

       vm.stopPrank();

       assertEq(nftsCompleted, initialNftCount, "Should complete all initial NFT IDs");

       uint256[] memory finalCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();
       assertEq(finalCirculation.length, 0, "Circulation should be completely empty");

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable.selector);
       ecosystem.fragmentEngine.mint();
       vm.stopPrank();
   }
}
