// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Deploy Configuration
 * @notice Basic deployment parameters for Fragment Protocol development
 * @dev Simple configuration for research and testing environments only
 * @author ATrnd
 */
contract DeployConfig {

    /**
     * @notice Returns deployer as contract owner
     * @return owner Deployer address for development use
     */
    function getOwner() external view returns (address owner) {
        return msg.sender;
    }

    /**
     * @notice Provides initial NFT IDs for fragment generation
     * @return initialNftIds Sequential NFT IDs (1-5) for development testing
     */
    function getInitialNftIds() external pure returns (uint256[] memory initialNftIds) {
        initialNftIds = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            initialNftIds[i] = i + 1;
        }

        return initialNftIds;
    }

}
