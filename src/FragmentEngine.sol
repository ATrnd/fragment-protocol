// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IFragmentEngine} from "./interfaces/IFragmentEngine.sol";
import {IRandomnessProvider} from "./interfaces/IRandomnessProvider.sol";
import {FragmentConstants} from "./constants/FragmentConstants.sol";
import {FragmentErrors} from "./constants/FragmentErrors.sol";
import {FragmentValidationLibrary} from "./libraries/FragmentValidationLibrary.sol";

/**
* @title Fragment Engine
* @author ATrnd
* @notice Core fragment NFT engine implementing fragment-based ownership primitive
* @dev Implements ERC721 standard for fragment tokens where complete NFTs are composed of exactly 4 collectible fragments.
*      Manages fragment minting with circulation-based distribution, burn operations for fusion eligibility,
*      and autonomous NFT lifecycle management through swap-and-pop circulation updates.
*      Uses development-grade block-based randomness for prototype fragment distribution.
* @custom:version 1.0.0
* @custom:scope Core Fragment Protocol implementation
* @custom:purpose Fragment-based NFT ownership primitive with mint, burn, and circulation management
* @custom:integration Works with FragmentFusion for burn-to-fuse transformation workflow
* @custom:security Reentrancy protected with comprehensive ownership validation for burn operations
* @custom:randomness Uses development-grade randomness suitable for prototype validation
* @custom:lifecycle Autonomous circulation management with no admin controls post-deployment
*/
contract FragmentEngine is IFragmentEngine, ERC721Enumerable, ReentrancyGuard {

  /*//////////////////////////////////////////////////////////////
                          LIBRARY INTEGRATIONS
  //////////////////////////////////////////////////////////////*/

  using FragmentValidationLibrary for uint256;
  using FragmentValidationLibrary for address;

  /*//////////////////////////////////////////////////////////////
                         IMMUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice The initial number of Fragment NFT IDs configured for fragment minting
  /// @dev Set during contract deployment, cannot be modified post-initialization.
  ///      Used by FragmentFusion to determine maximum fusion NFT supply limit.
  /// @custom:validation Immutable post-deployment, prevents configuration changes after initialization
  /// @custom:integration Referenced by FragmentFusion.i_maxFragmentFusionNFTs calculation
  uint256 public immutable i_initialNFTCount;

  /// @notice Reference to the randomness provider for fragment distribution
  /// @dev Contract interface for generating random indices during fragment minting operations.
  ///      Currently configured with development-grade block-based randomness for prototyping.
  /// @custom:randomness Development implementation using block.timestamp and caller entropy
  /// @custom:integration IRandomnessProvider interface enables future randomness upgrades
  IRandomnessProvider public immutable i_randomnessProvider;

  /*//////////////////////////////////////////////////////////////
                         MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice ID of the most recently minted fragment token
  /// @dev Increments after each successful mint operation, starting from 0 at deployment.
  ///      Next token to be minted will have ID of (s_nextFragmentTokenId + 1).
  /// @custom:validation Sequential progression ensures unique token identification
  /// @custom:integration Public for external token ID prediction and supply tracking
  uint256 public s_nextFragmentTokenId;

  /// @notice Fragment NFT IDs available for fragment minting operations
  /// @dev Initialized from constructor _initialNftIds parameter, shrinks as fragment sets complete.
  ///      Uses swap-and-pop pattern for efficient removal when Fragment NFT IDs reach 4 fragments.
  /// @custom:validation Array length decreases as Fragment NFT sets are completed and removed
  /// @custom:integration Used by randomness provider for Fragment NFT ID selection during minting
  uint256[] private s_availableFragmentNftIds;

  /// @notice Tracks burned Fragment NFT sets by Fragment NFT ID and burner address for replay attack prevention
  /// @dev Maps Fragment NFT ID => burner address => burned status to prevent double-burning.
  ///      Used by _isFragmentSetBurned for replay attack prevention in burn operations.
  /// @custom:security Prevents replay attacks by tracking burn status per Fragment NFT ID and burner
  /// @custom:burn Essential for _burnFragmentSet replay protection validation
  mapping(uint256 => mapping(address => bool)) private s_fragmentBurnedSets;

  /// @notice Maps Fragment NFT IDs to their circulation array index position
  /// @dev Used for efficient swap-and-pop removal in _removeNFTFromCirculation when sets complete.
  ///      Initialized in _initializeFirstFragment, enables O(1) removal performance.
  /// @custom:optimization Enables O(1) removal from circulation array
  /// @custom:circulation Updated during first fragment mint and NFT removal operations
  mapping(uint256 => uint256) private s_fragmentNftIdToAvailableIndex;

  /// @notice Number of fragments minted for each Fragment NFT ID
  /// @dev Maps Fragment NFT ID => count of minted fragments (0-4) for completion tracking.
  ///      Used in getFragmentTokenIds for burn verification and completion status.
  /// @custom:validation Tracks fragment completion progress for circulation management
  /// @custom:burn Used by _verifyFragmentSet in burn operations for completeness validation
  mapping(uint256 => uint256) private s_mintedFragmentsCount;

  /// @notice Fragment metadata for each minted token
  /// @dev Maps token ID => Fragment struct containing Fragment NFT ID and fragment position (1-4).
  ///      Core data structure linking fragment tokens to their parent Fragment NFT sets.
  mapping(uint256 => Fragment) public s_fragmentData;

  /// @notice Maps ERC721 token IDs to their parent Fragment NFT IDs
  /// @dev Maps token ID => Fragment NFT ID for reverse lookup from token ID to Fragment NFT ID.
  ///      Enables efficient token-to-Fragment NFT ID identification.
  mapping(uint256 => uint256) private s_tokenIdToFragmentNftId;

  /// @notice Maps Fragment NFT ID and fragment position to token ID
  /// @dev Maps Fragment NFT ID => fragment ID (1-4) => token ID for direct fragment lookup.
  ///      Enables efficient retrieval of specific fragments within Fragment NFT sets.
  mapping(uint256 => mapping(uint256 => uint256)) private s_fragmentNftIdToFragmentTokenId;

  /// @notice Records the burner address for each burned Fragment NFT set
  /// @dev Maps Fragment NFT ID => burner address, used in FragmentFusion._verifyFragmentFusionAddress.
  ///      Returns address(0) for unburned sets or non-existent Fragment NFT IDs.
  /// @custom:fusion Used by FragmentFusion.getFragmentSetBurner for burn eligibility verification
  /// @custom:integration Essential for burn-to-fuse workflow access control
  mapping(uint256 => address) private s_fragmentSetBurner;

  /// @notice Burn metadata for each Fragment NFT set
  /// @dev Maps Fragment NFT ID => BurnInfo struct containing burner address and timestamp.
  ///      Stores burn metadata for external query and tracking purposes.
  /// @custom:metadata Burn information storage for external query functions
  /// @custom:frontend Available for frontend tracking and analytics purposes
  mapping(uint256 => BurnInfo) private s_fragmentSetBurnInfo;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes Fragment Engine with randomness provider and Fragment NFT configuration
  /// @dev Sets up immutable references and initializes circulation array with provided Fragment NFT IDs.
  ///      Contract becomes immediately operational with no additional setup required.
  /// @param _randomnessProvider Address of contract implementing IRandomnessProvider interface
  /// @param _initialNftIds Array of Fragment NFT IDs available for fragment minting operations
  /// @custom:validation Sets immutable references and copies Fragment NFT IDs to circulation array
  /// @custom:integration Provider must implement IRandomnessProvider for minting operations
  constructor(
      address _randomnessProvider,
      uint256[] memory _initialNftIds
  ) ERC721(FragmentConstants.TOKEN_FRAGMENT_NAME, FragmentConstants.TOKEN_FRAGMENT_SYMBOL) {
      i_randomnessProvider = IRandomnessProvider(_randomnessProvider);
      i_initialNFTCount = _initialNftIds.length;
      s_availableFragmentNftIds = _initialNftIds;
      s_nextFragmentTokenId = FragmentConstants.FRAGMENT_STARTING_TOKEN_ID;
  }

  /*//////////////////////////////////////////////////////////////
                       MINT FUNCTIONALITY
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Mints a random fragment from available Fragment NFT circulation
   * @dev Selects Fragment NFT ID using randomness provider, calculates next fragment ID (1-4) based on current
   *      Fragment NFT ID state, initializes first fragment tracking if needed, and removes Fragment NFT ID
   *      from circulation when 4th fragment is minted. Emits FragmentMinted and optionally NFTRemovedFromCirculation.
   * @return tokenId The ID of the newly minted fragment token
   * @custom:security Reentrancy protected to prevent state manipulation during minting
   * @custom:integration Depends on IRandomnessProvider for fair Fragment NFT ID selection
   * @custom:validation Requires at least one Fragment NFT ID in circulation for minting
   * @custom:events Emits FragmentMinted(minter, tokenId, fragmentNftId, fragmentId)
   * @custom:circulation Automatically removes Fragment NFT ID when 4th fragment is minted
   */
  function mint() public nonReentrant returns (uint256) {
      _validateFragmentNFTsAvailable();

      uint256 randomIndex = i_randomnessProvider.generateRandomIndex(
          s_availableFragmentNftIds.length,
          s_nextFragmentTokenId
      );

      uint256 selectedFragmentNftId = s_availableFragmentNftIds[randomIndex];
      uint256 fragmentCountId = _getNextAvailableFragmentId(selectedFragmentNftId);
      s_nextFragmentTokenId = _getNextFragmentTokenId(s_nextFragmentTokenId);

      _initializeFirstFragment(selectedFragmentNftId, randomIndex);

      s_fragmentData[s_nextFragmentTokenId] = Fragment({
          fragmentNftId: selectedFragmentNftId,
          fragmentId: fragmentCountId
      });

      s_mintedFragmentsCount[selectedFragmentNftId] += FragmentConstants.INCREMENT_MINTED_FRAGMENT;
      s_fragmentNftIdToFragmentTokenId[selectedFragmentNftId][fragmentCountId] = s_nextFragmentTokenId;
      s_tokenIdToFragmentNftId[s_nextFragmentTokenId] = selectedFragmentNftId;

      emit FragmentMinted(
          msg.sender,
          s_nextFragmentTokenId,
          selectedFragmentNftId,
          fragmentCountId
      );

      _removeNFTIfCompleted(selectedFragmentNftId);
      _safeMint(msg.sender, s_nextFragmentTokenId);

      return s_nextFragmentTokenId;
  }

  /*//////////////////////////////////////////////////////////////
                     BURN FUNCTIONALITY
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Burns complete fragment set (4 fragments) for specific Fragment NFT ID
   * @dev Validates Fragment NFT ID has exactly 4 minted fragments owned by caller,
   *      prevents replay attacks, destroys all 4 fragment tokens, and records burn metadata.
   * @param fragmentNftId The Fragment NFT ID of the complete fragment set to burn
   * @return success True if burning completed successfully (always true or reverts)
   * @custom:security Prevents replay attacks, validates Fragment NFT ID existence, fragment completeness, and ownership
   * @custom:validation Checks: replay prevention, Fragment NFT ID existence, 4-fragment completeness, caller ownership
   * @custom:metadata Records burn information for external query purposes
   * @custom:irreversible Burn operation permanently destroys fragment tokens
   * @custom:events Emits FragmentSetBurned(burner, fragmentNftId)
   */
  function burnFragmentSet(uint256 fragmentNftId) public nonReentrant returns (bool success) {
      return _burnFragmentSet(fragmentNftId);
  }

  /// @notice Internal burn implementation with comprehensive validation and state updates
  /// @dev Validates: replay prevention, Fragment NFT ID verification, fragment completeness, ownership verification.
  ///      Updates burn state mappings and destroys all fragment tokens via _burn calls.
  /// @param fragmentNftId The Fragment NFT ID of the set to burn
  /// @return success True if burning completed successfully
  function _burnFragmentSet(uint256 fragmentNftId) internal returns (bool success) {
      if (_isFragmentSetBurned(fragmentNftId)) {
          revert FragmentErrors.FragmentEngine__SetAlreadyBurned();
      }

      bool verified = _verifyFragmentSet(fragmentNftId);
      if (!verified) {
          revert FragmentErrors.FragmentEngine__SetVerificationFailed();
      }

      s_fragmentBurnedSets[fragmentNftId][msg.sender] = FragmentConstants.OPERATION_SUCCESS;
      s_fragmentSetBurner[fragmentNftId] = msg.sender;

      s_fragmentSetBurnInfo[fragmentNftId] = BurnInfo({
          burner: msg.sender,
          burnTimestamp: block.timestamp
      });

      uint256[] memory fragmentTokenIds = getFragmentTokenIds(fragmentNftId);
      for (uint256 i = FragmentConstants.ZERO_UINT; i < FragmentConstants.SYSTEM_MAX_FRAGMENTS_PER_NFT; i += FragmentConstants.INCREMENT_INDEX) {
          uint256 fragmentTokenId = fragmentTokenIds[i];
          _burn(fragmentTokenId);
      }

      emit FragmentSetBurned(msg.sender, fragmentNftId);
      return FragmentConstants.OPERATION_SUCCESS;
  }

  /*//////////////////////////////////////////////////////////////
                     VERIFICATION FUNCTIONALITY
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Validates Fragment NFT ID existence, fragment completeness, and caller ownership
   * @dev Validates: Fragment NFT ID existence (prevents FragmentEngine__NonexistentNftId),
   *      fragment completeness (prevents FragmentEngine__IncompleteSet),
   *      caller ownership (prevents FragmentEngine__NotOwnerOfAll).
   *      Used internally by _burnFragmentSet for burn authorization.
   * @param fragmentNftId The Fragment NFT ID to validate for burn eligibility
   * @return verified True if verification passed (always true or reverts on failure)
   * @custom:validation Validates Fragment NFT ID existence, 4-fragment completeness, and caller ownership
   * @custom:burn Essential component of _burnFragmentSet authorization process
   * @custom:security Comprehensive validation prevents unauthorized burn operations
   * @custom:view Read-only operation safe for external calls
   */
  function verifyFragmentSet(uint256 fragmentNftId) public view returns (bool verified) {
      return _verifyFragmentSet(fragmentNftId);
  }

  /// @notice Internal verification implementation with specific error conditions
  /// @dev Validates existence, completeness, and ownership with specific error revert conditions.
  ///      Core validation logic for burn operation authorization.
  /// @param fragmentNftId The Fragment NFT ID to verify
  /// @return verified True if verification passed
  function _verifyFragmentSet(uint256 fragmentNftId) internal view returns (bool verified) {
      if (s_mintedFragmentsCount[fragmentNftId].hasNoFragmentsAvailable()) {
          revert FragmentErrors.FragmentEngine__NonexistentNftId();
      }

      uint256[] memory fragmentTokenIds = getFragmentTokenIds(fragmentNftId);
      if (!fragmentTokenIds.length.isFragmentSetComplete()) {
          revert FragmentErrors.FragmentEngine__IncompleteSet();
      }

      for (uint256 i = FragmentConstants.ZERO_UINT; i < FragmentConstants.SYSTEM_MAX_FRAGMENTS_PER_NFT; i += FragmentConstants.INCREMENT_INDEX) {
          uint256 fragmentTokenId = fragmentTokenIds[i];

          if (ownerOf(fragmentTokenId) != msg.sender) {
              revert FragmentErrors.FragmentEngine__NotOwnerOfAll();
          }
      }

      return FragmentConstants.OPERATION_SUCCESS;
  }

  /*//////////////////////////////////////////////////////////////
                     CIRCULATION MANAGEMENT
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes circulation index tracking when first fragment is minted for Fragment NFT ID
  /// @dev Sets s_fragmentNftIdToAvailableIndex mapping when Fragment NFT ID has zero fragments minted.
  ///      Enables tracking of Fragment NFT ID position in circulation array for efficient removal.
  ///      Required for swap-and-pop removal in _removeNFTFromCirculation.
  /// @param fragmentNftId The Fragment NFT ID to initialize circulation tracking for
  /// @param randomIndex The index position in circulation array for this Fragment NFT ID
  function _initializeFirstFragment(uint256 fragmentNftId, uint256 randomIndex) private {
      if(s_mintedFragmentsCount[fragmentNftId].hasNoFragmentsAvailable()) {
          s_fragmentNftIdToAvailableIndex[fragmentNftId] = randomIndex;
      }
  }

  /// @notice Checks fragment completion and triggers circulation removal when Fragment NFT ID reaches 4 fragments
  /// @dev Validates if Fragment NFT ID has reached maximum fragments (4) and triggers removal
  ///      via _removeNFTFromCirculation using swap-and-pop pattern. Emits NFTRemovedFromCirculation event.
  /// @param fragmentNftId The Fragment NFT ID to check for completion and potential removal
  function _removeNFTIfCompleted(uint256 fragmentNftId) private {
      if (s_mintedFragmentsCount[fragmentNftId].isFragmentCountAtMaximum()) {
          _removeNFTFromCirculation(fragmentNftId);
          emit NFTRemovedFromCirculation(fragmentNftId, block.timestamp);
      }
  }

  /// @notice Removes Fragment NFT ID from circulation using swap-and-pop optimization
  /// @dev Implements O(1) removal by swapping with last element and popping from array.
  ///      When Fragment NFT ID is removed, no additional fragments can be minted for that ID,
  ///      permanently reducing total available Fragment NFT supply.
  /// @param fragmentNftId The Fragment NFT ID to remove from circulation
  function _removeNFTFromCirculation(uint256 fragmentNftId) private {
      uint256 index = s_fragmentNftIdToAvailableIndex[fragmentNftId];
      uint256 lastIndex = s_availableFragmentNftIds.length - FragmentConstants.INCREMENT_INDEX;

      if (!index.isLastArrayIndex(s_availableFragmentNftIds.length)) {
          uint256 lastNftId = s_availableFragmentNftIds[lastIndex];
          s_availableFragmentNftIds[index] = lastNftId;
          s_fragmentNftIdToAvailableIndex[lastNftId] = index;
      }

      s_availableFragmentNftIds.pop();
      delete s_fragmentNftIdToAvailableIndex[fragmentNftId];
  }

  /*//////////////////////////////////////////////////////////////
                     UTILITY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Validates Fragment NFT IDs are available for minting operations
  /// @dev Reverts if circulation array is empty (no Fragment NFT IDs available for minting)
  function _validateFragmentNFTsAvailable() private view {
      if (!s_availableFragmentNftIds.length.hasArrayElements()) {
          revert FragmentErrors.FragmentEngine__NoFragmentNFTsAvailable();
      }
  }

  /// @notice Calculates next available fragment ID for specific Fragment NFT ID based on current mint count
  /// @dev Returns fragment ID (1-4) for next fragment to be minted for specific Fragment NFT ID.
  ///      Based on current fragment count for the Fragment NFT ID.
  /// @param fragmentNftId The Fragment NFT ID to calculate next fragment ID for
  /// @return nextFragmentId The next available fragment ID (1-4)
  function _getNextAvailableFragmentId(uint256 fragmentNftId) private view returns (uint256 nextFragmentId) {
      return (s_mintedFragmentsCount[fragmentNftId] + FragmentConstants.INCREMENT_FRAGMENT_ID);
  }

  /// @notice Calculates next fragment token ID in sequential progression
  /// @dev Simple increment function for fragment token ID advancement in global sequence
  /// @param fragmentTokenId Current fragment token ID
  /// @return nextFragmentTokenId Next fragment token ID in sequence (current + 1)
  function _getNextFragmentTokenId(uint256 fragmentTokenId) private pure returns(uint256 nextFragmentTokenId) {
      return fragmentTokenId + FragmentConstants.INCREMENT_TOKEN_ID;
  }

  /// @notice Checks if Fragment NFT set (4 fragments from same Fragment NFT ID) has been burned by caller
  /// @dev Returns burn status for specific Fragment NFT ID and caller address
  /// @param fragmentNftId The Fragment NFT ID to check burn status for
  /// @return True if Fragment NFT set was burned by caller (msg.sender)
  function _isFragmentSetBurned(uint256 fragmentNftId) private view returns (bool) {
      return s_fragmentBurnedSets[fragmentNftId][msg.sender];
  }

  /*//////////////////////////////////////////////////////////////
                     PUBLIC VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Public wrapper for calculating next fragment token ID
  /// @param fragmentTokenId Current token ID
  /// @return nextFragmentTokenId Next token ID in sequence
  function getNextFragmentTokenId(uint256 fragmentTokenId) public pure returns(uint256 nextFragmentTokenId) {
      return _getNextFragmentTokenId(fragmentTokenId);
  }

  /// @notice Public wrapper for calculating next available fragment ID for Fragment NFT ID
  /// @param fragmentNftId The Fragment NFT ID to query
  /// @return nextFragmentId The next available fragment ID
  function getNextAvailableFragmentId(uint256 fragmentNftId) public view returns (uint256 nextFragmentId) {
      return _getNextAvailableFragmentId(fragmentNftId);
  }

  /**
   * @notice Gets Fragment NFT IDs currently available for fragment minting
   * @dev Returns dynamic array of Fragment NFT IDs that shrinks as fragment sets complete.
   *      Each Fragment NFT ID represents a set that can have up to 4 fragments minted.
   * @return nftIds Array of Fragment NFT IDs available for minting operations
   * @custom:integration Used by randomness provider for Fragment NFT ID selection during minting
   * @custom:circulation Array size decreases as Fragment NFT sets complete and are removed
   * @custom:frontend Available for frontend tracking of remaining mintable Fragment NFT IDs
   */
  function getNFTsInCirculation() public view returns (uint256[] memory nftIds) {
      return s_availableFragmentNftIds;
  }

  /**
   * @notice Gets number of fragments remaining to be minted for specific Fragment NFT ID
   * @dev Calculates remaining capacity by subtracting minted count from maximum (4).
   *      Returns 0 when Fragment NFT ID is complete or if Fragment NFT ID doesn't exist.
   * @param fragmentNftId The Fragment NFT ID to query remaining capacity for
   * @return fragmentsLeft Number of fragments that can still be minted (0-4)
   * @custom:validation MAX_FRAGMENTS (4) minus current minted count for Fragment NFT ID
   * @custom:circulation Returns 0 when all 4 fragments minted and Fragment NFT ID removed
   * @custom:frontend Utility function for frontend progress tracking and completion status
   */
  function getFragmentsLeftForNFT(uint256 fragmentNftId) public view returns (uint256 fragmentsLeft) {
      return FragmentConstants.SYSTEM_MAX_FRAGMENTS_PER_NFT - s_mintedFragmentsCount[fragmentNftId];
  }

  /**
   * @notice Retrieves complete fragment metadata for specific fragment token
   * @dev Returns Fragment struct containing Fragment NFT ID and fragment position (1-4).
   *      Used for fragment identification and relationship tracking.
   * @param tokenId The fragment token ID to query metadata for
   * @return fragment Fragment data structure with Fragment NFT ID and fragment ID
   * @custom:integration Returns {fragmentNftId: uint256, fragmentId: uint256}
   * @custom:validation fragmentId will be between 1-4 for valid fragments
   * @custom:frontend Fragment identification utility for external systems
   */
  function getFragmentData(uint256 tokenId) public view returns (Fragment memory fragment) {
      return s_fragmentData[tokenId];
  }

  /// @notice Gets Fragment NFT ID associated with fragment token
  /// @dev Reverse lookup from fragment token ID to Fragment NFT ID due to random minting order.
  ///      Fragment tokens are assigned sequential token IDs but belong to randomly selected Fragment NFT IDs.
  /// @param tokenId The fragment token ID to lookup parent Fragment NFT ID for
  /// @return The Fragment NFT ID this fragment token belongs to
  function getFragmentNftIdByTokenId(uint256 tokenId) public view returns (uint256) {
      return s_tokenIdToFragmentNftId[tokenId];
  }

  /**
   * @notice Gets all fragment token IDs for specific Fragment NFT ID in sequential order
   * @dev Returns array of fragment token IDs ordered by fragment position (1,2,3,4).
   *      Used by _verifyFragmentSet for completeness validation and _burnFragmentSet for token destruction.
   * @param nftId The Fragment NFT ID to query fragment token IDs for
   * @return tokenIds Array of fragment token IDs belonging to Fragment NFT ID
   * @custom:burn Used by _verifyFragmentSet for FragmentEngine__IncompleteSet validation and _burnFragmentSet for token removal
   * @custom:validation Returns fragments in sequential order (fragment 1,2,3,4)
   * @custom:completion Array length indicates Fragment NFT ID completion status (0-4)
   */
  function getFragmentTokenIds(uint256 nftId) public view returns (uint256[] memory tokenIds) {
      uint256 fragmentCount = s_mintedFragmentsCount[nftId];
      tokenIds = new uint256[](fragmentCount);

      for (uint256 i = FragmentConstants.ZERO_UINT; i < fragmentCount; i += FragmentConstants.INCREMENT_INDEX) {
          tokenIds[i] = s_fragmentNftIdToFragmentTokenId[nftId][i + FragmentConstants.INCREMENT_FRAGMENT_ID];
      }

      return tokenIds;
  }

  /**
   * @notice Gets address that burned specific Fragment NFT set (4 fragments from same Fragment NFT ID)
   * @dev Returns burner address for FragmentFusion eligibility verification via FragmentFusion.getFragmentSetBurner.
   *      Returns address(0) if Fragment NFT set has not been burned or Fragment NFT ID doesn't exist.
   * @param fragmentNftId The Fragment NFT ID to check burn status for
   * @return burner The address that burned the Fragment NFT set, or address(0) if not burned
   * @custom:fusion Used by FragmentFusion._verifyFragmentFusionAddress for burn eligibility verification
   * @custom:integration Essential for burn-to-fuse workflow access control in FragmentFusion
   * @custom:security Returns zero address for unburned sets or non-existent Fragment NFT IDs
   */
  function getFragmentSetBurner(uint256 fragmentNftId) public view returns (address burner) {
      return s_fragmentSetBurner[fragmentNftId];
  }

  /**
   * @notice Gets burn metadata for specific Fragment NFT set (4 fragments from same Fragment NFT ID)
   * @dev Returns BurnInfo struct with burner address and burn timestamp for external query.
   *      May return zero values if Fragment NFT set has not been burned or Fragment NFT ID doesn't exist.
   * @param fragmentNftId The Fragment NFT ID to query burn information for
   * @return burnInfo Burn information including burner address and timestamp
   * @custom:integration Returns {burner: address, burnTimestamp: uint256}
   * @custom:frontend Burn metadata utility for external query and analytics
   * @custom:metadata Complete burn information storage for tracking purposes
   */
  function getFragmentSetBurnInfo(uint256 fragmentNftId) public view returns (BurnInfo memory burnInfo) {
      return s_fragmentSetBurnInfo[fragmentNftId];
  }

  /**
   * @notice Utility function to check if Fragment NFT set (4 fragments from same Fragment NFT ID) was burned by specific address
   * @dev Frontend utility function for checking if specific address burned specific Fragment NFT set.
   *      Not used by other contracts - available for external query purposes.
   * @param fragmentNftId The Fragment NFT ID to check burn status for
   * @param burnerAddress The address to verify burned the Fragment NFT set
   * @return burned True if Fragment NFT set was burned by specified address
   * @custom:frontend Utility function for external query and frontend integration
   * @custom:unused Not used by other contracts - external utility function only
   */
  function isFragmentSetBurnedByAddress(uint256 fragmentNftId, address burnerAddress) public view returns (bool burned) {
      return s_fragmentBurnedSets[fragmentNftId][burnerAddress];
  }
}
