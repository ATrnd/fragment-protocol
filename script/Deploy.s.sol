// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {FragmentEngine} from "../src/FragmentEngine.sol";
import {FragmentFusion} from "../src/FragmentFusion.sol";
import {FragmentRandomness} from "../src/FragmentRandomness.sol";
import {DeployConfig} from "./config/DeployConfig.sol";

/**
 * @title Fragment Protocol Deployment Script
 * @notice Basic deployment for Fragment Protocol development and research
 * @dev Deploys complete protocol stack for testing and UI research
 *      WARNING: Uses development-grade randomness - not production ready
 * @author ATrnd
 */
contract DeployFragmentEngine is Script {

    /**
     * @notice Deploys Fragment Protocol for development use
     * @dev Deploys FragmentRandomness, FragmentEngine, and FragmentFusion
     */
    function run() external {
        DeployConfig config = new DeployConfig();

        console.log("=== Fragment Protocol Development Deployment ===");
        console.log("Deployer:", msg.sender);

        vm.startBroadcast();

        // Deploy development randomness provider
        FragmentRandomness randomness = new FragmentRandomness();
        console.log("FragmentRandomness:", address(randomness));

        // Deploy core fragment engine
        FragmentEngine fragmentEngine = new FragmentEngine(
            address(randomness),
            config.getInitialNftIds()
        );
        console.log("FragmentEngine:", address(fragmentEngine));

        // Deploy fusion mechanism
        FragmentFusion fragmentFusion = new FragmentFusion(address(fragmentEngine));
        console.log("FragmentFusion:", address(fragmentFusion));

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("NFTs available:", fragmentEngine.i_initialNFTCount());
        console.log("Max fusions:", fragmentFusion.i_maxFragmentFusionNFTs());
    }

}

