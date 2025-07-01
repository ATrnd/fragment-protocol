// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFragmentEngine} from "./interfaces/IFragmentEngine.sol";
import {IFragmentFusion} from "./interfaces/IFragmentFusion.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {FragmentConstants} from "./constants/FragmentConstants.sol";
import {FragmentErrors} from "./constants/FragmentErrors.sol";
import {FragmentValidationLibrary} from "./libraries/FragmentValidationLibrary.sol";

/**
* @title Fragment Fusion
* @author ATrnd
* @notice Fragment fusion mechanism implementing burn-verification-to-fuse workflow
* @dev Implements ERC721 standard for fusion NFTs created from Fragment NFT sets burned in the FragmentEngine.
*      Validates burn eligibility through FragmentEngine integration, enforces burn-based access control,
*      and mints unique fusion NFTs representing transformed fragment collections.
*      Each Fragment NFT set can only be fused once by its original burner.
* @custom:version 1.0.0
* @custom:scope Fragment Protocol fusion implementation
* @custom:purpose Burn-verification-to-fuse mechanism with access control and fusion NFT creation
* @custom:integration Depends on FragmentEngine for burn verification and eligibility validation
* @custom:security Burn-based access control prevents unauthorized fusion operations
* @custom:lifecycle Autonomous fusion operations with supply limits based on initial Fragment NFT count
*/
contract FragmentFusion is IFragmentFusion, ERC721Enumerable {

   /*//////////////////////////////////////////////////////////////
                           LIBRARY INTEGRATIONS
   //////////////////////////////////////////////////////////////*/

   using FragmentValidationLibrary for uint256;
   using FragmentValidationLibrary for address;

   /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STATE
   //////////////////////////////////////////////////////////////*/

   /// @notice Reference to FragmentEngine contract for burn verification and configuration
   /// @dev Immutable reference used for: burn eligibility verification via getFragmentSetBurner,
   ///      constructor validation via i_initialNFTCount, and fusion limit calculation.
   ///      Burn verification is prerequisite for fusion eligibility in burn-verification-to-fuse workflow.
   /// @custom:validation Immutable post-deployment, ensures consistent burn verification source
   /// @custom:integration Used in constructor, _verifyFragmentFusionAddress, and fusion limit calculation
   IFragmentEngine public immutable i_fragmentEngine;

   /// @notice Maximum number of fusion NFTs that can be created
   /// @dev Set to match FragmentEngine initial Fragment NFT count to maintain supply relationship.
   ///      Prevents unlimited fusion NFT creation and maintains protocol scarcity.
   /// @custom:validation Equals i_fragmentEngine.i_initialNFTCount() for supply consistency
   /// @custom:integration Maintains 1:1 relationship between initial Fragment NFTs and max fusion NFTs
   uint256 public immutable i_maxFragmentFusionNFTs;

   /*//////////////////////////////////////////////////////////////
                           MUTABLE STATE
   //////////////////////////////////////////////////////////////*/

   /// @notice ID of the most recently minted fusion NFT
   /// @dev Used in: constructor initialization, fuseFragmentSet increment and storage operations,
   ///      _verifyFragmentFusionMax limit validation, getNextFusionTokenId calculation,
   ///      getFusionNFTsMinted current count, getFusionNFTsRemaining capacity calculation,
   ///      isFusionAvailable limit checking, getFusionStatistics data aggregation, and _fusionTokenExists validation.
   /// @custom:validation Sequential progression ensures unique fusion NFT identification
   /// @custom:integration Tracks total fusion NFTs minted against maximum limit
   uint256 private s_nextFragmentFusionTokenId;

   /// @notice Tracks which Fragment NFT sets have been fused to prevent double fusion
   /// @dev Used in: fuseFragmentSet state setting, _verifyFragmentFusionSet double-fusion prevention,
   ///      and isFragmentSetFused status queries. Once set to true, cannot be reversed.
   /// @custom:security Prevents double fusion attacks and maintains unique fusion NFT creation
   /// @custom:validation Once fused, Fragment NFT set cannot be fused again
   mapping(uint256 => bool) private s_fragmentSetFused;

   /// @notice Maps Fragment NFT IDs to their corresponding fusion NFT token IDs
   /// @dev Used in: fuseFragmentSet relationship establishment and getFusedNftIdByFragmentNftId lookups.
   ///      Enables tracking of which fusion NFT was created from which Fragment NFT set.
   /// @custom:integration Enables reverse lookup from Fragment NFT ID to fusion NFT
   /// @custom:frontend Available for Fragment NFT to fusion NFT relationship tracking
   mapping(uint256 => uint256) private s_fragmentTokenIdToFragmentFusionTokenId;

   /// @notice Fusion metadata storage for each minted fusion NFT
   /// @dev Maps fusion token ID => FragmentFusionInfo struct containing: fragmentNftId, fragmentFusedBy, fragmentFusedTimestamp.
   ///      Used in fuseFragmentSet metadata storage and getFusedNFTInfo/getFusedNFTInfoSafe data retrieval.
   /// @custom:metadata Fusion information storage containing original Fragment NFT ID, fuser address, and timestamp
   /// @custom:frontend Available for fusion NFT metadata queries and tracking
   mapping(uint256 => FragmentFusionInfo) private s_fragmentFusionInfo;

   /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
   //////////////////////////////////////////////////////////////*/

   /// @notice Initializes Fragment Fusion with Fragment Engine integration and supply limits
   /// @dev Sets up immutable references and validates Fragment Engine has available Fragment NFTs.
   ///      Establishes immutable reference to Fragment Engine for burn-verification-to-fuse workflow.
   /// @param _fragmentEngineAddress Address of the deployed Fragment Engine contract
   /// @custom:validation Validates Fragment Engine address and Fragment NFT availability
   /// @custom:integration Establishes immutable reference to Fragment Engine for burn verification prerequisite
   constructor(
       address _fragmentEngineAddress
   ) ERC721(FragmentConstants.TOKEN_FUSION_NAME, FragmentConstants.TOKEN_FUSION_SYMBOL) {
       i_fragmentEngine = IFragmentEngine(_fragmentEngineAddress);

       if (i_fragmentEngine.i_initialNFTCount().hasNoFragmentsAvailable()) {
           revert FragmentErrors.FragmentFusion__NoFragmentNFTsAvailable();
       }

       i_maxFragmentFusionNFTs = i_fragmentEngine.i_initialNFTCount();
       s_nextFragmentFusionTokenId = FragmentConstants.FUSION_STARTING_TOKEN_ID;
   }

   /*//////////////////////////////////////////////////////////////
                          FUSION FUNCTIONALITY
   //////////////////////////////////////////////////////////////*/

   /**
    * @notice Creates fusion NFT from Fragment NFT set previously burned in FragmentEngine
    * @dev Validates burn eligibility through FragmentEngine, verifies caller is original burner,
    *      checks fusion availability within supply limits, and mints unique fusion NFT.
    *      Updates fusion state mappings and records fusion metadata.
    * @param fragmentNftId The Fragment NFT ID of the burned Fragment NFT set to fuse
    * @return fusionTokenId The ID of the newly minted fusion NFT
    * @custom:security Validates burn eligibility, caller authorization, and fusion availability
    * @custom:validation Checks burn status, fusion eligibility, and supply limits before minting
    * @custom:integration Uses FragmentEngine.getFragmentSetBurner for burn verification
    * @custom:irreversible Fusion operation cannot be undone once completed
    * @custom:events Emits FragmentSetFused(fuser, fragmentNftId, fusionTokenId, timestamp)
    */
   function fuseFragmentSet(uint256 fragmentNftId) public returns (uint256 fusionTokenId) {
       _verifyFragmentFusionAddress(fragmentNftId);
       _verifyFragmentFusionSet(fragmentNftId);
       _verifyFragmentFusionMax();

       s_fragmentSetFused[fragmentNftId] = FragmentConstants.OPERATION_SUCCESS;
       s_nextFragmentFusionTokenId += FragmentConstants.INCREMENT_FUSION_TOKEN_ID;

       s_fragmentFusionInfo[s_nextFragmentFusionTokenId] = FragmentFusionInfo({
           fragmentNftId: fragmentNftId,
           fragmentFusedBy: msg.sender,
           fragmentFusedTimestamp: block.timestamp
       });

       s_fragmentTokenIdToFragmentFusionTokenId[fragmentNftId] = s_nextFragmentFusionTokenId;

       emit FragmentSetFused(
           msg.sender,
           fragmentNftId,
           s_nextFragmentFusionTokenId,
           block.timestamp
       );

       _safeMint(msg.sender, s_nextFragmentFusionTokenId);
       return s_nextFragmentFusionTokenId;
   }

   /*//////////////////////////////////////////////////////////////
                         VERIFICATION FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   /// @notice Validates caller is authorized to fuse specific Fragment NFT set burned in FragmentEngine
   /// @dev Security layer checking: Fragment NFT set burn status and caller authorization.
   ///      Verifies Fragment NFT set was burned and caller is the original burner.
   /// @param fragmentNftId The Fragment NFT ID to verify fusion eligibility for
   function _verifyFragmentFusionAddress(uint256 fragmentNftId) private view {
       address fragmentFusionRequestAddress = i_fragmentEngine.getFragmentSetBurner(fragmentNftId);

       if (fragmentFusionRequestAddress.isZeroAddress()) {
           revert FragmentErrors.FragmentFusion__SetNotBurned();
       } else if (fragmentFusionRequestAddress != msg.sender) {
           revert FragmentErrors.FragmentFusion__NotBurner();
       }
   }

   /// @notice Security layer preventing double fusion of same Fragment NFT set
   /// @dev Validates Fragment NFT set has not already been fused to prevent replay attacks.
   ///      Ensures each Fragment NFT set can only create one fusion NFT.
   /// @param fragmentNftId The Fragment NFT ID to check fusion status for
   function _verifyFragmentFusionSet(uint256 fragmentNftId) private view {
       if (s_fragmentSetFused[fragmentNftId] == FragmentConstants.OPERATION_SUCCESS) {
           revert FragmentErrors.FragmentFusion__AlreadyFused();
       }
   }

   /// @notice Defensive layer validating fusion supply limit has not been reached
   /// @dev Validates current fusion count against maximum allowed fusion NFTs.
   ///      Defensive programming explicitly validating design constraints.
   /// @param fragmentNftId The Fragment NFT ID to check fusion status for
   function _verifyFragmentFusionMax() private view {
       if (s_nextFragmentFusionTokenId.isFusionLimitReached(i_maxFragmentFusionNFTs)) {
           revert FragmentErrors.FragmentFusion__MaxFragmentFusionReached();
       }
   }

   /**
    * @notice External wrapper for burn eligibility and caller authorization validation
    * @dev Public wrapper for _verifyFragmentFusionAddress security layer.
    *      Validates Fragment NFT set burn status and caller authorization.
    * @param fragmentNftId The Fragment NFT ID to verify fusion eligibility for
    * @custom:security Security layer checking burn eligibility and caller authorization
    * @custom:frontend Available for frontend fusion eligibility checking
    */
   function verifyFragmentFusionAddress(uint256 fragmentNftId) public view {
       _verifyFragmentFusionAddress(fragmentNftId);
   }

   /**
    * @notice External wrapper for double fusion prevention validation
    * @dev Public wrapper for _verifyFragmentFusionSet security layer.
    *      Prevents double fusion attempts and replay attacks.
    * @param fragmentNftId The Fragment NFT ID to check fusion status for
    * @custom:security Security layer preventing double fusion and replay attacks
    * @custom:frontend Available for frontend fusion status checking
    */
   function verifyFragmentFusionSet(uint256 fragmentNftId) public view {
       _verifyFragmentFusionSet(fragmentNftId);
   }

   /**
    * @notice External wrapper for fusion supply limit validation
    * @dev Public wrapper for _verifyFragmentFusionMax defensive layer.
    *      Validates fusion operations against supply constraints.
    * @custom:security Defensive layer validating fusion supply constraints
    * @custom:frontend Available for frontend availability checking
    */
   function verifyFragmentFusionMax() public view {
       _verifyFragmentFusionMax();
   }

   /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   /**
    * @notice Retrieves fusion metadata for specific fusion NFT
    * @dev Returns FragmentFusionInfo struct containing: fragmentNftId, fragmentFusedBy, fragmentFusedTimestamp.
    *      Frontend utility for fusion NFT metadata queries and tracking.
    * @param fusionTokenId The fusion NFT token ID to query metadata for
    * @return fusionInfo Fusion metadata structure
    * @custom:integration Returns {fragmentNftId, fragmentFusedBy, fragmentFusedTimestamp}
    * @custom:metadata Fusion information containing original Fragment NFT ID, fuser address, and timestamp
    * @custom:frontend Frontend utility for fusion NFT information queries
    */
   function getFusedNFTInfo(uint256 fusionTokenId) public view returns (FragmentFusionInfo memory fusionInfo) {
       return s_fragmentFusionInfo[fusionTokenId];
   }

   /**
    * @notice Gets fusion NFT token ID corresponding to specific Fragment NFT ID
    * @dev Reverse lookup from Fragment NFT ID to fusion NFT token ID.
    *      Returns 0 if Fragment NFT set has not been fused. Frontend utility function.
    * @param fragmentNftId The Fragment NFT ID to lookup corresponding fusion NFT for
    * @return fusionTokenId The fusion NFT token ID (0 if not fused)
    * @custom:integration Enables Fragment NFT ID to fusion NFT token ID mapping
    * @custom:frontend Frontend utility for Fragment NFT to fusion NFT relationship tracking
    * @custom:validation Returns 0 for unfused Fragment NFT sets
    */
   function getFusedNftIdByFragmentNftId(uint256 fragmentNftId) public view returns (uint256 fusionTokenId) {
       return s_fragmentTokenIdToFragmentFusionTokenId[fragmentNftId];
   }

   /**
    * @notice Gets the next fusion NFT token ID that will be minted
    * @dev Frontend utility calculating next fusion token ID.
    *      Used in getFusionStatistics for statistical data aggregation.
    * @return nextTokenId The next fusion NFT token ID that will be minted
    * @custom:validation Current counter + 1 for next token calculation
    * @custom:frontend Frontend utility for fusion NFT ID tracking
    */
   function getNextFusionTokenId() public view returns (uint256 nextTokenId) {
       return s_nextFragmentFusionTokenId + FragmentConstants.INCREMENT_FUSION_TOKEN_ID;
   }

   /**
    * @notice Gets total number of fusion NFTs minted
    * @dev Frontend utility returning current fusion NFT supply count.
    *      Used in getFusionStatistics for statistical data aggregation.
    * @return minted The number of fusion NFTs that have been minted
    * @custom:validation Current fusion NFT supply count
    * @custom:frontend Frontend utility for fusion supply tracking
    */
   function getFusionNFTsMinted() public view returns (uint256 minted) {
       return s_nextFragmentFusionTokenId;
   }

   /**
    * @notice Gets number of fusion NFTs remaining to be minted
    * @dev Frontend utility calculating remaining fusion capacity within supply limits.
    *      Returns 0 when maximum fusion limit is reached.
    * @return remaining The number of fusion NFTs that can still be minted
    * @custom:validation Maximum minus current count (0 if at limit)
    * @custom:frontend Frontend utility for fusion capacity tracking
    */
   function getFusionNFTsRemaining() public view returns (uint256 remaining) {
       if (s_nextFragmentFusionTokenId.isFusionLimitReached(i_maxFragmentFusionNFTs)) {
           return FragmentConstants.ZERO_UINT;
       }
       return i_maxFragmentFusionNFTs - s_nextFragmentFusionTokenId;
   }

   /**
    * @notice Checks if specific Fragment NFT set has been fused
    * @dev Frontend utility for fusion status queries.
    *      Used for quick status checking and data retrieval.
    * @param fragmentNftId The Fragment NFT ID to check fusion status for
    * @return fused True if Fragment NFT set has been fused
    * @custom:validation Fusion status cannot change once set to true
    * @custom:frontend Frontend utility for fusion status queries
    */
   function isFragmentSetFused(uint256 fragmentNftId) public view returns (bool fused) {
       return s_fragmentSetFused[fragmentNftId];
   }

   /**
    * @notice Checks if fusion operations are available within supply limits
    * @dev Frontend utility returning current fusion availability status.
    *      Used for frontend fusion availability lookups.
    * @return available True if more fusion NFTs can be minted
    * @custom:validation Returns false when maximum fusion NFTs reached
    * @custom:frontend Frontend utility for fusion availability lookups
    */
   function isFusionAvailable() public view returns (bool available) {
       return !s_nextFragmentFusionTokenId.isFusionLimitReached(i_maxFragmentFusionNFTs);
   }

   /// @notice Gets fusion supply and status data in single query
   /// @dev Frontend utility aggregating multiple statistical data points.
   ///      Combines multiple queries for efficient frontend data retrieval.
   /// @return minted Number of fusion NFTs minted so far
   /// @return remaining Number of fusion NFTs remaining to mint
   /// @return maxAllowed Maximum number of fusion NFTs allowed
   /// @return nextTokenId The next fusion NFT token ID that will be minted
   function getFusionStatistics() public view returns (
       uint256 minted,
       uint256 remaining,
       uint256 maxAllowed,
       uint256 nextTokenId
   ) {
       minted = s_nextFragmentFusionTokenId;
       maxAllowed = i_maxFragmentFusionNFTs;
       remaining = getFusionNFTsRemaining();
       nextTokenId = getNextFusionTokenId();
   }

   /*//////////////////////////////////////////////////////////////
                       ADVANCED UTILITY FUNCTIONS
   //////////////////////////////////////////////////////////////*/

   /// @notice Validates fusion NFT token existence with ID range and ownership checks
   /// @dev Internal function used in getFusedNFTInfoSafe and wrapped by fusionTokenExists.
   ///      Frontend utility for fusion NFT existence checking.
   /// @param fusionTokenId The fusion NFT token ID to validate for existence
   /// @return exists True if fusion NFT token ID is valid and exists
   function _fusionTokenExists(uint256 fusionTokenId) internal view returns (bool exists) {
       return fusionTokenId.isValidFusionTokenId() &&
              fusionTokenId <= s_nextFragmentFusionTokenId &&
              !_ownerOf(fusionTokenId).isZeroAddress();
   }

   /**
    * @notice External wrapper for fusion NFT token existence checking
    * @dev Frontend utility function for fusion NFT existence queries.
    *      Used for frontend fusion NFT existence checking and data validation.
    * @param fusionTokenId The fusion NFT token ID to validate for existence
    * @return exists True if fusion NFT token ID is valid and exists
    * @custom:frontend Frontend utility for fusion NFT existence checking
    */
   function fusionTokenExists(uint256 fusionTokenId) public view returns (bool exists) {
       return _fusionTokenExists(fusionTokenId);
   }

   /**
    * @notice Fusion NFT information retrieval without revert on non-existent tokens
    * @dev Frontend utility function returning empty struct for non-existent fusion NFTs.
    *      Unlike getFusedNFTInfo which returns data for any input, this function validates existence first.
    * @param fusionTokenId The fusion NFT token ID to query
    * @return exists True if fusion NFT exists and data is valid
    * @return fusionInfo The fusion information (empty struct if fusion NFT doesn't exist)
    * @custom:frontend Frontend utility preventing reverts on non-existent fusion NFT queries
    */
   function getFusedNFTInfoSafe(uint256 fusionTokenId) public view returns (
       bool exists,
       FragmentFusionInfo memory fusionInfo
   ) {
       exists = _fusionTokenExists(fusionTokenId);
       if (exists) {
           fusionInfo = s_fragmentFusionInfo[fusionTokenId];
       }
   }
}
