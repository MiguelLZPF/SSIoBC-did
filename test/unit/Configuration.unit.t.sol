// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Configuration } from "@script/Configuration.s.sol";

contract ConfigurationUnitTest is Test {
  /// @dev Both branches live in ONE test function on purpose. vm.setEnv mutates the shared
  /// process environment and forge runs test functions in parallel, so two functions that
  /// each setEnv then construct Configuration race and fail non-deterministically.
  function test_getNetwork_readsNetworkNameWithChainIdFallback() public {
    vm.setEnv("NETWORK_NAME", "homelab");
    Configuration named = new Configuration();
    vm.setEnv("NETWORK_NAME", "");
    Configuration unnamed = new Configuration();

    vm.chainId(6660);
    (uint256 chainId, string memory name) = named.getNetwork();
    assertEq(chainId, 6660);
    assertEq(name, "homelab");

    vm.chainId(424242);
    (uint256 fallbackChainId, string memory fallbackName) = unnamed.getNetwork();
    assertEq(fallbackChainId, 424242);
    assertEq(fallbackName, "chain-424242");
  }
}
