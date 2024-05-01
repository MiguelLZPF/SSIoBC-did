// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { IDidManager, Controller, CreateVmCommand as DidCreateVmCommand, METHOD0, METHOD1, METHOD2, EXPIRATION, CONTROLLERS_MAX_LENGTH } from "src/interfaces/IDidManager.sol";
import { VMStorage, VerificationMethod, CreateVmCommand } from "src/VMStorage.sol";
import { ServiceStorage, Service, SERVICE_MAX_LENGTH } from "src/ServiceStorage.sol";

// import {ServiceStorage} from "./ServiceStorage.sol";

contract DidManager is IDidManager, VMStorage, ServiceStorage {
  // DIDs are stored in a mapping that maps a bytes32 key (representing the hash of the DID) to its expiration date.
  // hash(method0:method1:method2:id) --> expirationDate
  mapping(bytes32 => uint) private _expirationDate;
  // DID controllers are stored in a mapping that maps a bytes32 key (representing the hash of the DID or the hash of a specific VM) to an array of 5 bytes32 values (representing the actual controllers).
  // hash(method0:method1:method2:id) --> controller[0..4]
  mapping(bytes32 => Controller[CONTROLLERS_MAX_LENGTH]) private _controllers;

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
    bytes32 id = keccak256(
      abi.encodePacked(method0, method1, method2, random, msg.sender, block.timestamp)
    );
    bytes32 idHash = _calculateIdHash(method0, method1, method2, id);
    require(_isExpired(idHash), "DID in use");
    (, bytes32 positionHash) = _createVm(
      CreateVmCommand({
        didHash: idHash,
        id: vmId,
        type_: [bytes32(0), bytes32(0)],
        publicKey: [
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
        ],
        blockchainAccountId: [
          bytes32("eip155"),
          bytes32("666"),
          bytes32(uint256(uint160(msg.sender))),
          bytes32(0),
          bytes32(0)
        ],
        thisBcAddress: msg.sender,
        relationships: bytes1(0x01), // 0x01 (Authentication)
        expiration: 1 // Just to avoid one if statement
      })
    );
    _validateVm(positionHash, 0, msg.sender);
    _updateExpiration(idHash);
    emit DidCreated(id, idHash, msg.sender);
  }

  function createVm(DidCreateVmCommand memory command) external {
    //* Params validation
    // Required
    require(command.method0 != bytes32(0), "Method0 cant be 0");
    require(command.senderId != bytes32(0) && command.targetId != bytes32(0), "DIDs cant be 0");
    require(command.relationships > bytes1(0), "Relationships cant be 0");
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget({
      method0: command.method0,
      method1: command.method1,
      method2: command.method2,
      senderId: command.senderId,
      senderVmId: command.senderVmId,
      targetId: command.targetId
    });
    _createVm(
      CreateVmCommand({
        didHash: targetIdHash,
        id: command.vmId,
        type_: command.type_,
        publicKey: command.publicKey,
        blockchainAccountId: command.blockchainAccountId,
        thisBcAddress: command.thisBcAddress,
        relationships: command.relationships,
        expiration: command.expiration
      })
    );
    _updateExpiration(targetIdHash);
  }

  function validateVm(bytes32 positionHash, uint expiration) external {
    _validateVm(positionHash, expiration, msg.sender);
  }

  function expireVm(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 vmId
  ) external {
    //* Params validation
    // Required
    require(method0 != bytes32(0), "Method0 cant be 0");
    require(senderId != bytes32(0) && targetId != bytes32(0), "DIDs cant be 0");
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(
      method0,
      method1,
      method2,
      senderId,
      senderVmId,
      targetId
    );
    _expireVm(targetIdHash, vmId);
    _updateExpiration(targetIdHash);
  }

  function updateController(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 controllerId,
    bytes32 controllerVmId,
    uint8 controllerPosition
  ) external {
    //* Params validation
    // Required
    require(method0 != bytes32(0), "Method0 cant be 0");
    require(
      senderId != bytes32(0) && targetId != bytes32(0) && controllerId != bytes32(0),
      "DIDs cant be 0"
    );
    //* Implementation
    (bytes32 senderIdHash, bytes32 targetIdHash) = _validateSenderAndTarget(
      method0,
      method1,
      method2,
      senderId,
      senderVmId,
      targetId
    );
    // Sender can make changes to this DID
    // If controller position is greater than MAX_LENGTH, always overwrite the last controller
    if (controllerPosition > CONTROLLERS_MAX_LENGTH - 1) {
      controllerPosition = CONTROLLERS_MAX_LENGTH - 1;
    }
    // Update the controllers mapping
    _controllers[targetIdHash][controllerPosition] = Controller(controllerId, controllerVmId);
    // Emit the ControllerUpdated event
    emit ControllerUpdated(senderIdHash, targetIdHash, controllerPosition, controllerVmId);
    _updateExpiration(targetIdHash);
  }

  function updateService(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId,
    bytes32 serviceId,
    bytes32[SERVICE_MAX_LENGTH] memory type_,
    bytes32[SERVICE_MAX_LENGTH] memory serviceEndpoint
  ) external {
    //* Implementation
    (, bytes32 targetIdHash) = _validateSenderAndTarget(
      method0,
      method1,
      method2,
      senderId,
      senderVmId,
      targetId
    );
    _updateService(targetIdHash, serviceId, type_, serviceEndpoint);
    _updateExpiration(targetIdHash);
  }

  //* View functions

  function getExpiration(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId
  ) external view returns (uint exp) {
    bytes32 idHash = _calculateIdHash(method0, method1, method2, id);
    if (vmId != bytes32(0)) {
      return _getExpirationVm(idHash, vmId);
    } else {
      return _expirationDate[idHash];
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
    require(method0 != bytes32(0), "Method0 cant be 0");
    require(id != bytes32(0), "ID cant be 0");
    require(sender != address(0), "Sender cant be 0");
    bytes32 idHash = _calculateIdHash(method0, method1, method2, id);
    return _isVmRelationship(idHash, vmId, relationship, sender);
  }

  function getControllerList(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllers) {
    return _controllers[_calculateIdHash(method0, method1, method2, id)];
  }

  function getVm(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 vmId,
    uint8 position
  ) external view returns (VerificationMethod memory vm) {
    return _getVm(_calculateIdHash(method0, method1, method2, id), vmId, position);
  }

  function getVmListLength(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (uint8) {
    return _getVmListLength(_calculateIdHash(method0, method1, method2, id));
  }

  function getService(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id,
    bytes32 serviceId,
    uint8 position
  ) external view returns (Service memory service) {
    return _getService(_calculateIdHash(method0, method1, method2, id), serviceId, position);
  }

  function getServiceListLength(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 id
  ) external view returns (uint8 length) {
    return _getServiceListLength(_calculateIdHash(method0, method1, method2, id));
  }

  //* Internal functions

  function _validateSenderAndTarget(
    bytes32 method0,
    bytes32 method1,
    bytes32 method2,
    bytes32 senderId,
    bytes32 senderVmId,
    bytes32 targetId
  ) internal view returns (bytes32 senderIdHash, bytes32 targetIdHash) {
    // Calculate the hash of the sender and target DIDs
    senderIdHash = _calculateIdHash(method0, method1, method2, senderId);
    targetIdHash = _calculateIdHash(method0, method1, method2, targetId);
    // Check if the DIDs are expired
    require(!_isExpired(senderIdHash), "Sender DID expired");
    require(!_isExpired(targetIdHash), "Target DID expired");
    // Check if the sender is authenticated as the sender DID
    require(_isAuthenticated(senderIdHash, senderVmId, msg.sender), "Not authenticated as sender");
    // Check if the sender is a controller for the target DID
    require(
      _isControllerFor(senderId, senderVmId, senderIdHash, targetIdHash),
      "Not a controller for target"
    );
  }

  function _isControllerFor(
    bytes32 senderDid,
    bytes32 senderVmId,
    bytes32 senderIdHash,
    bytes32 targetIdHash
  ) internal view returns (bool) {
    // Copy the controllers of the target ID from storage to memory
    Controller[CONTROLLERS_MAX_LENGTH] memory controllers = _controllers[targetIdHash];
    // Check if the controllers array is empty or matches the ID
    bool controllersIsEmpty = true;
    for (uint8 i = 0; i < CONTROLLERS_MAX_LENGTH; i++) {
      // Check if the controller is not empty (used)
      if (controllers[i].id != bytes32(0)) {
        controllersIsEmpty = false;
        // Execute only if not empty
        // Check if the controller is the same as the sender ID
        if (controllers[i].vmId != bytes32(0)) {
          if (controllers[i].vmId == senderVmId && controllers[i].id == senderDid) {
            // match
            return true;
          }
        } else if (controllers[i].id == senderDid) {
          // match
          return true;
        }
      }
      // check next controller
    }
    // If the controllers array is empty and the sender ID matches the target ID, return true (controllers not used)
    if (controllersIsEmpty && senderIdHash == targetIdHash) {
      return true;
    }
    // If the controllers array is not empty and the sender is not a controller, return false
    // (controllers used but sender not in controllers)
    return false;
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
