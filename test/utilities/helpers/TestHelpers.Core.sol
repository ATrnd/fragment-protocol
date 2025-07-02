// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {FragmentEngine} from "../../../src/FragmentEngine.sol";
import {FragmentFusion} from "../../../src/FragmentFusion.sol";
import {FragmentRandomness} from "../../../src/FragmentRandomness.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {IFragmentFusion} from "../../../src/interfaces/IFragmentFusion.sol";
import {IRandomnessProvider} from "../../../src/interfaces/IRandomnessProvider.sol";

/**
 * @title TestHelpers Core
 * @author ATrnd
 * @notice Fragment Protocol ecosystem deployment utilities for test suite
 */
contract TestHelpersCore is Test {

   /*//////////////////////////////////////////////////////////////
                           CONSTANTS
   //////////////////////////////////////////////////////////////*/

   uint256 internal constant DEFAULT_NFT_COUNT = 5;
   uint256 internal constant MIN_NFT_COUNT = 1;
   uint256 internal constant MAX_NFT_COUNT = 20;
   uint256 internal constant BASIC_BURN_GAS_LIMIT = 300_000;
   uint256 internal constant BASIC_MINT_GAS_LIMIT = 200_000;
   uint256 internal constant STANDARD_BUILDER_USER_COUNT = 3;
   uint256 internal constant MAX_BUILDER_USERS = 5;

   /*//////////////////////////////////////////////////////////////
                           DATA STRUCTURES
   //////////////////////////////////////////////////////////////*/

   struct BasicEcosystem {
       IFragmentEngine fragmentEngine;
       IFragmentFusion fragmentFusion;
       IRandomnessProvider randomnessProvider;
       uint256 nftCount;
       uint256[] initialNftIds;
   }

   /*//////////////////////////////////////////////////////////////
                           DEPLOYMENT FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   function deployBasicEcosystem(uint256 nftCount) public returns (BasicEcosystem memory ecosystem) {
       require(nftCount >= MIN_NFT_COUNT, "TestHelpersCore: NFT count below minimum");
       require(nftCount <= MAX_NFT_COUNT, "TestHelpersCore: NFT count exceeds maximum");

       uint256[] memory nftIds = _createSequentialNftIds(nftCount);

       ecosystem.randomnessProvider = new FragmentRandomness();

       ecosystem.fragmentEngine = new FragmentEngine(
           address(ecosystem.randomnessProvider),
           nftIds
       );

       ecosystem.fragmentFusion = new FragmentFusion(
           address(ecosystem.fragmentEngine)
       );

       ecosystem.nftCount = nftCount;
       ecosystem.initialNftIds = nftIds;

       return ecosystem;
   }

   function deployMinimalEcosystem() public returns (BasicEcosystem memory ecosystem) {
       return deployBasicEcosystem(MIN_NFT_COUNT);
   }

   function deployStandardEcosystem() public returns (BasicEcosystem memory ecosystem) {
       return deployBasicEcosystem(DEFAULT_NFT_COUNT);
   }

   /*//////////////////////////////////////////////////////////////
                           BASIC UTILITY FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   function createLabeledUser(string memory label) public pure returns (address user) {
       require(bytes(label).length > 0, "TestHelpersCore: User label cannot be empty");
       require(bytes(label).length <= 32, "TestHelpersCore: User label too long");

       return address(uint160(uint256(keccak256(abi.encodePacked("labeled_user_", label)))));
   }

    /*//////////////////////////////////////////////////////////////
                               PUBLIC UTILITIES
    //////////////////////////////////////////////////////////////*/

    function createSequentialNftIds(uint256 count) public pure returns (uint256[] memory nftIds) {
        require(count > 0, "TestHelpersCore: NFT count must be positive");
        require(count <= MAX_NFT_COUNT, "TestHelpersCore: NFT count exceeds maximum");

        return _createSequentialNftIds(count);
    }

   /*//////////////////////////////////////////////////////////////
                           PRIVATE UTILITIES
   //////////////////////////////////////////////////////////////*/

   function _createSequentialNftIds(uint256 count) private pure returns (uint256[] memory nftIds) {
       nftIds = new uint256[](count);
       for (uint256 i = 0; i < count; i++) {
           nftIds[i] = i + 1;
       }
       return nftIds;
   }

   /*//////////////////////////////////////////////////////////////
                           VALIDATION FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   function validateBasicDeployment(BasicEcosystem memory ecosystem) public view {
       require(address(ecosystem.fragmentEngine) != address(0), "TestHelpersCore: FragmentEngine not deployed");
       require(address(ecosystem.fragmentFusion) != address(0), "TestHelpersCore: FragmentFusion not deployed");
       require(address(ecosystem.randomnessProvider) != address(0), "TestHelpersCore: RandomnessProvider not deployed");

       require(
           address(ecosystem.fragmentFusion.i_fragmentEngine()) == address(ecosystem.fragmentEngine),
           "TestHelpersCore: Fusion-Engine integration failed"
       );
       require(
           address(ecosystem.fragmentEngine.i_randomnessProvider()) == address(ecosystem.randomnessProvider),
           "TestHelpersCore: Engine-Randomness integration failed"
       );

       require(ecosystem.nftCount > 0, "TestHelpersCore: NFT count not set");
       require(ecosystem.initialNftIds.length == ecosystem.nftCount, "TestHelpersCore: NFT ID array size mismatch");

       uint256[] memory circulation = ecosystem.fragmentEngine.getNFTsInCirculation();
       require(circulation.length == ecosystem.nftCount, "TestHelpersCore: Circulation not initialized correctly");
   }

   function validateOperationalReadiness(BasicEcosystem memory ecosystem) public view {
       validateBasicDeployment(ecosystem);

       require(
           ecosystem.fragmentEngine.s_nextFragmentTokenId() == 0,
           "TestHelpersCore: Initial token ID not at starting position"
       );

       require(
           ecosystem.fragmentFusion.isFusionAvailable(),
           "TestHelpersCore: Fusion not available initially"
       );
       require(
           ecosystem.fragmentFusion.getFusionNFTsMinted() == 0,
           "TestHelpersCore: Initial fusion count not zero"
       );

       require(
           ecosystem.fragmentEngine.i_initialNFTCount() == ecosystem.nftCount,
           "TestHelpersCore: Initial NFT count mismatch"
       );
       require(
           ecosystem.fragmentFusion.i_maxFragmentFusionNFTs() == ecosystem.nftCount,
           "TestHelpersCore: Max fusion NFTs incorrect"
       );
   }

   /*//////////////////////////////////////////////////////////////
                           BASIC USER GENERATION
   //////////////////////////////////////////////////////////////*/

   function generateTestUsers(uint256 count) public pure returns (address[] memory users) {
       require(count > 0, "TestHelpersUsers: User count must be positive");
       require(count <= MAX_BUILDER_USERS, "TestHelpersUsers: User count exceeds builder testing maximum");

       users = new address[](count);
       for (uint256 i = 0; i < count; i++) {
           users[i] = address(uint160(uint256(keccak256(abi.encodePacked("builder_test_user", i)))));
       }
       return users;
   }

   function generateStandardUsers() public pure returns (address[] memory users) {
       return generateTestUsers(STANDARD_BUILDER_USER_COUNT);
   }

}
