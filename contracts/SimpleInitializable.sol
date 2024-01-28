// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title SimpleInitializable
 * @dev Abstract contract for initializing contract state.
 */
abstract contract SimpleInitializable {
  bool private _initialized;

  function isInitialized() external view returns (bool) {
    return _initialized;
  }

  /**
   * @dev Modifier to ensure that a contract is only initialized once.
   * Throws an error if the contract has already been initialized.
   */
  modifier initializer() {
    require(!_initialized, "Initializable: contract is already initialized");
    _;
    _initialized = true;
  }

  /**
   * @dev Modifier to check if the contract is initialized.
   * Throws an error if the contract is not initialized.
   */
  modifier onlyInitialized() {
    require(_initialized, "Initializable: contract is not initialized");
    _;
  }
}
