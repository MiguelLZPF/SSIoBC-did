// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IDidManager} from "./interfaces/IDidManager.sol";
import {IVMStorage} from "./interfaces/IVMStorage.sol";
import {IServiceStorage} from "./interfaces/IServiceStorage.sol";

contract DidManager is IDidManager {
  bytes32 private constant METHOD0 =
    bytes32(0x6c7a706600000000000000000000000000000000000000000000000000000000); // "lzpf"
  bytes32 private constant METHOD1 =
    bytes32(0x6d61696e00000000000000000000000000000000000000000000000000000000); // "main"
  bytes32 private constant METHOD2 = bytes32(0); // not used by default
  uint private constant EXPIRATION = 126144000; // 4 years in seconds (4 * 365 * 24 * 60 * 60)
  // System contracts
  IVMStorage private _vmStorage;
  IServiceStorage private _serviceStorage;
  ////      method0    -->     method1    -->     method2 -->   id
  //// mapping(bytes32 => mapping(bytes32 => mapping(bytes32 => bytes32))) private dids;
  // DIDs are stored in a mapping that maps a bytes32 key (representing the hash of the DID) to its expiration date.
  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint) private _expirationDate;
  // DID controllers are stored in a mapping that maps a bytes32 key (representing the hash of the DID or the hash of a specific VM) to an array of 5 bytes32 values (representing the actual controllers).
  // hash(method0:method1:method2:id | didHash&vmId) --> controller[0..4]
  mapping(bytes32 => bytes32[5]) private _controllers;

  constructor(IVMStorage vmStorage, IServiceStorage serviceStorage) {
    _vmStorage = vmStorage;
    _serviceStorage = serviceStorage;
  }

  /**
   * @dev Creates a new Decentralized Identifier (DID) using the specified method identifiers and a random value.
   * The method identifiers can be optionally provided, and if any of them is not provided (i.e., set to 0),
   * the default method identifier will be used instead.
   *
   * @param method0 The first method identifier.
   * @param method1 The second method identifier.
   * @param method2 The third method identifier.
   * @param random A random value used to generate the DID. You can use uuidv4() to generate a random value, for example.
   *
   * Requirements:
   * - The random value must not be zero.
   * - The generated DID must not already exist.
   *
   * Emits a `DidCreated` event with the generated DID and the address of the caller.
   */
  function createDid(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random,
    bytes32 vmId
  ) external {
    //* Params validation
    // Required
    require(random != bytes32(0), "Random cannot be 0");
    // Optional
    if (method0 == bytes32(0)) {
      method0 = METHOD0;
    }
    if (method1 == bytes32(0)) {
      method1 = METHOD1;
    }
    if (method2 == bytes32(0)) {
      method2 = METHOD2;
    }
    //* Implementation
    bytes32 id = keccak256(
      abi.encodePacked(
        method0,
        method1,
        method2,
        random,
        msg.sender,
        block.timestamp,
        block.coinbase, // address of the miner
        blockhash(block.number)
      )
    );
    bytes32 idHash = keccak256(abi.encodePacked(method0, method1, method2, id));
    require(_isExpired(idHash), "DID in use");
    (, bytes32 positionHash) = _vmStorage.createVM(
      idHash,
      vmId,
      bytes32(0), // type
      [
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0),
        bytes32(0)
      ], // publicKey
      [
        bytes32(abi.encodePacked("eip155")),
        bytes32(abi.encodePacked("666")),
        bytes32(bytes32(uint256(uint160(msg.sender)))),
        bytes32(0),
        bytes32(0)
      ],
      msg.sender,
      1 // Just to avoid one if...
    );
    _vmStorage.validateVM(positionHash, block.timestamp + EXPIRATION);
    _updateExpiration(idHash);
    emit DidCreated(id, msg.sender);
  }

  function createVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId,
    address thisBCAddress,
    uint expiration
  ) external {
    //* Params validation
    // Required
    require(method0 != bytes32(0), "Method0 cannot be 0");
    require(id != bytes32(0), "VM ID cannot be 0");
    //* Implementation
    bytes32 didHash = keccak256(abi.encodePacked(method0, method1, method2, id));
    require(!_isExpired(didHash), "DID expired");
    (bytes32 vmIdHash, bytes32 positionHash) = _vmStorage.createVM(
      didHash,
      vmId,
      type_,
      publicKey,
      blockchainAccountId,
      thisBCAddress,
      expiration
    );
    emit VMCreated(didHash, vmId, vmIdHash, positionHash);
  }

  function validateVM(bytes32 positionHash, uint expiration) external {
    bytes32 vmId = _vmStorage.validateVM(positionHash, expiration);
    emit VMValidated(vmId);
  }

  function addController(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external {}

  /**
   * @dev Updates the expiration date for a given ID hash.
   * @param idHash The hash of the ID to update the expiration date for.
   */
  function _updateExpiration(bytes32 idHash) internal {
    _expirationDate[idHash] = block.timestamp + EXPIRATION;
  }

  /**
   * @dev Checks if a given ID hash is expired.
   * @param idHash The hash of the ID to check.
   * @return expired True if the ID is expired, false otherwise.
   */
  function _isExpired(bytes32 idHash) internal view returns (bool expired) {
    // Check if now is greater than expiration date or 0
    if (block.timestamp > _expirationDate[idHash] || _expirationDate[idHash] == 0) {
      return true;
    } else {
      return false;
    }
  }
}
