// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
import { IDidManager } from "@src/interfaces/IDidManager.sol";
import { IW3CResolver } from "@src/interfaces/IW3CResolver.sol";
import { DidManagerScript } from "@script/DidManager.s.sol";
import { W3CResolverScript } from "@script/W3CResolver.s.sol";

/**
 * @title TestBase
 * @notice Minimal base class for all tests with common utilities
 * @dev Provides deployment utilities and basic test infrastructure
 */
abstract contract TestBase is Test {
    // Default test configuration
    uint256 internal constant DEFAULT_USER_BALANCE = 100 ether;
    address internal constant TEST_DEFAULT_SENDER = address(0);

    // Core contracts
    IDidManager internal didManager;
    IW3CResolver internal w3cResolver;

    /**
     * @notice Deploys DidManager and W3CResolver instances
     * @return The deployed DidManager contract
     */
    function _deployDidManager() internal returns (IDidManager) {
        (didManager, ) = new DidManagerScript().deploy(
            false, // store
            "", // tag
            false // broadcast
        );

        // Deploy W3CResolver with didManager
        (w3cResolver, ) = new W3CResolverScript().deploy(
            didManager,
            false, // store
            "", // tag
            false // broadcast
        );

        return didManager;
    }

    /**
     * @notice Sets up a test user with balance and labels
     * @param user The user address to setup
     * @param label The label for the user
     */
    function _setupUser(address user, string memory label) internal {
        vm.deal(user, DEFAULT_USER_BALANCE);
        vm.label(user, label);
    }

    /**
     * @notice Sets up multiple test users
     * @param users Array of user addresses
     * @param labels Array of corresponding labels
     */
    function _setupUsers(address[] memory users, string[] memory labels) internal {
        require(users.length == labels.length, "TestBase: users and labels length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            _setupUser(users[i], labels[i]);
        }
    }

    /**
     * @notice Helper to start pranking as a user
     * @param user The user to prank as
     */
    function _startPrank(address user) internal {
        vm.startPrank(user, user);
    }

    /**
     * @notice Helper to stop current prank
     */
    function _stopPrank() internal {
        vm.stopPrank();
    }
}