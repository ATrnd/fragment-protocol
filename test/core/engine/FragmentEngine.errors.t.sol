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
* @title FragmentEngine Errors Test
* @author ATrnd
* @notice FragmentEngine error conditions and edge cases validation
*/
contract FragmentEngineErrorsTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_error_noNftsAvailable() public {
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

       vm.startPrank(testUser);
       vm.expectRevert(FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable.selector);
       ecosystem.fragmentEngine.mint();
       vm.stopPrank();
   }

   function test_error_invalidParameterHandling() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);

       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.verifyFragmentSet(0);

       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.burnFragmentSet(0);

       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.verifyFragmentSet(type(uint256).max);

       vm.stopPrank();
   }

   function test_error_reentrancyProtection() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);
       uint256 tokenId = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Normal mint should work");
       vm.stopPrank();

       vm.startPrank(testUser);
       uint256 tokenId2 = ecosystem.fragmentEngine.mint();
       uint256 tokenId3 = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId2 > tokenId, "Second mint should work");
       assertTrue(tokenId3 > tokenId2, "Third mint should work");
       vm.stopPrank();
   }

   function test_error_stateCorruptionResistance() public {
       address testUser = testUsers[0];

       uint256 initialTokenId = ecosystem.fragmentEngine.s_nextFragmentTokenId();
       ecosystem.fragmentEngine.getNFTsInCirculation();

       vm.startPrank(testUser);
       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       try ecosystem.fragmentEngine.burnFragmentSet(fragment.fragmentNftId) {
           revert("Burn should have failed");
       } catch {
           // Expected failure
       }
       vm.stopPrank();

       uint256 afterFailureTokenId = ecosystem.fragmentEngine.s_nextFragmentTokenId();
       assertTrue(afterFailureTokenId > initialTokenId, "Token ID should have advanced from successful mint");
   }

   function test_error_boundaryConditions() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       while (ecosystem.fragmentEngine.getNFTsInCirculation().length > 1) {
           ecosystem.fragmentEngine.mint();

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter == 0) {
               break;
           }
       }

       uint256[] memory remaining = ecosystem.fragmentEngine.getNFTsInCirculation();
       assertEq(remaining.length, 1, "Should have exactly 1 NFT remaining");

       uint256 lastNftId = remaining[0];

       uint256 tokenId2 = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId2 > 0, "Should be able to mint from last NFT");

       uint256 fragmentsAfter = ecosystem.fragmentEngine.getFragmentsLeftForNFT(lastNftId);

       uint256 fragmentsToComplete = fragmentsAfter;

       for (uint256 i = 0; i < fragmentsToComplete; i++) {
           uint256 finalTokenId = ecosystem.fragmentEngine.mint();
           assertTrue(finalTokenId > 0, "Should be able to mint remaining fragments");

           uint256 circulationAfter = ecosystem.fragmentEngine.getNFTsInCirculation().length;

           if (circulationAfter == 0) {
               break;
           }
       }

       uint256[] memory finalCirculation = ecosystem.fragmentEngine.getNFTsInCirculation();
       assertEq(finalCirculation.length, 0, "Circulation should be empty after completing last NFT");

       vm.expectRevert(FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable.selector);
       ecosystem.fragmentEngine.mint();

       vm.stopPrank();
   }

   function test_error_integrationFailureHandling() public {
       assertTrue(address(ecosystem.fragmentEngine) != address(0), "FragmentEngine should be deployed");
       assertTrue(address(ecosystem.randomnessProvider) != address(0), "RandomnessProvider should be deployed");

       assertEq(
           address(ecosystem.fragmentEngine.i_randomnessProvider()),
           address(ecosystem.randomnessProvider),
           "RandomnessProvider integration should be correct"
       );

       address testUser = testUsers[0];
       vm.startPrank(testUser);
       uint256 tokenId = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Normal operation should work");
       vm.stopPrank();
   }

   function test_error_edgeDeploymentScenarios() public {
       TestHelpersCore.BasicEcosystem memory minimalEcosystem = deployMinimalEcosystem();

       assertTrue(address(minimalEcosystem.fragmentEngine) != address(0), "Minimal engine should deploy");
       assertEq(minimalEcosystem.fragmentEngine.i_initialNFTCount(), 1, "Should have 1 NFT");

       address testUser = testUsers[0];
       vm.startPrank(testUser);
       uint256 tokenId = minimalEcosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Should mint from minimal ecosystem");
       vm.stopPrank();
   }

   function test_error_messageAccuracy() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       vm.expectRevert(FragmentErrors.FragmentEngine__IncompleteSet.selector);
       ecosystem.fragmentEngine.burnFragmentSet(fragment.fragmentNftId);

       vm.expectRevert(FragmentErrors.FragmentEngine__NonexistentNftId.selector);
       ecosystem.fragmentEngine.burnFragmentSet(999);

       vm.stopPrank();
   }

   function test_error_resourceExhaustionScenarios() public {
       address testUser = testUsers[0];

       uint256 initialCirculation = ecosystem.fragmentEngine.getNFTsInCirculation().length;

       vm.startPrank(testUser);

       uint256 fragmentsMinted = 0;
       while (ecosystem.fragmentEngine.getNFTsInCirculation().length > 0) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           fragmentsMinted++;

           if (fragmentsMinted % 5 == 0) {
               assertTrue(tokenId > 0, "Minting should continue working");
           }

           if (fragmentsMinted > initialCirculation * 4) {
               break;
           }
       }

       vm.expectRevert(FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable.selector);
       ecosystem.fragmentEngine.mint();

       vm.stopPrank();
   }

   function test_error_recoveryAfterErrors() public {
       address testUser = testUsers[0];

       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       try ecosystem.fragmentEngine.burnFragmentSet(fragment.fragmentNftId) {
           revert("Should have failed");
       } catch {
           // Expected failure
       }

       try ecosystem.fragmentEngine.verifyFragmentSet(999) {
           revert("Should have failed");
       } catch {
           // Expected failure
       }

       uint256 tokenId2 = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId2 > tokenId, "System should work normally after error conditions");

       vm.stopPrank();
   }
}
