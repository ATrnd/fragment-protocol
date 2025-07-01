// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRandomnessProvider} from "./interfaces/IRandomnessProvider.sol";

/**
 * @title Fragment Randomness
 * @author ATrnd
 * @notice Pseudo-random index generator for FragmentEngine circulation array selection
 * @dev Implements IRandomnessProvider interface using block.timestamp entropy for array index generation.
 *      Used exclusively by FragmentEngine.mint() to select random indices from s_availableFragmentNftIds array.
 *      Combines block.timestamp, msg.sender, and salt via keccak256 hash for entropy generation.
 *      SECURITY NOTICE: Block timestamp can be manipulated by miners within consensus rules (~15 seconds).
 *      This implementation prioritizes development efficiency over cryptographic security.
 * @custom:version 1.0.0
 * @custom:scope Fragment Protocol randomness implementation
 * @custom:purpose Array index selection for FragmentEngine.mint() circulation management
 * @custom:integration Called by FragmentEngine.mint() via i_randomnessProvider.generateRandomIndex()
 * @custom:security Block timestamp manipulation possible - suitable for development/testing environments
 * @custom:entropy Combines block.timestamp, msg.sender, and salt parameters via keccak256
 * @custom:interface Implements IRandomnessProvider for pluggable randomness architecture
 * @custom:migration Designed for replacement with production randomness providers (Chainlink VRF, Gelato VRF)
 */
contract FragmentRandomness is IRandomnessProvider {

    /*//////////////////////////////////////////////////////////////
                           RANDOMNESS GENERATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates pseudo-random array index for FragmentEngine circulation array selection
     * @dev Combines block.timestamp, msg.sender, and salt via keccak256 for entropy generation.
     *      Used by FragmentEngine.mint() to select random index from s_availableFragmentNftIds array.
     *      SECURITY LIMITATION: Block timestamp can be manipulated by miners within consensus rules.
     *      Miners can influence timestamp by ~15 seconds, potentially affecting NFT selection fairness.
     *      Caller address (msg.sender) and salt provide additional entropy but do not eliminate manipulation risk.
     * @param maxLength Maximum value (exclusive) for generated index - must match circulation array length
     * @param salt Additional entropy provided by FragmentEngine
     * @return randomIndex Pseudo-random number in range [0, maxLength) for array index selection
     * @custom:usage Called by FragmentEngine.mint() with circulation array length and salt
     * @custom:entropy Hash input: abi.encode(block.timestamp, msg.sender, salt)
     * @custom:output Returns: uint256(keccak256(entropy)) % maxLength
     * @custom:security Vulnerable to miner timestamp manipulation - not suitable for high-value randomness
     * @custom:deterministic Same inputs produce same outputs
     * @custom:replacement Production deployments should use verifiable randomness (Chainlink VRF)
     */
    function generateRandomIndex(uint256 maxLength, uint256 salt)
        external
        view
        override
        returns (uint256 randomIndex)
    {
        // Combine multiple entropy sources for Fragment NFT ID selection
        // SECURITY: Block timestamp manipulable by miners - development use only
        return uint256(keccak256(abi.encode(
            block.timestamp,
            msg.sender,
            salt
        ))) % maxLength;
    }

}
