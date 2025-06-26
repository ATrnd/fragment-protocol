// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRandomnessProvider
 * @notice Interface for randomness providers in Fragment Protocol prototype
 * @dev Enables pluggable randomness sources for fragment distribution with prototype validation.
 *      Designed for compatibility with various randomness sources during development and testing.
 *      Supports both stateful and stateless provider implementations for maximum development flexibility.
 * @author ATrnd
 * @custom:version 1.1.0
 * @custom:scope Technical prototype for builder infrastructure validation
 * @custom:purpose Pluggable randomness architecture for prototype flexibility and builder integration
 * @custom:integration Interface supports both development and future production randomness sources
 * @custom:prototype Compatible with development providers and infrastructure
 * @custom:development Core infrastructure interface for Fragment Protocol randomness integration
 * @custom:validation Enables randomness provider experimentation without Fragment Engine changes
 * @custom:testing Supports both stateful (development) and stateless (testing) implementations
 */
interface IRandomnessProvider {

    /*//////////////////////////////////////////////////////////////
                            CORE RANDOMNESS FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates a random index within a given range for fragment distribution
    /// @dev Core randomness function used by FragmentEngine for fair fragment selection.
    ///      Implementation must ensure uniform distribution within the specified range.
    ///      IMPORTANT: Function mutability depends on provider implementation:
    ///      - Development providers (basic): typically view functions
    ///      - Integration providers: may require state modifications (nonpayable)
    ///      - Testing providers: may need counters or cycle management
    /// @param maxLength The maximum value (exclusive) for the generated index
    /// @param salt Additional entropy source for randomness enhancement
    /// @return randomIndex A random number between 0 and maxLength-1 (inclusive)
    /// @custom:validation Returns values in range [0, maxLength) - zero-based indexing
    /// @custom:integration Must provide statistically uniform distribution across range for analysis
    /// @custom:prototype Security guarantees depend on implementation (dev vs future production)
    /// @custom:development Used by FragmentEngine.mint() for NFT selection during testing
    /// @custom:testing Gas consumption varies by implementation complexity for validation
    /// @custom:entropy Salt parameter enables additional entropy injection for development
    /// @custom:mutability Function mutability varies by implementation needs and development requirements
    function generateRandomIndex(uint256 maxLength, uint256 salt) external returns (uint256 randomIndex);

}
