// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { HashBasedList } from "@lib/hash-based-list/src/HashBasedList.sol";

// Example of a service:
// {
//   "service": [{
//     "id":"did:example:123#linked-domain",
//     "type": "LinkedDomains",
//     "serviceEndpoint": "https://bar.example.com"
//   }]
// }

uint8 constant SERVICE_MAX_LENGTH = 20;
bytes32 constant SERVICE_NAMESPACE = bytes32("service");

struct Service {
  bytes32 id;
  bytes32[SERVICE_MAX_LENGTH] type_;
  bytes32[SERVICE_MAX_LENGTH] serviceEndpoint;
}

abstract contract ServiceStorage is HashBasedList {
  //* Events
  /**
   * @dev Emitted when a new service is created for a DID.
   * @param didIdHash The unique identifier of the DID.
   * @param id The unique identifier of the service.
   * @param serviceIdHash The unique identifier hash of the service.
   * @param positionHash The hash of the position of the service.
   */
  event ServiceUpdated(
    bytes32 indexed didIdHash,
    bytes32 indexed id,
    bytes32 indexed serviceIdHash,
    bytes32 positionHash
  );

  //* Storage
  // hash(DIDHash, position) --> Service Details
  // positionHash --> Service Details
  mapping(bytes32 => Service) private _service;

  /**
   * @dev Updates, creates or removes a service in the contract.
   * @param didHash The hash of the decentralized identifier (DID) associated with the service.
   * @param id The unique identifier of the service.
   * @param type_ An array of service types.
   * @param serviceEndpoint An array of service endpoints.
   */
  function _updateService(
    bytes32 didHash,
    bytes32 id,
    bytes32[SERVICE_MAX_LENGTH] memory type_,
    bytes32[SERVICE_MAX_LENGTH] memory serviceEndpoint
  ) internal {
    bytes32 serviceDidHash = _addServiceNameSpace(didHash);
    // Check parameters
    // require(didHash != bytes32(0), REVERT_EMPTY_DID_HASH); //! Unreachable code
    require(id != bytes32(0), "ID cannot be 0");
    // Get service
    (bytes32 idHash, bytes32 positionHash, uint8 position) = _calculateHashes(serviceDidHash, id);
    //  Service exists and type_ and serviceEndpoint are empty ==> delete service
    if (position > 0 && type_[0] == bytes32(0) && serviceEndpoint[0] == bytes32(0)) {
      // Get latest service on array
      // uint8 lastPosition = _getHblLength(serviceDidHash);
      bytes32 lastPositionHash = _calculatePositionHash(
        serviceDidHash,
        _getHblLength(serviceDidHash)
      );
      bytes32 lastServiceId = _service[lastPositionHash].id;
      bytes32 lastIdHash = _calculateIdHash(serviceDidHash, lastServiceId);
      // Replace the service with the last service
      _service[positionHash] = _service[lastPositionHash];
      // Delete the service new last service
      delete _service[lastPositionHash];
      // Remove position of the deleted service
      _removeHbl(serviceDidHash, id, lastServiceId);
      // Emit two events
      emit ServiceUpdated(didHash, id, idHash, 0);
      emit ServiceUpdated(didHash, lastServiceId, lastIdHash, positionHash);
      return;
    }
    // Check both are defined before updating (or create)
    require(type_[0] != bytes32(0), "Type cannot be 0");
    require(serviceEndpoint[0] != bytes32(0), "Endpoint cannot be 0");
    if (position == 0) {
      // Does not exist --> update service list length and position by ID
      (idHash, position) = _addHbl(serviceDidHash, id);
      positionHash = _calculatePositionHash(serviceDidHash, position);
    }
    // Store the service
    Service storage service = _service[positionHash];
    service.id = id;
    service.type_ = type_;
    service.serviceEndpoint = serviceEndpoint;

    // Emit an event
    emit ServiceUpdated(didHash, id, idHash, positionHash);
  }

  function _removeAllServices(bytes32 didHash) internal {
    bytes32 serviceDidHash = _addServiceNameSpace(didHash);
    for (uint8 i = 1; i <= _getHblLength(serviceDidHash); i++) {
      bytes32 positionHash = _calculatePositionHash(serviceDidHash, i);
      // Set serviceId --> position to 0
      _initHblPosition(serviceDidHash, _service[positionHash].id);
      // Delete service
      delete _service[positionHash];
    }
    // Set length to 0
    _initHblLength(serviceDidHash);
  }

  /**
   * @dev Returns the service for a given DID and (service position or service ID).
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The ID of the service.
   * @param position The position of the service.
   * @return service The service.
   */
  function _getService(
    bytes32 didHash,
    bytes32 id,
    uint8 position
  ) internal view returns (Service memory service) {
    didHash = _addServiceNameSpace(didHash);
    if (id == bytes32(0)) {
      return _service[keccak256(abi.encodePacked(didHash, position))];
    }
    (, bytes32 positionHash, ) = _calculateHashes(didHash, id);
    return _service[positionHash];
  }

  /**
   * @dev Returns the length of the service list for a given DID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return length The length of the service list.
   */
  function _getServiceListLength(bytes32 didHash) internal view returns (uint8 length) {
    return _getHblLength(_addServiceNameSpace(didHash));
  }

  function _addServiceNameSpace(bytes32 didHash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(didHash, SERVICE_NAMESPACE));
  }
}
