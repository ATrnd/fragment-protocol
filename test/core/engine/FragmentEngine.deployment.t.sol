// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TestHelpersCore} from "../../utilities/helpers/TestHelpers.Core.sol";
import {TestHelpersValidation} from "../../utilities/helpers/TestHelpers.Validation.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {FragmentEngine} from "../../../src/FragmentEngine.sol";
import {FragmentConstants} from "../../../src/constants/FragmentConstants.sol";
import {FragmentErrors} from "../../../src/constants/FragmentErrors.sol";

/**
* @title FragmentEngine Deployment Test
* @author ATrnd
* @notice FragmentEngine deployment validation
*/
contract FragmentEngineDeploymentTest is TestHelpersCore, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_constructor_parameterValidation() public view {
       assertEq(
           address(ecosystem.fragmentEngine.i_randomnessProvider()),
           address(ecosystem.randomnessProvider),
           "Randomness provider should be set correctly"
       );

       assertEq(
           ecosystem.fragmentEngine.i_initialNFTCount(),
           ecosystem.nftCount,
           "Initial NFT count should match deployment parameter"
       );
   }

   function test_constructor_immutableState() public view {
       uint256 storedCount = ecosystem.fragmentEngine.i_initialNFTCount();
       assertEq(storedCount, DEFAULT_NFT_COUNT, "Immutable NFT count should match deployment");

       address storedProvider = address(ecosystem.fragmentEngine.i_randomnessProvider());
       address deployedProvider = address(ecosystem.randomnessProvider);
       assertEq(storedProvider, deployedProvider, "Immutable provider reference should be correct");
   }

   function test_constructor_randomnessIntegration() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Mint should succeed with randomness provider");

       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
       assertTrue(fragment.fragmentNftId > 0, "Fragment should have valid NFT ID from randomness");
       assertTrue(fragment.fragmentId >= 1 && fragment.fragmentId <= 4, "Fragment ID should be valid");

       vm.stopPrank();
   }

   function test_constructor_initialCirculation() public view {
       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();

       assertEq(circulation.length, ecosystem.nftCount, "Circulation should contain all initial NFTs");

       for (uint256 i = 0; i < circulation.length; i++) {
           assertEq(circulation[i], i + 1, "NFT IDs should be sequential starting from 1");
       }
   }

   function test_constructor_nftIdArray() public view {
       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();

       assertNoDuplicates(circulation);

       for (uint256 i = 0; i < circulation.length; i++) {
           assertTrue(circulation[i] > 0, "NFT IDs should be positive");
       }
   }

   function test_constructor_contractIntegration() public view {
       assertEq(
           IERC721Metadata(address(ecosystem.fragmentEngine)).name(),
           FragmentConstants.TOKEN_FRAGMENT_NAME,
           "ERC721 name should match constants"
       );
       assertEq(
           IERC721Metadata(address(ecosystem.fragmentEngine)).symbol(),
           FragmentConstants.TOKEN_FRAGMENT_SYMBOL,
           "ERC721 symbol should match constants"
       );

       assertEq(
           ecosystem.fragmentEngine.s_nextFragmentTokenId(),
           FragmentConstants.FRAGMENT_STARTING_TOKEN_ID,
           "Initial token ID should be at starting value"
       );
   }

   function test_constructor_zeroParameterEdgeCases() public {
       TestHelpersCore.BasicEcosystem memory emptyEcosystem = deployMinimalEcosystem();

       assertEq(emptyEcosystem.fragmentEngine.i_initialNFTCount(), 1, "Should have minimal initial NFT count");
       assertEq(emptyEcosystem.fragmentEngine.getNFTsInCirculation().length, 1, "Should have minimal circulation");

       address testUser = testUsers[0];
       vm.startPrank(testUser);
       uint256 tokenId = emptyEcosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Should be able to mint from minimal ecosystem");
       vm.stopPrank();
   }

   function test_constructor_maximumBoundaries() public {
       createSequentialNftIds(MAX_NFT_COUNT);

       TestHelpersCore.BasicEcosystem memory maxEcosystem = deployBasicEcosystem(MAX_NFT_COUNT);

       assertEq(
           maxEcosystem.fragmentEngine.i_initialNFTCount(),
           MAX_NFT_COUNT,
           "Maximum NFT count should be supported"
       );

       validateOperationalReadiness(maxEcosystem);
   }
}
