// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Configuration } from "@script/Configuration.s.sol";

contract ConfigurationUnitTest is Test {
  /// @dev Configuration reads env vars in field initializers, so setEnv must
  /// precede construction. A Configuration built before setEnv sees the old value.
  function test_getNetwork_usesNetworkNameEnv() public {
    vm.setEnv("NETWORK_NAME", "homelab");
    Configuration config = new Configuration();
    vm.chainId(6660);
    (uint256 chainId, string memory name) = config.getNetwork();
    assertEq(chainId, 6660);
    assertEq(name, "homelab");
  }

  function test_getNetwork_fallsBackToChainId() public {
    vm.setEnv("NETWORK_NAME", "");
    Configuration config = new Configuration();
    vm.chainId(424242);
    (uint256 chainId, string memory name) = config.getNetwork();
    assertEq(chainId, 424242);
    assertEq(name, "chain-424242");
  }
}
