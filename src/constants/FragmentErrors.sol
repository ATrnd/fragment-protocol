// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title FragmentErrors
 * @notice Centralized error definitions for Fragment Protocol prototype
 * @dev Professional error management for security validation and access control.
 *      Each error includes comprehensive context to facilitate debugging during development.
 *      Provides security barriers to prevent unauthorized operations and system exploitation.
 * @author ATrnd
 * @custom:version 1.0.0
 * @custom:scope Technical prototype security validation library
 * @custom:purpose Centralized error definitions for access control and validation barriers
 * @custom:integration Enables centralized error management across protocol contracts
 * @custom:debugging Detailed error context for development and security analysis
 * @custom:development Used across Fragment Protocol contracts for consistent error handling
 */
library FragmentErrors {

    /*//////////////////////////////////////////////////////////////
                           FRAGMENT ENGINE ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no fragment NFTs are available for minting operations
    /// @dev Occurs when all NFTs have reached maximum fragments (4) and been removed from circulation
    /// @custom:trigger s_availableFragmentNftIds.length == 0 in FragmentEngine.mint()
    /// @custom:frequency Rare - only occurs when all initial fragment NFTs are completed
    /// @custom:resolution System has reached designed completion - no further minting possible
    /// @custom:integration Indicates successful completion of fragment distribution phase
    /// @custom:development Expected end state when all fragment NFT capacity is exhausted
    /// @custom:security Prevents over-minting beyond protocol design limits
    error FragmentEngine__NoFragmentNFTsAvailable();

    /// @notice Thrown when attempting to burn a fragment set that's already been burned by the caller
    /// @dev Prevents double-burning of the same fragment set by the same address (replay protection)
    /// @custom:trigger s_fragmentBurnedSets[nftId][msg.sender] == true
    /// @custom:frequency Should never occur in normal operation - indicates exploitation attempt
    /// @custom:resolution Security validation failure - check system integrity
    /// @custom:integration Prevents unauthorized duplicate burn operations preventing replay attacks
    /// @custom:development Replay attack protection mechanism for burn operations
    /// @custom:security Critical validation preventing burn operation replay attacks
    error FragmentEngine__SetAlreadyBurned();

    /// @notice Thrown when fragment set verification fails during burning operations
    /// @dev Indicates one of multiple validation failures: incomplete set, wrong owner, or non-existent NFT
    /// @custom:trigger Multiple conditions: set not complete, caller not owner, or invalid NFT ID
    /// @custom:frequency Should never occur in normal operation - indicates unauthorized access attempt
    /// @custom:resolution Security validation failure - caller must own all 4 fragments of valid NFT ID
    /// @custom:integration Comprehensive validation barrier enforcing multiple security requirements
    /// @custom:development Multi-layer security validation with detailed failure analysis via verifyFragmentSet()
    /// @custom:security Multi-layer validation preventing unauthorized burn operations
    error FragmentEngine__SetVerificationFailed();

    /// @notice Thrown when attempting to verify or operate on a non-existent NFT ID
    /// @dev Occurs when querying NFT ID that has never had fragments minted or invalid ID provided
    /// @custom:trigger s_mintedFragmentsCount[nftId] == 0 or out-of-range NFT ID
    /// @custom:frequency Should never occur in normal operation - indicates invalid input or exploitation
    /// @custom:resolution Security validation failure - verify NFT ID validity
    /// @custom:integration Input validation barrier preventing operations on invalid NFT identifiers
    /// @custom:development Parameter validation preventing invalid value injection attacks
    /// @custom:security Prevents invalid value injection into burn operations
    error FragmentEngine__NonexistentNftId();

    /// @notice Thrown when attempting to verify or burn an incomplete fragment set
    /// @dev Occurs when fragment set has fewer than required 4 fragments for burning
    /// @custom:trigger fragmentTokenIds.length < 4 in verification logic
    /// @custom:frequency Should never occur in normal operation - burn requires complete set
    /// @custom:resolution Complete fragment set required - must own all 4 fragments of same NFT ID
    /// @custom:integration Enforces completeness requirement for burn operations
    /// @custom:development Completeness validation ensuring burn operation integrity
    /// @custom:security Prevents premature burning of incomplete fragment collections
    error FragmentEngine__IncompleteSet();

    /// @notice Thrown when caller doesn't own all fragments required for burning
    /// @dev Prevents unauthorized burning by non-owners, enforces complete ownership of all 4 fragments
    /// @custom:trigger ownerOf(tokenId) != msg.sender for any fragment in the set
    /// @custom:frequency Should never occur in normal operation - indicates unauthorized access attempt
    /// @custom:resolution Caller must own all 4 fragment tokens (1,2,3,4) of specified NFT ID
    /// @custom:integration Ownership validation preventing unauthorized access to burn functionality
    /// @custom:development Comprehensive ownership verification across complete fragment set
    /// @custom:security Critical ownership validation preventing unauthorized fragment burning
    error FragmentEngine__NotOwnerOfAll();

    /*//////////////////////////////////////////////////////////////
                           FRAGMENT FUSION ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when FragmentFusion deployment fails due to no available NFTs
    /// @dev Occurs during deployment when FragmentEngine has zero initial NFTs configured
    /// @custom:trigger i_fragmentEngine.i_initialNFTCount() == 0 during constructor
    /// @custom:frequency Very rare - deployment configuration error
    /// @custom:resolution Deploy FragmentEngine with valid initial NFT set before FragmentFusion
    /// @custom:integration Critical deployment dependency validation for setup
    /// @custom:development Indicates incorrect deployment sequence or configuration
    /// @custom:security Validates proper contract initialization dependencies
    error FragmentFusion__NoFragmentNFTsAvailable();

    /// @notice Thrown when caller tries to fuse a fragment set burned by another address
    /// @dev Enforces burn-based access control: only original burner can fuse their burned fragment set
    /// @custom:trigger getFragmentSetBurner(nftId) != msg.sender
    /// @custom:frequency Should never occur in normal operation - indicates unauthorized access attempt
    /// @custom:resolution Only the address that burned the specific fragment set can fuse it
    /// @custom:integration Access control mechanism preventing fusion theft via unauthorized access
    /// @custom:development Burn-based eligibility system ensuring only legitimate burners can fuse
    /// @custom:security Prevents unauthorized access to fusion functionality
    error FragmentFusion__NotBurner();

    /// @notice Thrown when trying to fuse a fragment set that hasn't been burned yet
    /// @dev Prevents fusion of fragment sets still held as individual ERC721 tokens - burn is prerequisite
    /// @custom:trigger getFragmentSetBurner(nftId) == address(0)
    /// @custom:frequency Should never occur in normal operation - indicates workflow violation
    /// @custom:resolution Burn the complete fragment set first using FragmentEngine.burnFragmentSet()
    /// @custom:integration Workflow sequence validation enforcing proper burn-before-fuse progression
    /// @custom:development Sequential operation validation preventing premature fusion attempts
    /// @custom:security Fragment set must be burned before fusion eligibility
    error FragmentFusion__SetNotBurned();

    /// @notice Thrown when trying to fuse a fragment set that has already been fused
    /// @dev Prevents double-fusion of the same fragment set (replay attack protection)
    /// @custom:trigger s_fragmentSetFused[nftId] == true
    /// @custom:frequency Should never occur in normal operation - indicates exploitation attempt
    /// @custom:resolution Each fragment set can only be fused once - check fusion status before retry
    /// @custom:integration Enforces unique fusion NFT creation preventing duplicates
    /// @custom:development Fusion operations are irreversible once completed
    /// @custom:security Replay attack prevention for fusion operations
    error FragmentFusion__AlreadyFused();

    /// @notice Thrown when the maximum number of fusion NFTs has been reached
    /// @dev Prevents fusion beyond i_maxFragmentFusionNFTs limit maintaining protocol scarcity
    /// @custom:trigger s_nextFragmentFusionTokenId >= i_maxFragmentFusionNFTs
    /// @custom:frequency Rare - occurs only when fusion limit (equal to initial NFT count) reached
    /// @custom:resolution Fragment Protocol has reached maximum fusion capacity by design
    /// @custom:integration Maintains limited fusion NFT supply according to protocol design
    /// @custom:development Protocol economics preventing unlimited fusion minting
    /// @custom:security Enforces protocol scarcity limits preventing overflow
    error FragmentFusion__MaxFragmentFusionReached();

}
