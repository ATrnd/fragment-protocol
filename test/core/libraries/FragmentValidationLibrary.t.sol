// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FragmentValidationLibrary} from "../../../src/libraries/FragmentValidationLibrary.sol";

/**
* @title Fragment Validation Library Test
* @author ATrnd
* @notice Fragment validation utilities test
*/
contract FragmentValidationLibraryTest is Test {

   function test_hasNoFragmentsAvailable_basicValidation() public pure {
       assertTrue(
           FragmentValidationLibrary.hasNoFragmentsAvailable(0),
           "Should return true for zero fragment availability"
       );

       assertFalse(
           FragmentValidationLibrary.hasNoFragmentsAvailable(1),
           "Should return false for 1 fragment available"
       );

       assertFalse(
           FragmentValidationLibrary.hasNoFragmentsAvailable(4),
           "Should return false for 4 fragments available"
       );
   }

   function test_isZeroAddress_basicValidation() public view {
       assertTrue(
           FragmentValidationLibrary.isZeroAddress(address(0)),
           "Should return true for zero address"
       );

       assertFalse(
           FragmentValidationLibrary.isZeroAddress(address(1)),
           "Should return false for address(1)"
       );

       assertFalse(
           FragmentValidationLibrary.isZeroAddress(address(this)),
           "Should return false for contract address"
       );
   }

   function test_isFragmentSetComplete_basicValidation() public pure {
       assertTrue(
           FragmentValidationLibrary.isFragmentSetComplete(4),
           "Should return true for exactly 4 fragments"
       );

       assertFalse(
           FragmentValidationLibrary.isFragmentSetComplete(0),
           "Should return false for 0 fragments"
       );

       assertFalse(
           FragmentValidationLibrary.isFragmentSetComplete(3),
           "Should return false for 3 fragments"
       );
   }

   function test_isFragmentCountAtMaximum_basicValidation() public pure {
       assertTrue(
           FragmentValidationLibrary.isFragmentCountAtMaximum(4),
           "Should return true for exactly 4 fragments"
       );

       assertTrue(
           FragmentValidationLibrary.isFragmentCountAtMaximum(5),
           "Should return true for 5 fragments"
       );

       assertFalse(
           FragmentValidationLibrary.isFragmentCountAtMaximum(3),
           "Should return false for 3 fragments"
       );
   }

   function test_isValidFusionTokenId_basicValidation() public pure {
       assertTrue(
           FragmentValidationLibrary.isValidFusionTokenId(1),
           "Should return true for fusion token ID 1"
       );

       assertTrue(
           FragmentValidationLibrary.isValidFusionTokenId(100),
           "Should return true for fusion token ID 100"
       );

       assertFalse(
           FragmentValidationLibrary.isValidFusionTokenId(0),
           "Should return false for fusion token ID 0"
       );
   }

   function test_isFusionLimitReached_basicValidation() public pure {
       uint256 maxAllowed = 10;

       assertTrue(
           FragmentValidationLibrary.isFusionLimitReached(10, maxAllowed),
           "Should return true when current equals max allowed"
       );

       assertTrue(
           FragmentValidationLibrary.isFusionLimitReached(11, maxAllowed),
           "Should return true when current exceeds max allowed"
       );

       assertFalse(
           FragmentValidationLibrary.isFusionLimitReached(9, maxAllowed),
           "Should return false when current below max allowed"
       );
   }

   function test_isLastArrayIndex_basicValidation() public pure {
       uint256 arrayLength = 5;

       assertTrue(
           FragmentValidationLibrary.isLastArrayIndex(4, arrayLength),
           "Should return true for last index (4) in array of length 5"
       );

       assertFalse(
           FragmentValidationLibrary.isLastArrayIndex(3, arrayLength),
           "Should return false for index 3 in array of length 5"
       );
   }

   function test_hasArrayElements_basicValidation() public pure {
       assertTrue(
           FragmentValidationLibrary.hasArrayElements(5),
           "Should return true for array length 5"
       );

       assertTrue(
           FragmentValidationLibrary.hasArrayElements(1),
           "Should return true for array length 1"
       );

       assertFalse(
           FragmentValidationLibrary.hasArrayElements(0),
           "Should return false for array length 0"
       );
   }
}
