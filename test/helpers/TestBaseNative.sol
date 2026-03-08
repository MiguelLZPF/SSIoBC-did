// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { IDidManagerNative } from "@interfaces/IDidManagerNative.sol";
import { IW3CResolver } from "@interfaces/IW3CResolver.sol";
import { DidManagerNativeScript } from "@script/DidManagerNative.s.sol";
import { W3CResolverNativeScript } from "@script/W3CResolverNative.s.sol";

/**
 * @title TestBaseNative
 * @notice Minimal base class for native variant tests with common utilities
 * @dev Provides deployment utilities and basic test infrastructure for DidManagerNative
 */
abstract contract TestBaseNative is Test {
  // Default test configuration
  uint256 internal constant DEFAULT_USER_BALANCE = 100 ether;

  // Core contracts
  IDidManagerNative internal didManagerNative;
  IW3CResolver internal w3cResolverNative;

  /**
   * @notice Deploys DidManagerNative and W3CResolverNative instances
   * @return The deployed DidManagerNative contract
   */
  function _deployDidManagerNative() internal returns (IDidManagerNative) {
    (didManagerNative,) = new DidManagerNativeScript().deploy(false, "", false);

    (w3cResolverNative,) = new W3CResolverNativeScript().deploy(didManagerNative, false, "", false);

    return didManagerNative;
  }

  /**
   * @notice Sets up a test user with balance and labels
   */
  function _setupUser(address user, string memory label) internal {
    vm.deal(user, DEFAULT_USER_BALANCE);
    vm.label(user, label);
  }

  /**
   * @notice Sets up multiple test users
   */
  function _setupUsers(address[] memory users, string[] memory labels) internal {
    require(users.length == labels.length, "TestBaseNative: users and labels length mismatch");
    for (uint256 i = 0; i < users.length; i++) {
      _setupUser(users[i], labels[i]);
    }
  }

  function _startPrank(address user) internal {
    vm.startPrank(user, user);
  }

  function _stopPrank() internal {
    vm.stopPrank();
  }
}
