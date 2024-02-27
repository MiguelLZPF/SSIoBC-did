// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Deployment, DeploymentStoreInfo} from "@script/Configuration.s.sol";
import {Storage, IStorage, IPayableOwner} from "@src/Storage.sol";
import {StorageScript, DeployCommand} from "@script/Storage.s.sol";

contract StorageTest is Test {
  // Constants
  uint256 private constant INIT_AMOUNT = 12 ether;
  address private constant DEFAULT_USER = address(10);
  uint256 private constant DEFAULT_USER_BALANCE = 100 ether;
  // Variables
  Storage public myStorage;
  address admin = DEFAULT_SENDER;
  address payable user = payable(DEFAULT_USER);

  function setUp() public {
    Deployment memory deployment;
    // Transfer some ether to user
    vm.deal(user, DEFAULT_USER_BALANCE);
    // Deploy the contract
    (myStorage, deployment) = new StorageScript().deploy(
      DeployCommand({
        initValue: INIT_AMOUNT,
        storeInfo: DeploymentStoreInfo({store: false, tag: bytes32(0)})
      })
    );
    // Check the initial state
    assertEq(myStorage.retrieve(), INIT_AMOUNT);
    assertEq(myStorage.hasRole(bytes32(0), address(admin)), true);
    assertEq(myStorage.hasRole(bytes32(0), address(user)), false);
  }

  function test_Store() public {
    vm.startPrank(user);
    uint256 newAmount = 3;
    uint previousAmount = myStorage.retrieve();
    assertEq(previousAmount, INIT_AMOUNT);
    // Event check
    vm.expectEmit(address(myStorage));
    emit IStorage.Stored(newAmount);
    // Change the value
    myStorage.store(newAmount);
    uint currentAmount = myStorage.retrieve();
    assertEq(currentAmount, newAmount);
    vm.stopPrank();
  }

  function test_PayMe() public {
    vm.startPrank(user);
    uint256 amount = 15 ether;
    // Initial state check
    uint256 initBalanceUser = address(user).balance;
    uint256 initBalanceAdmin = address(admin).balance;
    assertGt(initBalanceUser, 1);
    assertGt(initBalanceAdmin, 1);
    // Event check
    vm.expectEmit(address(myStorage));
    emit IPayableOwner.ThankYou(address(admin), address(user), "Thanks!!");
    // Pay the admin
    myStorage.payMe{value: amount}();
    // Final state check
    uint256 finalBalanceUser = address(user).balance;
    uint256 finalBalanceAdmin = address(admin).balance;
    assertEq(finalBalanceUser, initBalanceUser - amount);
    assertEq(finalBalanceAdmin, initBalanceAdmin + amount);
    vm.stopPrank();
  }

  function test_PayMe_ShouldNot_WhenBalance0() public {
    address noBalanceAddress = payable(address(0));
    vm.startPrank(noBalanceAddress);
    uint256 amount = 1 ether;
    // Initial state check
    uint256 initBalanceUser = address(noBalanceAddress).balance;
    uint256 initBalanceAdmin = address(admin).balance;
    assertEq(initBalanceUser, 0);
    assertGt(initBalanceAdmin, 1);
    // Event check
    vm.expectRevert();
    // Pay the admin
    myStorage.payMe{value: amount}();
    // Final state check
    uint256 finalBalanceUser = address(noBalanceAddress).balance;
    uint256 finalBalanceAdmin = address(admin).balance;
    assertEq(finalBalanceUser, initBalanceUser);
    assertEq(finalBalanceAdmin, initBalanceAdmin);
    vm.stopPrank();
  }
}
