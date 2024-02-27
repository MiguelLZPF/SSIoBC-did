// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
interface IStorage {
  // EVENTS
  event Stored(uint256 indexed num);

  /**
   * @dev Store value in variable
   * @param num value to store
   */
  function store(uint256 num) external;

  /**
   * @dev Return value
   * @return value of 'number'
   */
  function retrieve() external view returns (uint256);
}
