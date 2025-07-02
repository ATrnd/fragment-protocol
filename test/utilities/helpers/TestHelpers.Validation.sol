// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {IFragmentFusion} from "../../../src/interfaces/IFragmentFusion.sol";

/**
* @title TestHelpers Validation
* @author ATrnd
* @notice Fragment Protocol test validation utilities
*/
contract TestHelpersValidation is Test {

   uint256 private constant BASIC_BURN_GAS_LIMIT = 300_000;

   function assertCompleteFragmentSet(
       IFragmentEngine fragmentEngine,
       uint256 nftId,
       address expectedOwner
   ) public view {
       require(address(fragmentEngine) != address(0), "TestHelpersValidation: FragmentEngine cannot be zero address");
       require(expectedOwner != address(0), "TestHelpersValidation: Expected owner cannot be zero address");

       uint256 fragmentsLeft = fragmentEngine.getFragmentsLeftForNFT(nftId);
       require(fragmentsLeft == 0, "TestHelpersValidation: Fragment set is not complete (missing fragments)");

       uint256[] memory tokenIds = fragmentEngine.getFragmentTokenIds(nftId);
       require(tokenIds.length == 4, "TestHelpersValidation: Fragment set does not have exactly 4 fragments");

       bool[5] memory fragmentIdsSeen;

       for (uint256 i = 0; i < tokenIds.length; i++) {
           address actualOwner = IERC721(address(fragmentEngine)).ownerOf(tokenIds[i]);
           require(
               actualOwner == expectedOwner,
               "TestHelpersValidation: Fragment not owned by expected address"
           );

           IFragmentEngine.Fragment memory fragment = fragmentEngine.getFragmentData(tokenIds[i]);
           require(
               fragment.fragmentNftId == nftId,
               "TestHelpersValidation: Fragment NFT ID does not match expected"
           );
           require(
               fragment.fragmentId >= 1 && fragment.fragmentId <= 4,
               "TestHelpersValidation: Invalid fragment ID (must be 1-4)"
           );

           require(
               !fragmentIdsSeen[fragment.fragmentId],
               "TestHelpersValidation: Duplicate fragment ID found in set"
           );
           fragmentIdsSeen[fragment.fragmentId] = true;
       }

       for (uint256 i = 1; i <= 4; i++) {
           require(
               fragmentIdsSeen[i],
               "TestHelpersValidation: Missing fragment ID in complete set"
           );
       }
   }

   function assertFragmentSetBurned(
       IFragmentEngine fragmentEngine,
       uint256 nftId,
       address expectedBurner
   ) public view {
       require(address(fragmentEngine) != address(0), "TestHelpersValidation: FragmentEngine cannot be zero address");
       require(expectedBurner != address(0), "TestHelpersValidation: Expected burner cannot be zero address");

       address actualBurner = fragmentEngine.getFragmentSetBurner(nftId);
       require(
           actualBurner == expectedBurner,
           "TestHelpersValidation: Fragment set not burned by expected address"
       );

       IFragmentEngine.BurnInfo memory burnInfo = fragmentEngine.getFragmentSetBurnInfo(nftId);
       require(
           burnInfo.burner == expectedBurner,
           "TestHelpersValidation: Burn info burner address incorrect"
       );
       require(
           burnInfo.burnTimestamp > 0,
           "TestHelpersValidation: Burn timestamp not set"
       );

       require(
           fragmentEngine.isFragmentSetBurnedByAddress(nftId, expectedBurner),
           "TestHelpersValidation: Fragment set burn not confirmed for address"
       );
   }

   function assertFusionNFTCreated(
       IFragmentFusion fragmentFusion,
       uint256 fusionTokenId,
       uint256 originalNftId,
       address expectedFuser
   ) public view {
       require(address(fragmentFusion) != address(0), "TestHelpersValidation: FragmentFusion cannot be zero address");
       require(expectedFuser != address(0), "TestHelpersValidation: Expected fuser cannot be zero address");

       address fusionOwner = IERC721(address(fragmentFusion)).ownerOf(fusionTokenId);
       require(
           fusionOwner == expectedFuser,
           "TestHelpersValidation: Fusion NFT not owned by expected fuser"
       );

       IFragmentFusion.FragmentFusionInfo memory fusionInfo = fragmentFusion.getFusedNFTInfo(fusionTokenId);
       require(
           fusionInfo.fragmentNftId == originalNftId,
           "TestHelpersValidation: Fusion info original NFT ID incorrect"
       );
       require(
           fusionInfo.fragmentFusedBy == expectedFuser,
           "TestHelpersValidation: Fusion info fuser address incorrect"
       );
       require(
           fusionInfo.fragmentFusedTimestamp > 0,
           "TestHelpersValidation: Fusion timestamp not set"
       );

       require(
           fragmentFusion.isFragmentSetFused(originalNftId),
           "TestHelpersValidation: Fragment set not marked as fused"
       );

       uint256 lookupFusionId = fragmentFusion.getFusedNftIdByFragmentNftId(originalNftId);
       require(
           lookupFusionId == fusionTokenId,
           "TestHelpersValidation: Reverse lookup fusion ID incorrect"
       );
   }

   function assertCustomGasLimit(
       uint256 actualGas,
       uint256 customLimit,
       uint256 tolerance
   ) public pure {
       require(customLimit > 0, "TestHelpersValidation: Custom limit must be positive");
       require(tolerance <= 100, "TestHelpersValidation: Tolerance cannot exceed 100%");

       uint256 maxAllowed = customLimit + (customLimit * tolerance / 100);
       require(
           actualGas <= maxAllowed,
           "TestHelpersValidation: Gas usage exceeds custom limit"
       );
   }

   function assertNoDuplicates(uint256[] memory array) public pure {
       require(array.length > 0, "TestHelpersValidation: Cannot validate empty array");

       for (uint256 i = 0; i < array.length; i++) {
           for (uint256 j = i + 1; j < array.length; j++) {
               require(
                   array[i] != array[j],
                   "TestHelpersValidation: Duplicate values found in array"
               );
           }
       }
   }

   function assertArrayLength(uint256[] memory array, uint256 expectedLength) public pure {
       require(
           array.length == expectedLength,
           "TestHelpersValidation: Array length does not match expected"
       );
   }

   function assertValidAddresses(address[] memory addresses) public pure {
       require(addresses.length > 0, "TestHelpersValidation: Cannot validate empty address array");

       for (uint256 i = 0; i < addresses.length; i++) {
           require(
               addresses[i] != address(0),
               "TestHelpersValidation: Zero address found in array"
           );

           for (uint256 j = i + 1; j < addresses.length; j++) {
               require(
                   addresses[i] != addresses[j],
                   "TestHelpersValidation: Duplicate addresses found in array"
               );
           }
       }
   }

   function assertCompleteWorkflow(
       IFragmentEngine fragmentEngine,
       IFragmentFusion fragmentFusion,
       uint256 nftId,
       address user,
       uint256 fusionTokenId
   ) public view {
       assertFragmentSetBurned(fragmentEngine, nftId, user);
       assertFusionNFTCreated(fragmentFusion, fusionTokenId, nftId, user);

       IFragmentEngine.BurnInfo memory burnInfo = fragmentEngine.getFragmentSetBurnInfo(nftId);
       IFragmentFusion.FragmentFusionInfo memory fusionInfo = fragmentFusion.getFusedNFTInfo(fusionTokenId);

       require(
           burnInfo.burner == fusionInfo.fragmentFusedBy,
           "TestHelpersValidation: Workflow user consistency check failed"
       );
       require(
           fusionInfo.fragmentFusedTimestamp >= burnInfo.burnTimestamp,
           "TestHelpersValidation: Workflow timestamp consistency check failed"
       );
   }
}
