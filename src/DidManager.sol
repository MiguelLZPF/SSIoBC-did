// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager, UpdateControllerCommand, METHOD0, METHOD1, METHOD2, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "./interfaces/IDidManager.sol";
import { VMStorage, VerificationMethod } from "./VMStorage.sol";

// import {ServiceStorage} from "./ServiceStorage.sol";

contract DidManager is VMStorage, IDidManager {
  // DIDs are stored in a mapping that maps a bytes32 key (representing the hash of the DID) to its expiration date.
  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint) private _expirationDate;
  // DID controllers are stored in a mapping that maps a bytes32 key (representing the hash of the DID or the hash of a specific VM) to an array of 5 bytes32 values (representing the actual controllers).
  // hash(method0:method1:method2:id | didHash&vmId) --> controller[0..4]
  mapping(bytes32 => bytes32[CONTROLLERS_MAX_LENGTH]) private _controllers;

  constructor() {}

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
    // reverse order to check method0 before is changed
    if (method0 == bytes32(0) && method2 == bytes32(0)) {
      method2 = METHOD2;
    }
    if (method0 == bytes32(0) && method1 == bytes32(0)) {
      method1 = METHOD1;
    }
    if (method0 == bytes32(0)) {
      method0 = METHOD0;
    }
    //* Implementation
    bytes32 id = _calculateId(method0, method1, method2, random, msg.sender, block.timestamp);
    bytes32 idHash = _calculateIdHash(method0, method1, method2, id);
    require(_isExpired(idHash), "DID in use");
    (, bytes32 positionHash) = _createVM(
      idHash,
      vmId,
      [bytes32(0), bytes32(0)], // type
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
      bytes1(0x01), // relationships = 0x01 (Authentication)
      1 // Just to avoid one if...
    );
    _validateVM(positionHash, block.timestamp + EXPIRATION, msg.sender);
    _updateExpiration(idHash);
    emit DidCreated(id, idHash, msg.sender);
  }

  function createVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    bytes32[2] calldata type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId,
    address thisBCAddress,
    bytes1 relationships,
    uint expiration
  ) external {
    //* Params validation
    // Required
    require(method0 != bytes32(0), "Method0 cannot be 0");
    require(id != bytes32(0), "VM ID cannot be 0");
    //* Implementation
    bytes32 didHash = keccak256(abi.encodePacked(method0, method1, method2, id));
    require(!_isExpired(didHash), "DID expired");
    _createVM(
      didHash,
      vmId,
      type_,
      publicKey,
      blockchainAccountId,
      thisBCAddress,
      relationships,
      expiration
    );
  }

  function validateVM(bytes32 positionHash, uint expiration) external {
    _validateVM(positionHash, expiration, msg.sender);
  }

  function updateController(UpdateControllerCommand memory command) external {
    //* Params validation
    // Required
    require(
      command.fromMethod0 != bytes32(0) &&
        command.toMethod0 != bytes32(0) &&
        command.controllerMethod0 != bytes32(0),
      "Method0 cannot be 0"
    );
    require(
      command.fromId != bytes32(0) &&
        command.toId != bytes32(0) &&
        command.controllerId != bytes32(0),
      "ID cannot be 0"
    );
    //* Implementation
    // Calculate the hash of the from and to DIDs
    bytes32 fromDidHash = _calculateIdHash(
      command.fromMethod0,
      command.fromMmethod1,
      command.fromMmethod2,
      command.fromId
    );
    bytes32 toDidHash = _calculateIdHash(
      command.toMethod0,
      command.toMethod1,
      command.toMethod2,
      command.toId
    );
    // Check if the DIDs are expired
    require(!_isExpired(fromDidHash), "From DID expired");
    require(!_isExpired(toDidHash), "To DID expired");
    // Check if the sender is a controller of the from DID
    require(_isControllerFor(fromDidHash, command.fromVmId, toDidHash), "Not a controller of To");
    // Check if the sender is authenticated as the from DID
    require(
      _isAuthenticated(fromDidHash, command.fromVmId, msg.sender),
      "Not authenticated as From"
    );
    // Sender can make changes to this DID
    // Calculate the hash of the controller DID
    bytes32 controllerDidOrDidVmIdHash = _calculateIdHash(
      command.controllerMethod0,
      command.controllerMethod1,
      command.controllerMethod2,
      command.controllerId
    );
    // If the controller VM ID is provided, calculate the hash of the controller VM ID
    if (command.controllerVmId != bytes32(0)) {
      controllerDidOrDidVmIdHash = keccak256(
        abi.encodePacked(controllerDidOrDidVmIdHash, command.controllerVmId)
      );
    }
    // If controller position is greater than MAX_LENGTH, always overwrite the last controller
    if (command.controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      command.controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    // Update the controllers mapping
    _controllers[toDidHash][command.controllerPosition] = controllerDidOrDidVmIdHash;
    // Emit the ControllerUpdated event
    emit ControllerUpdated(
      fromDidHash,
      toDidHash,
      controllerDidOrDidVmIdHash,
      command.controllerPosition
    );
  }

  //* View functions

  function getExpiration(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (uint exp) {
    bytes32 didHash = _calculateIdHash(method0, method1, method2, id);
    if (vmId != bytes32(0)) {
      return _getExpirationVM(didHash, vmId);
    } else {
      return _expirationDate[didHash];
    }
  }

  function authenticate(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    address sender
  ) external view returns (bool) {
    return isVmRelationship(method0, method1, method2, id, vmId, 0x01, sender);
  }

  function isVmRelationship(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    bytes1 relationship,
    address sender
  ) public view returns (bool) {
    require(method0 != bytes32(0), "Method0 cannot be 0");
    require(id != bytes32(0), "ID cannot be 0");
    require(sender != address(0), "Sender cannot be 0");
    bytes32 didHash = _calculateIdHash(method0, method1, method2, id);
    return _isVmRelationship(didHash, vmId, relationship, sender);
  }

  function getControllerList(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (bytes32[CONTROLLERS_MAX_LENGTH] memory controllers) {
    return _controllers[_calculateIdHash(method0, method1, method2, id)];
  }

  function getVM(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (VerificationMethod memory vm) {
    return _getVM(_calculateIdHash(method0, method1, method2, id), vmId);
  }

  //* Internal functions

  function _isControllerFor(
    bytes32 fromDid,
    bytes32 fromVmId,
    bytes32 toDid
  ) internal view returns (bool) {
    // Copy the controllers of ID from storage to memory
    bytes32[CONTROLLERS_MAX_LENGTH] memory controllers = _controllers[toDid];
    // Set the from ID with the from VM ID
    bytes32 fromDidWithVm = keccak256(abi.encodePacked(fromDid, fromVmId));
    // Check if the controllers array is empty or matches the ID
    bool controllersIsEmpty = true;
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      // Check if the controller is not empty (used)
      if (controllers[i] != bytes32(0)) {
        controllersIsEmpty = false;
      }
      // Check if the controller matches the sender
      if (controllers[i] == fromDid || controllers[i] == fromDidWithVm) {
        return true;
      }
    }
    // If the controllers array is empty, return true (controllers not used)
    if (controllersIsEmpty) {
      return true;
    }
    // If the controllers array is not empty and the sender is not a controller, return false
    // (controllers used but sender not in controllers)
    return false;
  }

  /**
   * @dev Calculates the ID based on the provided parameters.
   * @param method0 The first method parameter.
   * @param method1 The second method parameter.
   * @param method2 The third method parameter.
   * @param random The random parameter.
   * @param sender The address of the sender.
   * @param timestamp The timestamp parameter.
   * @return id The calculated ID.
   */
  function _calculateId(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 random,
    address sender,
    uint timestamp
  ) internal pure returns (bytes32 id) {
    return keccak256(abi.encodePacked(method0, method1, method2, random, sender, timestamp));
  }

  /**
   * @dev Calculates the hash of an ID using the specified methods.
   * @param method0 The first method to include in the hash.
   * @param method1 The second method to include in the hash.
   * @param method2 The third method to include in the hash.
   * @param id The ID to include in the hash.
   * @return idHash The hash of the ID.
   */
  function _calculateIdHash(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) internal pure returns (bytes32 idHash) {
    return keccak256(abi.encodePacked(method0, method1, method2, id));
  }

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
