// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Configuration, Deployment } from "@script/Configuration.s.sol";

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

  /// @dev Both scenarios live in ONE test function on purpose, same reasoning as
  /// test_getNetwork_readsNetworkNameWithChainIdFallback above: vm.setEnv mutates the
  /// shared process environment and forge runs test functions in parallel, so two
  /// functions that each setEnv("DEPLOYMENTS_PATH", ...) then construct Configuration
  /// race and fail non-deterministically. Each scenario uses its own temp path so the
  /// two runs, sequential within this one function, cannot interfere with each other.
  function test_storeAndRetrieveDeployment_roundTripsAndReplaces() public {
    // .temp/ is gitignored, so a clean checkout does not have it; create it before
    // any vm.writeFile below or this test fails on first run from a fresh clone.
    vm.createDir("./.temp", true);

    // Scenario 1: store then retrieve round-trips the full struct.
    string memory roundTripPath = "./.temp/test-deployments.json";
    vm.writeFile(roundTripPath, "{}");
    vm.setEnv("DEPLOYMENTS_PATH", roundTripPath);
    Configuration roundTripConfig = new Configuration();

    Deployment memory d = Deployment({
      bytecodeHash: keccak256("code"),
      chainId: 6660,
      logicAddr: address(0xBEEF),
      name: bytes32("DidManager"),
      proxyAddr: address(0),
      tag: bytes32("tag-1"),
      timestamp: 1234
    });
    roundTripConfig.storeDeployment(d);

    Deployment memory got = roundTripConfig.retrieveDeployment(6660, "DidManager");
    assertEq(got.logicAddr, address(0xBEEF));
    assertEq(got.chainId, 6660);

    // Scenario 2: a second store under the same chain+name key replaces rather than appends.
    string memory replacePath = "./.temp/test-deployments-replace.json";
    vm.writeFile(replacePath, "{}");
    vm.setEnv("DEPLOYMENTS_PATH", replacePath);
    Configuration replaceConfig = new Configuration();

    Deployment memory first = Deployment({
      bytecodeHash: keccak256("a"),
      chainId: 6660,
      logicAddr: address(0xAAAA),
      name: bytes32("DidManager"),
      proxyAddr: address(0),
      tag: bytes32("t"),
      timestamp: 1
    });
    Deployment memory second = first;
    second.logicAddr = address(0xBBBB);
    second.timestamp = 2;

    replaceConfig.storeDeployment(first);
    replaceConfig.storeDeployment(second);

    assertEq(replaceConfig.retrieveDeployment(6660, "DidManager").logicAddr, address(0xBBBB));
    // One key, not two entries: a redeploy on a persistent chain must not accumulate.
    string memory raw = vm.readFile(replacePath);
    assertEq(vm.parseJsonKeys(raw, ".6660").length, 1);
  }
}
