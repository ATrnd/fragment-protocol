// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFragmentEngine} from "./IFragmentEngine.sol";

/**
 * @title IFragmentFusion
 * @notice Interface for the fragment fusion mechanism prototype
 * @dev Defines operations for fusing burned fragment sets into new NFTs for technical validation.
 *      Integrates with FragmentEngine for burn verification and eligibility tracking.
 *      Implements burn-based access control for secure fusion operations during testing.
 * @author ATrnd
 * @custom:version 1.0.0
 * @custom:scope Technical prototype for builder infrastructure validation
 * @custom:purpose Fragment fusion prototype for builder integration
 * @custom:integration Enables investigation of burn-to-fuse transformation mechanics
 * @custom:prototype Professional reference implementation for novel fusion validation
 * @custom:validation ERC721Enumerable with fusion-specific extensions for testing
 * @custom:development Requires active FragmentEngine prototype for burn verification
 * @custom:discovery Maximum fusion NFTs limited to initial NFT count for prototype scarcity
 */
interface IFragmentFusion {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a fragment set is fused into a new NFT
    /// @dev Indicates successful fusion of burned fragments into fusion NFT for tracking.
    ///      Marks completion of fragment lifecycle: mint → burn → fuse.
    /// @param fuser Address that performed the fusion (must be original burner)
    /// @param fragmentNftId Original fragment NFT ID that was fused
    /// @param fusionTokenId New fusion token ID representing the fused set
    /// @param timestamp When the fusion occurred (block.timestamp)
    /// @custom:integration Used by analytics and prototype systems for fusion tracking
    /// @custom:validation Only emitted after successful burn verification
    /// @custom:prototype Fusion operation is irreversible once this event is emitted
    /// @custom:development Completes the fragment-to-fusion transformation process for analysis
    event FragmentSetFused(
        address indexed fuser,
        uint256 indexed fragmentNftId,
        uint256 indexed fusionTokenId,
        uint256 timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no fragment NFTs are available for fusion operations
    /// @dev Occurs during deployment when FragmentEngine has zero initial NFTs
    /// @custom:trigger i_fragmentEngine.i_initialNFTCount() == 0
    /// @custom:resolution Deploy FragmentEngine with valid initial NFT set
    /// @custom:frequency Should only occur during incorrect prototype deployment
    error FragmentFusion__NoFragmentNFTsAvailable();

    /// @notice Thrown when caller tries to fuse a set burned by someone else
    /// @dev Prevents unauthorized fusion by non-burners, maintains burn-based access control
    /// @custom:trigger getFragmentSetBurner(nftId) != msg.sender
    /// @custom:resolution Only the original burner can fuse their burned set
    /// @custom:validation Critical access control preventing fusion theft in prototype
    error FragmentFusion__NotBurner();

    /// @notice Thrown when trying to fuse a fragment set that hasn't been burned
    /// @dev Occurs when attempting to fuse fragments still held as individual tokens
    /// @custom:trigger getFragmentSetBurner(nftId) == address(0)
    /// @custom:resolution Burn the complete fragment set first in FragmentEngine
    /// @custom:integration Fragment set must be burned before fusion eligibility
    error FragmentFusion__SetNotBurned();

    /// @notice Thrown when trying to fuse a fragment set that has already been fused
    /// @dev Prevents double-fusion of the same fragment set, maintains uniqueness
    /// @custom:trigger s_fragmentSetFused[nftId] == true
    /// @custom:resolution Each fragment set can only be fused once
    /// @custom:prototype Ensures one-to-one mapping between fragment sets and fusions
    error FragmentFusion__AlreadyFused();

    /// @notice Thrown when the maximum number of fusion NFTs has been reached
    /// @dev Prevents fusion beyond prototype limits, maintains scarcity for testing
    /// @custom:trigger s_nextFragmentFusionTokenId >= i_maxFragmentFusionNFTs
    /// @custom:resolution Maximum fusions equal to initial NFT count
    /// @custom:integration Maintains limited supply of fusion NFTs for scarcity validation
    error FragmentFusion__MaxFragmentFusionReached();

    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Comprehensive metadata for a fused NFT
    /// @dev Contains complete fusion history and eligibility information for tracking.
    ///      Immutable record of fusion transaction and original fragment relationship.
    /// @param fragmentNftId The original fragment NFT ID that was fused
    /// @param fragmentFusedBy Address of the user who fused the fragment set
    /// @param fragmentFusedTimestamp When the fusion occurred (block.timestamp)
    /// @custom:validation Metadata cannot be modified after fusion completion
    /// @custom:integration Links fusion NFT back to original fragment set for analysis
    /// @custom:development Used by analytics for fusion history tracking and pattern investigation
    struct FragmentFusionInfo {
        uint256 fragmentNftId;
        address fragmentFusedBy;
        uint256 fragmentFusedTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new fusion NFT from a previously burned fragment set
    /// @dev Verifies burn eligibility, fusion availability, and mints new ERC721 token.
    ///      Implements comprehensive validation before fusion execution.
    /// @param fragmentNftId The ID of the fragment set that was burned
    /// @return fusionTokenId The ID of the newly minted fusion NFT
    /// @custom:validation Approximately 180k gas for complete fusion operation
    /// @custom:requirements Fragment set must be burned by caller in FragmentEngine
    /// @custom:integration Checks burn eligibility, fusion status, and availability limits
    /// @custom:prototype Only original burner can fuse their burned fragment set
    /// @custom:development Requires active FragmentEngine prototype for verification
    /// @custom:events Emits FragmentSetFused upon successful completion
    /// @custom:effects Creates fusion NFT, updates mappings, and records metadata
    /// @custom:irreversible Fusion operation cannot be undone once completed
    function fuseFragmentSet(uint256 fragmentNftId) external returns (uint256 fusionTokenId);

    /*//////////////////////////////////////////////////////////////
                         VERIFICATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that the caller is eligible to fuse a specific fragment set
    /// @dev Comprehensive burn verification including existence and ownership checks.
    ///      External access to address verification logic for integration purposes.
    /// @param fragmentNftId The fragment NFT ID to verify for fusion eligibility
    /// @custom:validation Approximately 15k gas for complete verification
    /// @custom:integration Used by external contracts for pre-fusion validation
    /// @custom:prototype Verifies burn eligibility without state changes
    /// @custom:requirements Fragment set must be burned by caller
    /// @custom:development Checks both burn status and caller authorization
    function verifyFragmentFusionAddress(uint256 fragmentNftId) external view;

    /// @notice Verifies that a fragment set hasn't already been fused
    /// @dev Checks fusion status to prevent double fusion attempts.
    ///      External access to set verification logic for integration.
    /// @param fragmentNftId The fragment NFT ID to check for fusion status
    /// @custom:validation Approximately 5k gas for fusion status check
    /// @custom:integration Used by external contracts for fusion status verification
    /// @custom:prototype Prevents double fusion attempts before execution
    /// @custom:development Once fused, status cannot be reversed
    /// @custom:uniqueness Ensures each fragment set can only be fused once
    function verifyFragmentFusionSet(uint256 fragmentNftId) external view;

    /// @notice Verifies that the fusion limit hasn't been reached
    /// @dev Checks prototype limits to ensure fusion availability.
    ///      External access to maximum fusion verification for planning.
    /// @custom:validation Approximately 5k gas for limit verification
    /// @custom:integration Prevents fusion beyond maximum allowed NFTs
    /// @custom:development Used by external contracts for availability verification
    /// @custom:prototype Compares current count with maximum fusion NFTs
    /// @custom:scarcity Maintains limited supply constraints for testing
    function verifyFragmentFusionMax() external view;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves comprehensive metadata for a fusion NFT
    /// @dev Returns complete fusion information including original fragment data.
    ///      Essential for fusion history tracking and prototype integration.
    /// @param fusionTokenId The fusion token ID to query for metadata
    /// @return fusionInfo The complete fusion metadata structure
    /// @custom:validation Approximately 8k gas for metadata retrieval
    /// @custom:integration Returns {fragmentNftId, fragmentFusedBy, fragmentFusedTimestamp}
    /// @custom:development Used by prototype systems and analytics for fusion tracking
    /// @custom:prototype Metadata cannot be modified after fusion completion
    /// @custom:traceability Links fusion NFT back to original fragment set and burner
    function getFusedNFTInfo(uint256 fusionTokenId) external view returns (FragmentFusionInfo memory fusionInfo);

    /// @notice Gets the fusion token ID corresponding to a fragment NFT ID
    /// @dev Enables reverse lookup from original fragment set to fusion token.
    ///      Returns 0 if the fragment set hasn't been fused yet.
    /// @param fragmentNftId The original fragment NFT ID to lookup
    /// @return fusionTokenId The fusion token ID (0 if not fused)
    /// @custom:validation Approximately 3k gas for mapping lookup
    /// @custom:integration Used by external systems for fragment-to-fusion mapping
    /// @custom:prototype Returns 0 for unfused fragment sets (safe default)
    /// @custom:development Reverse lookup from fragment ID to fusion token
    /// @custom:monitoring Enables tracking of fusion completion status
    function getFusedNftIdByFragmentNftId(uint256 fragmentNftId) external view returns (uint256 fusionTokenId);

    /*//////////////////////////////////////////////////////////////
                        SUPPLY AND STATISTICS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the current next fusion token ID for prediction
    /// @dev Calculates the next fusion token ID that will be minted.
    ///      External systems can use this for pre-fusion planning and UI.
    /// @return nextTokenId The next fusion token ID that will be minted
    /// @custom:validation Approximately 3k gas for calculation
    /// @custom:integration Enables external systems to predict next token ID
    /// @custom:prototype Current counter + 1
    /// @custom:development Used by frontend systems for user experience optimization
    /// @custom:planning Helps external systems prepare for upcoming fusions
    function getNextFusionTokenId() external view returns (uint256 nextTokenId);

    /// @notice Gets the number of fusion NFTs minted so far
    /// @dev Returns current fusion NFT supply for tracking and analytics.
    ///      Useful for monitoring progress toward maximum fusion limits.
    /// @return minted The number of fusion NFTs that have been minted
    /// @custom:validation Approximately 3k gas for counter read
    /// @custom:integration Current fusion NFT supply count
    /// @custom:prototype Tracks progress toward maximum fusion limit
    /// @custom:development Used by monitoring systems for supply tracking
    /// @custom:scarcity Enables calculation of remaining fusion availability
    function getFusionNFTsMinted() external view returns (uint256 minted);

    /// @notice Gets the number of fusion NFTs remaining to be minted
    /// @dev Calculates remaining fusion capacity for availability planning.
    ///      Returns 0 when maximum fusion limit is reached.
    /// @return remaining The number of fusion NFTs that can still be minted
    /// @custom:validation Approximately 5k gas for calculation
    /// @custom:integration Real-time availability check for fusion operations
    /// @custom:prototype Maximum minus current count (0 if at limit)
    /// @custom:development Used by frontend systems for user guidance
    /// @custom:planning Enables capacity planning for fusion operations
    function getFusionNFTsRemaining() external view returns (uint256 remaining);

    /// @notice Checks if a fragment set has been fused
    /// @dev Simple boolean check for fusion status of specific fragment set.
    ///      Quick status verification for external integration.
    /// @param fragmentNftId The fragment NFT ID to check for fusion status
    /// @return fused True if the fragment set has been fused
    /// @custom:validation Approximately 3k gas for mapping lookup
    /// @custom:integration Simple boolean fusion status check
    /// @custom:development Used by external contracts for fusion status queries
    /// @custom:prototype Status cannot change once set to true
    /// @custom:efficiency Fast boolean check without struct retrieval
    function isFragmentSetFused(uint256 fragmentNftId) external view returns (bool fused);

    /// @notice Checks if fusion is available (not at maximum limit)
    /// @dev Returns availability status for fusion operations planning.
    ///      Quick availability check for operational decision making.
    /// @return available True if more fusion NFTs can be minted
    /// @custom:validation Approximately 5k gas for limit comparison
    /// @custom:integration Real-time availability status for fusion operations
    /// @custom:prototype Returns false when maximum fusion NFTs reached
    /// @custom:development Used by frontend systems for operation enablement
    /// @custom:planning Enables operational planning and user guidance
    function isFusionAvailable() external view returns (bool available);

    /// @notice Gets comprehensive fusion statistics in single call
    /// @dev Aggregated statistics for efficient external system integration.
    ///      Reduces gas costs by combining multiple queries into one.
    /// @return minted Number of fusion NFTs minted so far
    /// @return remaining Number of fusion NFTs remaining to mint
    /// @return maxAllowed Maximum number of fusion NFTs allowed
    /// @return nextTokenId The next token ID that will be minted
    /// @custom:validation Approximately 15k gas for combined statistics
    /// @custom:integration Combines multiple queries for gas optimization
    /// @custom:development Comprehensive statistics for dashboard integration
    /// @custom:prototype Single call for complete fusion system status
    /// @custom:monitoring Enables efficient system state monitoring
    function getFusionStatistics() external view returns (
        uint256 minted,
        uint256 remaining,
        uint256 maxAllowed,
        uint256 nextTokenId
    );

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE STATE GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Fragment Engine contract reference
    /// @dev Auto-generated getter for public immutable FragmentEngine reference.
    ///      Critical for verifying cross-contract integration and burn verification.
    /// @return fragmentEngine The Fragment Engine contract interface
    /// @custom:integration Essential reference for burn verification operations
    /// @custom:validation Immutable reference prevents contract manipulation
    /// @custom:development External systems can verify integration target
    /// @custom:prototype Set once during contract initialization
    function i_fragmentEngine() external view returns (IFragmentEngine fragmentEngine);

    /// @notice Gets the maximum number of fusion NFTs that can be created
    /// @dev Auto-generated getter for public immutable maximum fusion limit.
    ///      Determines prototype scarcity and fusion availability bounds.
    /// @return maxCount The maximum fusion NFT count
    /// @custom:integration Protocol-defined maximum fusion NFT supply for testing
    /// @custom:prototype Maintains limited supply of fusion NFTs for scarcity validation
    /// @custom:validation Equals FragmentEngine initial NFT count
    /// @custom:development Value cannot change post-deployment
    function i_maxFragmentFusionNFTs() external view returns (uint256 maxCount);

    /*//////////////////////////////////////////////////////////////
                        ADVANCED UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates that a fusion token ID exists and is properly minted
    /// @dev Comprehensive validation including ID range, supply bounds, and ownership.
    ///      Used internally and externally for token existence verification.
    /// @param fusionTokenId The fusion token ID to validate for existence
    /// @return exists True if the fusion token ID is valid and exists
    /// @custom:validation Approximately 10k gas for comprehensive validation
    /// @custom:integration Checks ID validity, supply bounds, and ownership
    /// @custom:development Used by prototype systems and external contracts
    /// @custom:prototype Prevents operations on non-existent tokens
    /// @custom:verification Comprehensive existence and validity checking
    function fusionTokenExists(uint256 fusionTokenId) external view returns (bool exists);

    /// @notice Gets fusion information safely with existence validation
    /// @dev Safe alternative to getFusedNFTInfo that includes existence verification.
    ///      Returns empty struct if token doesn't exist instead of reverting.
    /// @param fusionTokenId The fusion token ID to query safely
    /// @return exists True if the token exists and data is valid
    /// @return fusionInfo The fusion information (empty struct if token doesn't exist)
    /// @custom:validation Approximately 15k gas for validation and retrieval
    /// @custom:integration Returns empty data instead of reverting for non-existent tokens
    /// @custom:development Safe method for external contracts and frontends
    /// @custom:prototype Combines existence check with data retrieval
    /// @custom:robustness Prevents revert-based errors in external integrations
    function getFusedNFTInfoSafe(uint256 fusionTokenId) external view returns (
        bool exists,
        FragmentFusionInfo memory fusionInfo
    );

}
