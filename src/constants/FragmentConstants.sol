// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title FragmentConstants
 * @notice Centralized constants for the Fragment Protocol prototype
 * @dev Constants library providing consistent values across protocol implementation
 *      for fragment mechanics, token identification, and validation operations.
 * @author ATrnd
 * @custom:version 1.0.0
 * @custom:scope Technical prototype constants library
 * @custom:purpose Centralized protocol parameters and validation constants
 * @custom:integration Enables consistent behavior across Fragment Protocol contracts
 */
library FragmentConstants {

    /*//////////////////////////////////////////////////////////////
                           CORE PROTOCOL PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum fragments per NFT defining completeness threshold
    /// @dev Core protocol parameter: 4 fragments constitute a complete set for fusion
    /// @custom:implementation Chosen for protocol simplicity and gas efficiency
    /// @custom:validation Essential parameter for completeness validation
    /// @custom:integration Enables fragment collection mechanics
    uint256 internal constant SYSTEM_MAX_FRAGMENTS_PER_NFT = 4;

    /*//////////////////////////////////////////////////////////////
                           TOKEN METADATA CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Fragment Engine token name for ERC721 compliance
    /// @dev ERC721 metadata for fragment tokens
    /// @custom:standard Professional naming for prototype deployment
    /// @custom:integration Clear identification for ecosystem tracking
    string internal constant TOKEN_FRAGMENT_NAME = "Fragment Engine";

    /// @notice Fragment Engine token symbol for ERC721 compliance
    /// @dev ERC721 symbol for fragment tokens
    /// @custom:standard Standardized 4-character format for compatibility
    /// @custom:integration Enables clear token identification in applications
    string internal constant TOKEN_FRAGMENT_SYMBOL = "FRAG";

    /// @notice Fragment Fusion token name for ERC721 compliance
    /// @dev ERC721 metadata for fusion tokens - distinguished from fragment tokens
    /// @custom:standard Distinguished naming separating fusion tokens from fragment tokens
    /// @custom:integration Clear differentiation between Fragment Engine and Fragment Fusion tokens
    string internal constant TOKEN_FUSION_NAME = "Fragment Fusion";

    /// @notice Fragment Fusion token symbol for ERC721 compliance
    /// @dev ERC721 symbol for fusion tokens - distinguished from FRAG fragment tokens
    /// @custom:standard Extended symbol (FRAGFUSE) clearly differentiating from fragment tokens (FRAG)
    /// @custom:integration Enables precise tracking of fusion tokens separately from fragment tokens
    string internal constant TOKEN_FUSION_SYMBOL = "FRAGFUSE";

    /*//////////////////////////////////////////////////////////////
                           VALIDATION CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Zero uint constant for validation and initialization
    /// @dev Used throughout the protocol for zero checks and default values
    /// @custom:validation Standard zero value avoiding magic numbers
    /// @custom:integration Consistent zero handling for data integrity
    uint256 internal constant ZERO_UINT = 0;

    /// @notice Zero address constant for validation and initialization
    /// @dev Used throughout the protocol for address validation and null checks
    /// @custom:validation Essential for address validation avoiding magic numbers
    /// @custom:integration Standard zero address for data consistency
    address internal constant ZERO_ADDRESS = address(0);

    /*//////////////////////////////////////////////////////////////
                           INCREMENT PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard increment for fragment counting operations
    /// @dev Used when adding fragments to NFT sets during minting
    /// @custom:validation Ensures consistent fragment count progression (0→1→2→3→4)
    /// @custom:integration Avoids magic numbers in fragment counting logic
    uint256 internal constant INCREMENT_MINTED_FRAGMENT = 1;

    /// @notice Standard increment for indices and array operations
    /// @dev Used for token ID progression and array indexing
    /// @custom:validation Critical for array bounds and iteration logic
    /// @custom:integration Consistent incrementing avoiding magic numbers
    uint256 internal constant INCREMENT_INDEX = 1;

    /// @notice Increment for calculating next fragment ID within sets
    /// @dev Added to current count to get next fragment ID (1→2→3→4)
    /// @custom:validation Fragment IDs progress sequentially within each NFT set
    /// @custom:integration Avoids magic numbers in fragment ID calculations
    uint256 internal constant INCREMENT_FRAGMENT_ID = 1;

    /// @notice Increment for calculating next token ID in global sequence
    /// @dev Added to current token ID to get next global token ID
    /// @custom:validation Global token ID progression for unique identification
    /// @custom:integration Ensures unique token tracking avoiding magic numbers
    uint256 internal constant INCREMENT_TOKEN_ID = 1;

    /// @notice Increment for fusion token ID progression
    /// @dev Used when minting new fusion tokens, separate from fragment tokens
    /// @custom:validation Fusion token ID progression independent of fragments
    /// @custom:integration Maintains distinct ID spaces for Fragment Engine vs Fragment Fusion
    uint256 internal constant INCREMENT_FUSION_TOKEN_ID = 1;

    /*//////////////////////////////////////////////////////////////
                           FRAGMENT SYSTEM BOUNDARIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum fragment ID in a set, establishing valid range
    /// @dev Fragment IDs start from 1, following human-readable conventions
    /// @custom:validation Lower bound for fragment ID validation
    /// @custom:integration Avoids magic numbers in fragment ID validation
    uint256 internal constant FRAGMENT_MIN_ID = 1;

    /// @notice Maximum fragment ID in a set, establishing valid range
    /// @dev Fragment IDs go from 1 to SYSTEM_MAX_FRAGMENTS_PER_NFT (4)
    /// @custom:validation Upper bound matching system maximum
    /// @custom:integration Enables dynamic range validation based on SYSTEM_MAX_FRAGMENTS_PER_NFT
    uint256 internal constant FRAGMENT_MAX_ID = SYSTEM_MAX_FRAGMENTS_PER_NFT;

    /// @notice Starting token ID for fragment minting sequence
    /// @dev First fragment token will have ID 1 (after increment from 0)
    /// @custom:validation Token ID 0 reserved, first actual token gets ID 1
    /// @custom:integration Enables clean sequential token ID progression
    uint256 internal constant FRAGMENT_STARTING_TOKEN_ID = 0;

    /// @notice Size of a complete fragment set array for memory allocation
    /// @dev Used for array initialization and loop bounds in fragment operations
    /// @custom:validation Optimizes array allocation for fragment collections
    /// @custom:integration Consistent array sizing based on SYSTEM_MAX_FRAGMENTS_PER_NFT
    uint256 internal constant FRAGMENT_SET_SIZE = SYSTEM_MAX_FRAGMENTS_PER_NFT;

    /// @notice Last index in a fragment set array (0-based indexing)
    /// @dev Used for array bounds checking and circulation management operations
    /// @custom:validation Critical for circulation management logic
    /// @custom:integration Enables dynamic calculation based on SYSTEM_MAX_FRAGMENTS_PER_NFT
    uint256 internal constant FRAGMENT_SET_LAST_INDEX = SYSTEM_MAX_FRAGMENTS_PER_NFT - INCREMENT_INDEX;

    /*//////////////////////////////////////////////////////////////
                           FUSION SYSTEM PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Starting fusion token ID for fusion minting sequence
    /// @dev First fusion token will have ID 1 (after increment from 0)
    /// @custom:validation Fusion token ID 0 reserved, first actual token gets ID 1
    /// @custom:integration Separate ID space from Fragment Engine for clear tracking
    uint256 internal constant FUSION_STARTING_TOKEN_ID = 0;

    /// @notice Minimum fusion token ID establishing valid range
    /// @dev Fusion token IDs start from 1, maintaining consistency with fragment tokens
    /// @custom:validation Lower bound for fusion token ID validation
    /// @custom:integration Consistent ID ranges across Fragment Engine and Fragment Fusion
    uint256 internal constant FUSION_MIN_TOKEN_ID = 1;

    /*//////////////////////////////////////////////////////////////
                           OPERATION RESULT CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Represents successful operation result
    /// @dev Used for return values and operation verification instead of raw boolean
    /// @custom:validation Standard success indicator for burn and fusion operations
    /// @custom:integration Consistent success tracking avoiding magic boolean values
    bool internal constant OPERATION_SUCCESS = true;

    /// @notice Represents failed operation result
    /// @dev Used for return values and error state indication instead of raw boolean
    /// @custom:validation Standard failure indicator for burn and fusion operations
    /// @custom:integration Consistent failure tracking avoiding magic boolean values
    bool internal constant OPERATION_FAILURE = false;

}
