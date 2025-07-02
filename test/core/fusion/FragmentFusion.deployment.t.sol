// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TestHelpersCore} from "../../utilities/helpers/TestHelpers.Core.sol";
import {TestHelpersValidation} from "../../utilities/helpers/TestHelpers.Validation.sol";
import {IFragmentFusion} from "../../../src/interfaces/IFragmentFusion.sol";
import {IFragmentEngine} from "../../../src/interfaces/IFragmentEngine.sol";
import {FragmentFusion} from "../../../src/FragmentFusion.sol";
import {FragmentEngine} from "../../../src/FragmentEngine.sol";
import {FragmentRandomness} from "../../../src/FragmentRandomness.sol";
import {FragmentErrors} from "../../../src/constants/FragmentErrors.sol";

/**
* @title FragmentFusion Deployment Test
* @author ATrnd
* @notice FragmentFusion deployment validation
*/
contract FragmentFusionDeploymentTest is TestHelpersCore, TestHelpersValidation {

   TestHelpersCore.BasicEcosystem private ecosystem;
   address[] private testUsers;

   function setUp() public {
       ecosystem = deployStandardEcosystem();
       testUsers = generateStandardUsers();
   }

   function test_deployment_standardSuccess() public view {
       assertEq(
           address(ecosystem.fragmentFusion.i_fragmentEngine()),
           address(ecosystem.fragmentEngine),
           "FragmentEngine reference should be set correctly"
       );

       assertEq(
           ecosystem.fragmentFusion.i_maxFragmentFusionNFTs(),
           ecosystem.fragmentEngine.i_initialNFTCount(),
           "Max fusion NFTs should equal initial NFT count"
       );

       assertEq(
           ecosystem.fragmentFusion.getFusionNFTsMinted(),
           0,
           "Initial fusion NFTs minted should be 0"
       );

       assertTrue(
           ecosystem.fragmentFusion.isFusionAvailable(),
           "Fusion should be available initially"
       );
   }

   function test_deployment_immutableState() public view {
       address engineRef1 = address(ecosystem.fragmentFusion.i_fragmentEngine());
       address engineRef2 = address(ecosystem.fragmentFusion.i_fragmentEngine());
       assertEq(engineRef1, engineRef2, "Engine references should be consistent");

       uint256 maxFusions = ecosystem.fragmentFusion.i_maxFragmentFusionNFTs();
       uint256 expectedMax = ecosystem.fragmentEngine.i_initialNFTCount();
       assertEq(maxFusions, expectedMax, "Max fusions should match engine NFT count");

       assertEq(
           ecosystem.fragmentFusion.getNextFusionTokenId(),
           1,
           "Next fusion token ID should start at 1"
       );
   }

   function test_deployment_zeroNFTsRevert() public {
       FragmentRandomness randomnessProvider = new FragmentRandomness();
       uint256[] memory emptyNftIds = new uint256[](0);

       FragmentEngine emptyFragmentEngine = new FragmentEngine(
           address(randomnessProvider),
           emptyNftIds
       );

       assertEq(
           emptyFragmentEngine.i_initialNFTCount(),
           0,
           "FragmentEngine should have zero initial NFT count"
       );

       vm.expectRevert(FragmentErrors.FragmentFusion__NoFragmentNFTsAvailable.selector);
       new FragmentFusion(address(emptyFragmentEngine));
   }

   function test_deployment_invalidAddresses() public {
       vm.expectRevert();
       new FragmentFusion(address(0));

       address invalidAddress = createLabeledUser("invalid");
       vm.expectRevert();
       new FragmentFusion(invalidAddress);
   }

   function test_deployment_crossContractIntegration() public view {
       assertEq(
           address(ecosystem.fragmentEngine.i_randomnessProvider()),
           address(ecosystem.randomnessProvider),
           "FragmentEngine should be connected to randomness provider"
       );

       assertEq(
           address(ecosystem.fragmentFusion.i_fragmentEngine()),
           address(ecosystem.fragmentEngine),
           "FragmentFusion should be connected to FragmentEngine"
       );

       assertTrue(
           ecosystem.fragmentFusion.isFusionAvailable(),
           "Fusion functionality should be operational"
       );

       (uint256 minted, uint256 remaining, uint256 maxAllowed, uint256 nextTokenId) =
           ecosystem.fragmentFusion.getFusionStatistics();

       assertEq(minted, 0, "Initial minted count should be 0");
       assertEq(remaining, maxAllowed, "Initial remaining should equal max allowed");
       assertEq(nextTokenId, 1, "Next token ID should start at 1");
   }

   function test_deployment_customConfiguration() public {
       uint256[] memory customIds = createSequentialNftIds(3);
       customIds[0] = 100;
       customIds[1] = 200;
       customIds[2] = 300;

       TestHelpersCore.BasicEcosystem memory customEcosystem = deployBasicEcosystem(3);

       assertTrue(
           address(customEcosystem.fragmentEngine) != address(0),
           "Custom FragmentEngine should deploy"
       );
       assertTrue(
           address(customEcosystem.fragmentFusion) != address(0),
           "Custom FragmentFusion should deploy"
       );

       assertEq(customEcosystem.nftCount, 3, "Custom NFT count should be 3");
       assertEq(
           customEcosystem.fragmentFusion.i_maxFragmentFusionNFTs(),
           3,
           "Custom max fusions should be 3"
       );
   }

   function test_deployment_statisticsAndLimits() public view {
       (uint256 minted, uint256 remaining, uint256 maxAllowed, uint256 nextTokenId) =
           ecosystem.fragmentFusion.getFusionStatistics();

       assertEq(minted, 0, "Initially no fusion NFTs should be minted");
       assertEq(remaining, maxAllowed, "Initially all fusion slots should be available");
       assertEq(maxAllowed, ecosystem.fragmentEngine.i_initialNFTCount(), "Max should equal NFT count");
       assertEq(nextTokenId, 1, "Next token ID should start at 1");

       assertTrue(
           ecosystem.fragmentFusion.isFusionAvailable(),
           "Fusion should be available after deployment"
       );
   }

   function test_deployment_edgeCases() public {
       TestHelpersCore.BasicEcosystem memory minEcosystem = deployMinimalEcosystem();

       assertEq(
           minEcosystem.fragmentFusion.i_maxFragmentFusionNFTs(),
           1,
           "Single NFT deployment should work"
       );

       TestHelpersCore.BasicEcosystem memory maxEcosystem = deployBasicEcosystem(MAX_NFT_COUNT);

       assertEq(
           maxEcosystem.fragmentFusion.i_maxFragmentFusionNFTs(),
           MAX_NFT_COUNT,
           "Larger deployment should work"
       );
   }
}
