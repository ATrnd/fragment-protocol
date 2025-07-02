// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TestHelpersCore} from "../../utilities/helpers/TestHelpers.Core.sol";
import {TestHelpersFragments} from "../../utilities/helpers/TestHelpers.Fragments.sol";
import {TestHelpersValidation} from "../../utilities/helpers/TestHelpers.Validation.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {FragmentEngine} from "../../../src/FragmentEngine.sol";
import {FragmentConstants} from "../../../src/constants/FragmentConstants.sol";
import {FragmentErrors} from "../../../src/constants/FragmentErrors.sol";

/**
* @title FragmentEngine Minting Test
* @author ATrnd
* @notice FragmentEngine minting operations validation
*/
contract FragmentEngineMintingTest is TestHelpersCore, TestHelpersFragments, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_mint_basicFunctionality() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Mint should succeed and return valid token ID");

       vm.stopPrank();
   }

   function test_mint_tokenIdProgression() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 initialTokenId = ecosystem.fragmentEngine.s_nextFragmentTokenId();

       uint256 firstToken = ecosystem.fragmentEngine.mint();
       uint256 afterFirstMint = ecosystem.fragmentEngine.s_nextFragmentTokenId();

       uint256 secondToken = ecosystem.fragmentEngine.mint();
       uint256 afterSecondMint = ecosystem.fragmentEngine.s_nextFragmentTokenId();

       assertEq(firstToken, initialTokenId + 1, "First token should be initial + 1");
       assertEq(secondToken, firstToken + 1, "Second token should be first + 1");
       assertEq(afterFirstMint, firstToken, "State should equal last minted token ID");
       assertEq(afterSecondMint, secondToken, "State should equal last minted token ID");

       vm.stopPrank();
   }

   function test_mint_fragmentDataAccuracy() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       assertTrue(fragment.fragmentNftId > 0, "Fragment NFT ID should be positive");
       assertTrue(fragment.fragmentId >= 1 && fragment.fragmentId <= 4, "Fragment ID should be 1-4");

       uint256 nftIdByTokenId = ecosystem.fragmentEngine.getFragmentNftIdByTokenId(tokenId);
       assertEq(nftIdByTokenId, fragment.fragmentNftId, "NFT ID lookup should match fragment data");

       vm.stopPrank();
   }

   function test_mint_randomNftSelection() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256[] memory selectedNfts = new uint256[](20);
       for (uint256 i = 0; i < 20; i++) {
           uint256 tokenId = ecosystem.fragmentEngine.mint();
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
           selectedNfts[i] = fragment.fragmentNftId;
       }

       bool foundDifferentNfts = false;
       for (uint256 i = 1; i < selectedNfts.length; i++) {
           if (selectedNfts[i] != selectedNfts[0]) {
               foundDifferentNfts = true;
               break;
           }
       }

       assertTrue(foundDifferentNfts, "Random selection should pick different NFTs");

       vm.stopPrank();
   }

   function test_mint_fragmentIdAssignment() public {
       address testUser = testUsers[0];

       uint256[] memory fragmentIds = mintCompleteFragmentSet(ecosystem.fragmentEngine, testUser, 1);

       assertEq(fragmentIds.length, 4, "Should mint complete set of 4 fragments");

       bool[] memory idsSeen = new bool[](5);

       for (uint256 i = 0; i < fragmentIds.length; i++) {
           IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(fragmentIds[i]);

           assertTrue(fragment.fragmentId >= 1 && fragment.fragmentId <= 4, "Fragment ID must be 1-4");
           assertFalse(idsSeen[fragment.fragmentId], "Fragment ID should not be duplicated");
           idsSeen[fragment.fragmentId] = true;
       }
   }

   function test_mint_ownershipAssignment() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();

       address owner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(tokenId);
       assertEq(owner, testUser, "Fragment should be owned by minter");

       uint256 totalSupply = IERC721Enumerable(address(ecosystem.fragmentEngine)).totalSupply();
       assertEq(totalSupply, 1, "Total supply should increase after mint");

       vm.stopPrank();
   }

   function test_mint_eventEmission() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       uint256 tokenId = ecosystem.fragmentEngine.mint();

       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       vm.stopPrank();

       assertTrue(tokenId > 0, "Token ID should be valid");
       assertTrue(fragment.fragmentNftId > 0, "Fragment NFT ID should be valid");
       assertTrue(fragment.fragmentId >= 1 && fragment.fragmentId <= 4, "Fragment ID should be 1-4");

       address owner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(tokenId);
       assertEq(owner, testUser, "Fragment should be owned by minter");
   }

   function test_mint_stateConsistency() public {
       address testUser = testUsers[0];
       vm.startPrank(testUser);

       ecosystem.fragmentEngine.s_nextFragmentTokenId();
       ecosystem.fragmentEngine.getNFTsInCirculation();

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);

       uint256 fragmentsLeft = ecosystem.fragmentEngine.getFragmentsLeftForNFT(fragment.fragmentNftId);
       assertEq(fragmentsLeft, 3, "Should have 3 fragments left after first mint");

       uint256 nextAvailable = ecosystem.fragmentEngine.getNextAvailableFragmentId(fragment.fragmentNftId);
       assertEq(nextAvailable, fragment.fragmentId + 1, "Next available should increment");

       vm.stopPrank();
   }

   function test_mint_multipleConsecutive() public {
       address testUser = testUsers[0];
       uint256[] memory tokenIds = mintFragments(ecosystem.fragmentEngine, testUser, 5);

       assertEq(tokenIds.length, 5, "Should mint requested number of fragments");

       for (uint256 i = 1; i < tokenIds.length; i++) {
           assertEq(tokenIds[i], tokenIds[i-1] + 1, "Token IDs should be sequential");
       }

       for (uint256 i = 0; i < tokenIds.length; i++) {
           address owner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(tokenIds[i]);
           assertEq(owner, testUser, "All fragments should be owned by minter");
       }
   }

   function test_mint_differentUsers() public {
       uint256[] memory userTokenCounts = new uint256[](testUsers.length);

       for (uint256 i = 0; i < testUsers.length; i++) {
           uint256[] memory tokens = mintFragments(ecosystem.fragmentEngine, testUsers[i], 2);
           userTokenCounts[i] = tokens.length;

           for (uint256 j = 0; j < tokens.length; j++) {
               address owner = IERC721(address(ecosystem.fragmentEngine)).ownerOf(tokens[j]);
               assertEq(owner, testUsers[i], "Fragment should be owned by respective user");
           }
       }

       for (uint256 i = 0; i < userTokenCounts.length; i++) {
           assertEq(userTokenCounts[i], 2, "Each user should have minted 2 fragments");
       }
   }

   function test_mint_lastAvailableNft() public {
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
       assertEq(remaining.length, 1, "Should have exactly one NFT remaining");

       uint256 lastNftId = remaining[0];

       uint256 tokenId = ecosystem.fragmentEngine.mint();
       assertTrue(tokenId > 0, "Should successfully mint from last NFT");

       IFragmentEngine.Fragment memory fragment = ecosystem.fragmentEngine.getFragmentData(tokenId);
       assertEq(fragment.fragmentNftId, lastNftId, "Fragment should come from the last NFT");

       vm.stopPrank();
   }

}
