// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {IFragmentFusion} from "../../../src/interfaces/IFragmentFusion.sol";

/**
 * @title TestHelpers Fragments
 * @author ATrnd
 * @notice Fragment operation utilities for test suite
 */
contract TestHelpersFragments is Test {

   /*//////////////////////////////////////////////////////////////
                           CONSTANTS
   //////////////////////////////////////////////////////////////*/

   uint256 private constant MAX_COMPLETION_ATTEMPTS = 200;
   uint256 private constant MAX_BATCH_MINT_COUNT = 50;

   /*//////////////////////////////////////////////////////////////
                           CORE FRAGMENT OPERATIONS
   //////////////////////////////////////////////////////////////*/

   function mintCompleteFragmentSet(
       IFragmentEngine fragmentEngine,
       address user,
       uint256 targetNftId
   ) public returns (uint256[] memory fragmentIds) {
       require(address(fragmentEngine) != address(0), "TestHelpersFragments: FragmentEngine cannot be zero address");
       require(user != address(0), "TestHelpersFragments: User cannot be zero address");

       uint256[] memory tempFragmentIds = new uint256[](4);
       uint256 fragmentCount = 0;
       uint256 attempts = 0;
       uint256 actualTargetNftId = targetNftId;

       vm.startPrank(user);

       while (attempts < MAX_COMPLETION_ATTEMPTS && fragmentCount < 4) {
           attempts++;

           uint256[] memory circulation = fragmentEngine.getNFTsInCirculation();
           if (circulation.length == 0) {
               vm.stopPrank();
               revert("TestHelpersFragments: No NFTs available for minting");
           }

           if (actualTargetNftId > 0) {
               uint256 fragmentsLeft = fragmentEngine.getFragmentsLeftForNFT(actualTargetNftId);
               if (fragmentsLeft == 0 && fragmentCount == 4) {
                   break;
               }
           }

           try fragmentEngine.mint() returns (uint256 tokenId) {
               IFragmentEngine.Fragment memory fragment = fragmentEngine.getFragmentData(tokenId);

               if (actualTargetNftId == 0) {
                   actualTargetNftId = fragment.fragmentNftId;
               }

               if (fragment.fragmentNftId == actualTargetNftId) {
                   tempFragmentIds[fragmentCount] = tokenId;
                   fragmentCount++;
               }

               if (fragmentCount == 4) {
                   uint256 fragmentsLeft = fragmentEngine.getFragmentsLeftForNFT(actualTargetNftId);
                   if (fragmentsLeft == 0) {
                       break;
                   }
               }
           } catch {
               vm.stopPrank();
               revert("TestHelpersFragments: Fragment minting failed - check NFT availability");
           }
       }

       vm.stopPrank();

       if (fragmentCount != 4) {
           revert("TestHelpersFragments: Failed to complete fragment set - check circulation");
       }

       fragmentIds = new uint256[](4);
       for (uint256 i = 0; i < 4; i++) {
           fragmentIds[i] = tempFragmentIds[i];
       }

       _validateFragmentSetConsistency(fragmentEngine, fragmentIds, actualTargetNftId);

       return fragmentIds;
   }

   function burnCompleteFragmentSet(
       IFragmentEngine fragmentEngine,
       address user,
       uint256 targetNftId
   ) public returns (uint256 nftId) {
       uint256[] memory fragmentIds = mintCompleteFragmentSet(fragmentEngine, user, targetNftId);
       require(fragmentIds.length == 4, "TestHelpersFragments: Failed to mint complete set for burning");

       IFragmentEngine.Fragment memory fragment = fragmentEngine.getFragmentData(fragmentIds[0]);
       nftId = fragment.fragmentNftId;

       _validateFragmentOwnership(fragmentEngine, fragmentIds, user);

       uint256 fragmentsLeft = fragmentEngine.getFragmentsLeftForNFT(nftId);
       require(fragmentsLeft == 0, "TestHelpersFragments: Fragment set is not complete for burning");

       vm.startPrank(user);
       bool burnSuccess = fragmentEngine.burnFragmentSet(nftId);
       vm.stopPrank();

       require(burnSuccess, "TestHelpersFragments: Fragment set burn operation failed");

       address burner = fragmentEngine.getFragmentSetBurner(nftId);
       require(burner == user, "TestHelpersFragments: Burn state not recorded correctly");

       return nftId;
   }

   function mintFragments(
       IFragmentEngine fragmentEngine,
       address user,
       uint256 count
   ) public returns (uint256[] memory fragmentIds) {
       require(count > 0, "TestHelpersFragments: Fragment count must be positive");
       require(count <= MAX_BATCH_MINT_COUNT, "TestHelpersFragments: Fragment count exceeds maximum");
       require(address(fragmentEngine) != address(0), "TestHelpersFragments: FragmentEngine cannot be zero address");
       require(user != address(0), "TestHelpersFragments: User cannot be zero address");

       fragmentIds = new uint256[](count);

       vm.startPrank(user);

       for (uint256 i = 0; i < count; i++) {
           uint256[] memory circulation = fragmentEngine.getNFTsInCirculation();
           if (circulation.length == 0) {
               vm.stopPrank();
               uint256[] memory partialResults = new uint256[](i);
               for (uint256 j = 0; j < i; j++) {
                   partialResults[j] = fragmentIds[j];
               }
               return partialResults;
           }

           try fragmentEngine.mint() returns (uint256 tokenId) {
               fragmentIds[i] = tokenId;
           } catch {
               vm.stopPrank();
               uint256[] memory partialResults = new uint256[](i);
               for (uint256 j = 0; j < i; j++) {
                   partialResults[j] = fragmentIds[j];
               }
               return partialResults;
           }
       }

       vm.stopPrank();
       return fragmentIds;
   }

   function transferAllFragmentsOfNFT(
       IFragmentEngine fragmentEngine,
       uint256 nftId,
       address to
   ) public {
       require(address(fragmentEngine) != address(0), "TestHelpersFragments: FragmentEngine cannot be zero address");
       require(to != address(0), "TestHelpersFragments: To address cannot be zero");

       uint256[] memory fragmentTokenIds = fragmentEngine.getFragmentTokenIds(nftId);
       require(fragmentTokenIds.length > 0, "TestHelpersFragments: No fragments found for NFT");

       for (uint256 i = 0; i < fragmentTokenIds.length; i++) {
           address currentOwner = IERC721(address(fragmentEngine)).ownerOf(fragmentTokenIds[i]);
           if (currentOwner != to) {
               _transferFragment(fragmentEngine, currentOwner, to, fragmentTokenIds[i]);
           }
       }
   }

   /*//////////////////////////////////////////////////////////////
                           PRIVATE UTILITIES
   //////////////////////////////////////////////////////////////*/

   function _transferFragment(
       IFragmentEngine fragmentEngine,
       address from,
       address to,
       uint256 tokenId
   ) private {
       require(from != address(0), "TestHelpersFragments: From address cannot be zero");
       require(to != address(0), "TestHelpersFragments: To address cannot be zero");
       require(from != to, "TestHelpersFragments: Cannot transfer to same address");

       address currentOwner = IERC721(address(fragmentEngine)).ownerOf(tokenId);
       require(currentOwner == from, "TestHelpersFragments: From address does not own fragment");

       vm.startPrank(from);
       IERC721(address(fragmentEngine)).transferFrom(from, to, tokenId);
       vm.stopPrank();

       address newOwner = IERC721(address(fragmentEngine)).ownerOf(tokenId);
       require(newOwner == to, "TestHelpersFragments: Fragment transfer failed");
   }

   function _validateFragmentSetConsistency(
       IFragmentEngine fragmentEngine,
       uint256[] memory fragmentIds,
       uint256 expectedNftId
   ) private view {
       require(fragmentIds.length == 4, "TestHelpersFragments: Fragment set must contain exactly 4 fragments");

       bool[5] memory fragmentIdsSeen;

       for (uint256 i = 0; i < fragmentIds.length; i++) {
           IFragmentEngine.Fragment memory fragment = fragmentEngine.getFragmentData(fragmentIds[i]);

           require(
               fragment.fragmentNftId == expectedNftId,
               "TestHelpersFragments: Fragment belongs to different NFT"
           );

           require(
               fragment.fragmentId >= 1 && fragment.fragmentId <= 4,
               "TestHelpersFragments: Invalid fragment ID"
           );
           require(
               !fragmentIdsSeen[fragment.fragmentId],
               "TestHelpersFragments: Duplicate fragment ID in set"
           );

           fragmentIdsSeen[fragment.fragmentId] = true;
       }

       for (uint256 i = 1; i <= 4; i++) {
           require(fragmentIdsSeen[i], "TestHelpersFragments: Missing fragment ID in complete set");
       }
   }

   function _validateFragmentOwnership(
       IFragmentEngine fragmentEngine,
       uint256[] memory fragmentIds,
       address expectedOwner
   ) private view {
       require(fragmentIds.length > 0, "TestHelpersFragments: Cannot validate empty fragment array");
       require(expectedOwner != address(0), "TestHelpersFragments: Expected owner cannot be zero address");

       for (uint256 i = 0; i < fragmentIds.length; i++) {
           address actualOwner = IERC721(address(fragmentEngine)).ownerOf(fragmentIds[i]);
           require(
               actualOwner == expectedOwner,
               "TestHelpersFragments: Fragment not owned by expected address"
           );
       }
   }

}
