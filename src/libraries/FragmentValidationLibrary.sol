// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../constants/FragmentConstants.sol";

/**
 * @title FragmentValidationLibrary
 * @notice Pure utility functions for fragment validation operations in Fragment Protocol
 * @dev Centralized validation utility library providing reusable validation predicates.
 *      Pure functions enable gas optimization and comprehensive testing coverage.
 *      Used across Fragment Protocol contracts for consistent validation logic.
 * @author ATrnd
 * @custom:version 1.0.0
 * @custom:scope Technical validation utility library
 * @custom:purpose Centralized validation predicates for Fragment Protocol operations
 * @custom:integration Enables consistent validation behavior across protocol contracts
 * @custom:validation Pure functions provide gas-efficient validation without state changes
 * @custom:development Used across Fragment Protocol contracts for consistent validation logic
 */
library FragmentValidationLibrary {

    /*//////////////////////////////////////////////////////////////
                           ZERO VALUE VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Performs zero check validation for fragment minting operations
    /// @dev Used in FragmentEngine for two specific validation contexts:
    ///      1. _initializeFirstFragment: checks if no fragments minted for NFT ID
    ///      2. _verifyFragmentSet: validates NFT ID exists (security check for burn operations)
    /// @param fragmentCount Current fragment count for specific NFT ID
    /// @return available True if fragment count is zero (no fragments minted)
    /// @custom:validation Approximately 200 gas for pure comparison operation
    /// @custom:integration Equality comparison against ZERO_UINT constant
    /// @custom:development Used in mint initialization and burn security validation
    /// @custom:usage High frequency - called during every mint operation and burn verification
    /// @custom:purpose Zero check validation for fragment existence and burn eligibility
    function hasNoFragmentsAvailable(uint256 fragmentCount) internal pure returns (bool available) {
        return fragmentCount == FragmentConstants.ZERO_UINT;
    }

    /// @notice Validates address parameters in FragmentFusion security checks
    /// @dev Used in FragmentFusion for two specific validation contexts:
    ///      1. _verifyFragmentFusionAddress: security validation for fusion eligibility
    ///      2. _fusionTokenExists: fusion token existence validation in getter functions
    /// @param addr The address to validate against zero address
    /// @return isZero True if the address is the zero address (0x000...000)
    /// @custom:validation Approximately 200 gas for pure address comparison
    /// @custom:integration Used in fusion security validation and token existence checks
    /// @custom:development Critical for fusion access control and token validation
    /// @custom:usage Medium frequency - called during fusion operations and token queries
    /// @custom:purpose Address validation for fusion security and token existence verification
    function isZeroAddress(address addr) internal pure returns (bool isZero) {
        return addr == FragmentConstants.ZERO_ADDRESS;
    }

    /*//////////////////////////////////////////////////////////////
                           FRAGMENT SET VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Security check for fragment set completeness in burn operations
    /// @dev Used in _verifyFragmentSet within FragmentEngine._burnFragmentSet for security validation.
    ///      Validates fragment set has all 4 fragments before allowing burn operation.
    /// @param fragmentCount The current number of fragments in the set
    /// @return True if the fragment set is complete (has all 4 fragments)
    /// @custom:validation Validates against SYSTEM_MAX_FRAGMENTS_PER_NFT (4)
    /// @custom:integration Essential security check in burn verification process
    /// @custom:development Used in _verifyFragmentSet for burn operation authorization
    /// @custom:usage Low frequency - called only during burn operations (not progression tracking)
    /// @custom:purpose Security validation ensuring only complete fragment sets can be burned
    function isFragmentSetComplete(uint256 fragmentCount) internal pure returns (bool) {
        return fragmentCount == FragmentConstants.SYSTEM_MAX_FRAGMENTS_PER_NFT;
    }

    /// @notice Garbage collection validation for NFT circulation management
    /// @dev Used in _removeNFTIfCompleted within FragmentEngine.mint() for circulation management.
    ///      Part of built-in garbage collection mechanics removing fully minted NFTs from circulation.
    /// @param fragmentCount The current fragment count to validate
    /// @return True if all fragments minted for NFT ID (ready for circulation removal)
    /// @custom:validation Validates against SYSTEM_MAX_FRAGMENTS_PER_NFT threshold
    /// @custom:integration Core component of circulation garbage collection system
    /// @custom:development Triggers NFT removal from circulation when capacity reached
    /// @custom:usage High frequency - called during every mint operation
    /// @custom:purpose Determines when NFTs should be removed from active circulation
    function isFragmentCountAtMaximum(uint256 fragmentCount) internal pure returns (bool) {
        return fragmentCount >= FragmentConstants.SYSTEM_MAX_FRAGMENTS_PER_NFT;
    }

    /*//////////////////////////////////////////////////////////////
                           FUSION VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Fusion token existence validation for getter functions
    /// @dev Used in _fusionTokenExists within FragmentFusion.getFusedNFTInfoSafe.
    ///      Part of fusion token state lookup and information retrieval system.
    /// @param tokenId The fusion token ID to validate for existence
    /// @return valid True if the token ID meets minimum requirements (>=1)
    /// @custom:validation Approximately 200 gas for pure comparison operation
    /// @custom:integration Validates against FUSION_MIN_TOKEN_ID (1)
    /// @custom:development Used in fusion token existence verification for getter functions
    /// @custom:usage Medium frequency - called during fusion token information queries
    /// @custom:purpose Validates fusion token existence and eligibility for information retrieval
    function isValidFusionTokenId(uint256 tokenId) internal pure returns (bool valid) {
        return tokenId >= FragmentConstants.FUSION_MIN_TOKEN_ID;
    }

    /// @notice Security check for fusion capacity limits
    /// @dev Used in _verifyFragmentFusionMax within FragmentFusion.fuseFragmentSet and view functions.
    ///      Security validation preventing fusion beyond protocol-defined limits.
    /// @param currentCount The current fusion count to validate against limit
    /// @param maxAllowed The maximum allowed fusions for capacity validation
    /// @return limitReached True if the fusion limit has been reached or exceeded
    /// @custom:validation Approximately 200 gas for pure comparison operation
    /// @custom:integration Security barrier in fusion operations and availability queries
    /// @custom:development Used in fusion security validation and information getters
    /// @custom:usage Low frequency - called during fusion operations and specific availability checks
    /// @custom:purpose Security validation preventing fusion beyond protocol-defined capacity
    function isFusionLimitReached(uint256 currentCount, uint256 maxAllowed) internal pure returns (bool limitReached) {
        return currentCount >= maxAllowed;
    }

    /*//////////////////////////////////////////////////////////////
                           ARRAY MANIPULATION VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Optimized array removal eligibility check for circulation management
    /// @dev Used in _removeNFTFromCirculation within FragmentEngine mint operations.
    ///      Validates eligibility for swap-and-pop array optimization during NFT removal.
    /// @param index The array index to validate for swap-and-pop eligibility
    /// @param arrayLength The array length for optimization validation
    /// @return isLast True if index is last element (no swap needed, direct pop)
    /// @custom:validation Approximately 300 gas for arithmetic and comparison operations
    /// @custom:integration Enables optimized array removal in circulation management
    /// @custom:development Critical for efficient NFT circulation removal operations
    /// @custom:usage High frequency - called during every mint operation in circulation management
    /// @custom:purpose Determines swap-and-pop optimization eligibility for array removal
    function isLastArrayIndex(uint256 index, uint256 arrayLength) internal pure returns (bool isLast) {
        return index == arrayLength - FragmentConstants.INCREMENT_INDEX;
    }

    /// @notice Fragment NFT supply validation for mint operations
    /// @dev Used in _validateFragmentNFTsAvailable within FragmentEngine.mint() security check.
    ///      Validates fragment NFT supply availability before allowing mint operations.
    /// @param arrayLength The circulation array length to validate for supply
    /// @return hasElements True if fragment NFTs are available for minting
    /// @custom:validation Approximately 200 gas for pure comparison operation
    /// @custom:integration Security check in mint operation validation
    /// @custom:development Used in _validateFragmentNFTsAvailable for mint authorization
    /// @custom:usage High frequency - called during every mint operation
    /// @custom:purpose Validates fragment NFT supply availability before mint execution
    function hasArrayElements(uint256 arrayLength) internal pure returns (bool hasElements) {
        return arrayLength > FragmentConstants.ZERO_UINT;
    }

}
