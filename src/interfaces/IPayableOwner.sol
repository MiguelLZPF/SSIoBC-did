// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
interface IPayableOwner {
  // EVENTS
  event ThankYou(address indexed from, address indexed to, string message);

  function payMe() external payable;
}
