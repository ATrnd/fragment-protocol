// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRandomnessProvider} from "./IRandomnessProvider.sol";

/**
 * @title IFragmentEngine
 * @notice Interface for the core fragment NFT engine prototype
 * @dev Defines essential operations for fragment minting, verification, and burning.
 *      Implements autonomous fragment distribution with pluggable randomness for technical validation.
 *      Compatible with ERC721 standard and integrates with FragmentFusion for systematic testing.
 * @author ATrnd
 * @custom:version 1.0.0
 * @custom:scope Technical prototype for builder infrastructure validation
 * @custom:purpose Core interface for Fragment Protocol builder integration infrastructure
 * @custom:integration Enables investigation of fragment-based ownership mechanics
 * @custom:prototype Professional reference implementation for novel ownership validation
 * @custom:validation ERC721Enumerable with fragment-specific extensions for testing
 * @custom:development Designed for FragmentFusion and randomness provider compatibility
 */
interface IFragmentEngine {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a fragment is minted with random distribution
    /// @dev Provides complete fragment identification and ownership tracking for development
    /// @param minter Address that minted the fragment (msg.sender)
    /// @param tokenId ID of the minted fragment token (globally unique)
    /// @param fragmentNftId ID of the NFT this fragment belongs to (1 of 4)
    /// @param fragmentId Unique identifier within the fragment set (1-4)
    /// @custom:integration Primary parameters indexed for efficient query filtering and data analysis
    /// @custom:development Used by prototype systems and analytics for fragment tracking
    /// @custom:validation Event emission adds ~2k gas to mint operation for testing
    event FragmentMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 indexed fragmentNftId,
        uint256 fragmentId
    );

    /// @notice Emitted when a complete set of fragments is burned for fusion eligibility
    /// @dev Indicates fragment set is eligible for fusion in FragmentFusion prototype
    /// @param fragmentBurner Address that initiated the burn (verified owner of all 4)
    /// @param fragmentNftId ID of the fragment NFT set that was burned
    /// @custom:integration Critical event for FragmentFusion prototype eligibility verification
    /// @custom:validation Only emitted after successful ownership verification
    /// @custom:prototype Burn operation is irreversible once this event is emitted
    event FragmentSetBurned(
        address indexed fragmentBurner,
        uint256 indexed fragmentNftId
    );

    /// @notice Emitted when an NFT is removed from circulation (all 4 fragments minted)
    /// @dev Indicates NFT will no longer appear in random selection for minting
    /// @param fragmentNftId ID of the NFT removed from active circulation
    /// @param timestamp When the removal occurred (block.timestamp)
    /// @custom:integration Marks transition from mintable to complete state for analysis
    /// @custom:development Used for tracking prototype completion rates and patterns
    /// @custom:validation External systems can monitor NFT lifecycle completion during testing
    event NFTRemovedFromCirculation(
        uint256 indexed fragmentNftId,
        uint256 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no fragment NFTs are available for minting
    /// @dev Occurs when all NFTs have reached 4 fragments and been removed from circulation
    /// @custom:trigger s_availableFragmentNftIds.length == 0
    /// @custom:resolution System has reached designed completion - all initial NFTs have been fully minted and removed from circulation
    /// @custom:frequency Rare - only when all initial NFTs are completed in prototype testing
    error FragmentEngine__NoFragmentNFTsAvailable();

    /// @notice Thrown when attempting to burn a set that's already been burned
    /// @dev Prevents double-burning of the same fragment set by the same address
    /// @custom:trigger s_fragmentBurnedSets[nftId][msg.sender] == true
    /// @custom:resolution Check burn status before attempting to burn
    /// @custom:validation Prevents duplicate burn attempts and state inconsistency
    error FragmentEngine__SetAlreadyBurned();

    /// @notice Thrown when set verification fails during burning
    /// @dev Indicates fragment set doesn't meet burning requirements
    /// @custom:trigger Incomplete set, wrong owner, or non-existent NFT
    /// @custom:resolution Ensure caller owns all 4 fragments of the NFT
    /// @custom:integration Comprehensive ownership and completeness check failure
    error FragmentEngine__SetVerificationFailed();

    /// @notice Thrown when attempting to verify a non-existent NFT ID
    /// @dev Occurs when querying NFT ID that has never had fragments minted
    /// @custom:trigger s_mintedFragmentsCount[nftId] == 0
    /// @custom:resolution Verify NFT ID exists in initial deployment
    /// @custom:validation Prevents operations on invalid NFT identifiers
    error FragmentEngine__NonexistentNftId();

    /// @notice Thrown when attempting to verify an incomplete fragment set
    /// @dev Occurs when fragment set has fewer than 4 fragments
    /// @custom:trigger fragmentTokenIds.length < 4
    /// @custom:resolution Mint remaining fragments to complete the set
    /// @custom:validation All 4 fragments (1,2,3,4) must exist for burning
    error FragmentEngine__IncompleteSet();

    /// @notice Thrown when caller doesn't own all fragments in a set
    /// @dev Prevents unauthorized burning by non-owners
    /// @custom:trigger ownerOf(tokenId) != msg.sender for any fragment
    /// @custom:resolution Acquire ownership of all 4 fragments before burning
    /// @custom:validation Critical ownership validation for burn authorization
    error FragmentEngine__NotOwnerOfAll();

    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Defines the properties of a fragment NFT with complete identification
    /// @dev Essential data structure for fragment identification and prototype validation
    /// @param fragmentNftId ID of the complete NFT this fragment belongs to
    /// @param fragmentId Unique identifier within the fragment set (1-4)
    /// @custom:validation fragmentId is always between 1-4
    /// @custom:integration Each (fragmentNftId, fragmentId) pair is globally unique
    /// @custom:development Used by prototype systems for fragment categorization
    struct Fragment {
        uint256 fragmentNftId;
        uint256 fragmentId;
    }

    /// @notice Stores comprehensive information about a burned fragment set
    /// @dev Contains metadata required for fusion eligibility verification in prototype
    /// @param burner Address that burned the fragments (eligible for fusion)
    /// @param burnTimestamp When the burn occurred (block.timestamp)
    /// @custom:integration Used by FragmentFusion for burn verification
    /// @custom:validation Data cannot be modified after burn completion
    /// @custom:prototype Prevents unauthorized fusion by tracking original burner
    struct BurnInfo {
        address burner;
        uint256 burnTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints a new fragment NFT with autonomous random distribution
    /// @dev Uses pluggable randomness provider for fair fragment distribution.
    ///      Automatically manages circulation and removes completed NFTs.
    /// @return tokenId The ID of the newly minted fragment token
    /// @custom:validation Approximately 150k gas for standard mint operation
    /// @custom:integration Depends on configured IRandomnessProvider implementation
    /// @custom:prototype No user input - system selects NFT and fragment ID automatically
    /// @custom:development Reentrancy protected, no admin controls for autonomous testing
    /// @custom:events Emits FragmentMinted and optionally NFTRemovedFromCirculation
    /// @custom:requirements At least one NFT must be available in circulation
    function mint() external returns (uint256 tokenId);

    /// @notice Burns a complete set of 4 fragments enabling fusion eligibility
    /// @dev Requires caller ownership of all fragments in the set.
    ///      Permanently destroys tokens and records burn information.
    /// @param fragmentNftId The NFT ID of the complete fragment set to burn
    /// @return success True if burning was successful (always true or reverts)
    /// @custom:validation Approximately 200k gas for complete set burn
    /// @custom:requirements Caller must own fragments 1, 2, 3, and 4 of specified NFT
    /// @custom:prototype Comprehensive ownership verification prevents unauthorized burns
    /// @custom:integration Burn info used by FragmentFusion for eligibility verification
    /// @custom:irreversible Burn operation cannot be undone once completed
    /// @custom:events Emits FragmentSetBurned upon successful completion
    function burnFragmentSet(uint256 fragmentNftId) external returns (bool success);

    /// @notice Verifies fragment set completeness and caller ownership
    /// @dev Comprehensive validation for burning eligibility without state changes.
    ///      Used internally before burning and available for external verification.
    /// @param fragmentNftId The NFT ID to verify for burning eligibility
    /// @return verified True if verification passed (always true or reverts)
    /// @custom:validation Approximately 50k gas for complete verification
    /// @custom:integration Checks existence, completeness (4 fragments), and ownership
    /// @custom:development Used by external contracts and frontends for pre-burn validation
    /// @custom:prototype Same validation logic as actual burning without state changes
    /// @custom:view Read-only operation safe for external calls
    function verifyFragmentSet(uint256 fragmentNftId) external view returns (bool verified);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets all token IDs for fragments of a specific NFT
    /// @dev Returns fragments in sequential order (1, 2, 3, 4) with array length indicating progress.
    ///      Array length shows minting progress: 0-4 fragments.
    /// @param nftId The NFT ID to query for fragment token IDs
    /// @return tokenIds Array of fragment token IDs belonging to the NFT
    /// @custom:validation Approximately 10k gas + 2k per fragment
    /// @custom:integration Returns fragments in sequential order (fragment 1, 2, 3, 4)
    /// @custom:development Used by burning logic and external fragment tracking systems
    /// @custom:prototype Array length indicates completion status (4 = complete set)
    function getFragmentTokenIds(uint256 nftId) external view returns (uint256[] memory tokenIds);

    /// @notice Gets the address that burned a specific fragment set
    /// @dev Returns the address eligible for fusion, or zero address if not burned.
    ///      Critical for FragmentFusion contract burn verification.
    /// @param fragmentNftId The NFT ID to check for burn status
    /// @return burner The address that burned the set, or address(0) if not burned
    /// @custom:validation Approximately 2k gas for storage read
    /// @custom:integration Essential for FragmentFusion burner eligibility verification
    /// @custom:prototype Returns zero address for unburned sets (safe default)
    /// @custom:development Non-zero return indicates fusion eligibility for returned address
    function getFragmentSetBurner(uint256 fragmentNftId) external view returns (address burner);

    /// @notice Gets NFT IDs still available for fragment minting
    /// @dev Returns dynamic array that shrinks as NFTs complete and are removed.
    ///      Used by randomness provider for selection and by frontends for availability.
    /// @return nftIds Array of NFT IDs currently in circulation
    /// @custom:validation Approximately 5k gas + 1k per available NFT
    /// @custom:integration Array size decreases as fragments are minted and sets completed
    /// @custom:prototype This array is used for random NFT selection in mint()
    /// @custom:development External systems can track global minting progress
    function getNFTsInCirculation() external view returns (uint256[] memory nftIds);

    /// @notice Gets the number of fragments remaining to mint for an NFT
    /// @dev Calculates remaining capacity by subtracting minted count from maximum (4).
    ///      Returns 0 when NFT is complete and removed from circulation.
    /// @param fragmentNftId The NFT ID to query for remaining capacity
    /// @return fragmentsLeft Number of fragments that can still be minted (0-4)
    /// @custom:validation Approximately 3k gas for calculation
    /// @custom:integration MAX_FRAGMENTS (4) minus current minted count
    /// @custom:prototype Returns 0 when all 4 fragments minted
    /// @custom:development Useful for tracking individual NFT completion progress
    function getFragmentsLeftForNFT(uint256 fragmentNftId) external view returns (uint256 fragmentsLeft);

    /// @notice Retrieves complete fragment data for a specific token
    /// @dev Returns Fragment struct containing NFT ID and fragment position.
    ///      Essential for understanding fragment relationships and categorization.
    /// @param tokenId The fragment token ID to query
    /// @return fragment Fragment data structure with NFT ID and fragment ID (1-4)
    /// @custom:validation Approximately 5k gas for struct retrieval
    /// @custom:integration Returns {fragmentNftId: uint256, fragmentId: uint256}
    /// @custom:prototype fragmentId will be between 1-4 for valid fragments
    /// @custom:development Used by prototype systems and trading systems for categorization
    function getFragmentData(uint256 tokenId) external view returns (Fragment memory fragment);

    /// @notice Gets the Fragment NFT ID associated with a token ID
    /// @dev Quick lookup to determine which NFT a fragment token belongs to.
    ///      More efficient than full getFragmentData when only NFT ID needed.
    /// @param tokenId The fragment token ID to lookup
    /// @return fragmentNftId The NFT ID this fragment belongs to
    /// @custom:validation Approximately 3k gas for direct mapping lookup
    /// @custom:integration More gas-efficient than getFragmentData for NFT ID only
    /// @custom:development Used for fragment grouping and ownership verification
    /// @custom:prototype Returns 0 for non-existent tokens
    function getFragmentNftIdByTokenId(uint256 tokenId) external view returns (uint256 fragmentNftId);

    /// @notice Gets comprehensive burn information for a fragment set
    /// @dev Returns BurnInfo struct with burner address and timestamp.
    ///      Contains zero values for sets that haven't been burned.
    /// @param fragmentNftId The NFT ID to query for burn information
    /// @return burnInfo Complete burn information including burner and timestamp
    /// @custom:validation Approximately 5k gas for struct retrieval
    /// @custom:integration Returns {burner: address, burnTimestamp: uint256}
    /// @custom:development Used by FragmentFusion and analytics systems
    /// @custom:prototype Returns zero values for sets that haven't been burned
    function getFragmentSetBurnInfo(uint256 fragmentNftId) external view returns (BurnInfo memory burnInfo);

    /// @notice Checks if a fragment set was burned by a specific address
    /// @dev Precise verification for burn-based access control and permissions.
    ///      More specific than getFragmentSetBurner for address verification.
    /// @param fragmentNftId The NFT ID to check for burn status
    /// @param burnerAddress The address to verify burned the set
    /// @return burned True if the set was burned by the specified address
    /// @custom:validation Approximately 3k gas for mapping lookup
    /// @custom:integration Enables fine-grained burn verification for access control
    /// @custom:development Used by external contracts for burn-based permissions
    /// @custom:prototype More specific than getFragmentSetBurner for boolean verification
    function isFragmentSetBurnedByAddress(uint256 fragmentNftId, address burnerAddress) external view returns (bool burned);

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE STATE GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the initial number of NFT IDs available for minting
    /// @dev Auto-generated getter for public immutable variable set during deployment.
    ///      Used by FragmentFusion to determine maximum fusion NFT limit.
    /// @return nftCount The initial NFT count set during deployment
    /// @custom:validation Value cannot change post-deployment
    /// @custom:integration Used by FragmentFusion for fusion limit calculation
    /// @custom:prototype Set once during contract initialization
    function i_initialNFTCount() external view returns (uint256 nftCount);

    /// @notice Gets the randomness provider contract reference
    /// @dev Auto-generated getter for public immutable randomness provider.
    ///      Critical for verifying randomness source and integration compatibility.
    /// @return provider The randomness provider contract interface
    /// @custom:integration Interface for pluggable randomness (Chainlink VRF, Gelato VRF, etc.)
    /// @custom:validation Immutable reference prevents randomness provider manipulation
    /// @custom:development External systems can verify randomness source
    function i_randomnessProvider() external view returns (IRandomnessProvider provider);

    /*//////////////////////////////////////////////////////////////
                        MUTABLE STATE GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Exposes the current next fragment token ID state
    /// @dev Auto-generated getter for public variable tracking token ID progression.
    ///      Used for predicting next token ID and monitoring minting progress.
    /// @return tokenId The current value of s_nextFragmentTokenId
    /// @custom:integration Increments by 1 for each minted fragment
    /// @custom:development Used by external systems for token ID prediction
    /// @custom:validation Enables tracking of total fragments minted across all NFTs
    function s_nextFragmentTokenId() external view returns (uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the next available fragment ID for an NFT
    /// @dev Calculates the next fragment ID based on current minted count.
    ///      Returns values 1-4 corresponding to fragment positions in the set.
    /// @param fragmentNftId The NFT ID to query for next fragment
    /// @return nextFragmentId The next available fragment ID (1-4)
    /// @custom:validation Approximately 3k gas for calculation
    /// @custom:integration Current minted count + 1 (results in 1, 2, 3, or 4)
    /// @custom:prototype Returns values between 1-4
    /// @custom:development Used by minting logic and external fragment prediction
    function getNextAvailableFragmentId(uint256 fragmentNftId) external view returns (uint256 nextFragmentId);

    /// @notice Gets the next fragment token ID in global sequence
    /// @dev Pure function calculating next token ID in the global sequence.
    ///      Used for token ID prediction and sequential progression.
    /// @param fragmentTokenId Current fragment token ID
    /// @return nextFragmentTokenId Next token ID in sequence (input + 1)
    /// @custom:validation Approximately 1k gas for pure calculation
    /// @custom:integration No state access required - pure mathematical calculation
    /// @custom:prototype Maintains global token ID sequence across all fragments
    /// @custom:development Used by external systems for token ID progression tracking
    function getNextFragmentTokenId(uint256 fragmentTokenId) external pure returns (uint256 nextFragmentTokenId);

}
