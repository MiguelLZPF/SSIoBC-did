// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

// Example of a service:
// {
//   "service": [{
//     "id":"did:example:123#linked-domain",
//     "type": "LinkedDomains",
//     "serviceEndpoint": "https://bar.example.com"
//   }]
// }

uint8 constant SERVICE_MAX_LENGTH = 20;

struct Service {
  bytes32 id;
  bytes32[SERVICE_MAX_LENGTH] type_;
  bytes32[SERVICE_MAX_LENGTH] serviceEndpoint;
}

abstract contract ServiceStorage {
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
  mapping(bytes32 => Service) private _service;
  // hash(DIDHash, Service ID) --> position
  mapping(bytes32 => uint8) private _servicePositionById;
  // DIDHash --> Service length
  mapping(bytes32 => uint8) private _serviceLength;

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
    // Check parameters
    require(didHash != bytes32(0), "1st param required"); // "DID hash cannot be 0"
    require(id != bytes32(0), "2nd param required"); // "ID cannot be 0"
    // Get service
    (bytes32 idHash, bytes32 positionHash, uint8 position) = _calculateServiceHashes(didHash, id);
    Service storage service = _service[positionHash];
    //  Service.id exists and type_ and serviceEndpoint are empty ==> delete service
    if (service.id != bytes32(0) && type_[0] == bytes32(0) && serviceEndpoint[0] == bytes32(0)) {
      // Get latest service on array
      uint8 lastPosition = _serviceLength[didHash] - 1;
      bytes32 lastPositionHash = keccak256(abi.encodePacked(didHash, lastPosition));
      Service memory lastService = _service[lastPositionHash];
      bytes32 lastIdHash = keccak256(abi.encodePacked(didHash, lastService.id));
      // Replace the service with the last service
      _service[positionHash] = lastService;
      // Update position of the previous last service
      _servicePositionById[lastIdHash] = position;
      // Delete the service new last service
      delete _service[lastPositionHash];
      // Remove position of the deleted service
      _servicePositionById[idHash] = 0;
      // Decrease the length
      _serviceLength[didHash]--;
      // Emit two events
      emit ServiceUpdated(didHash, id, idHash, 0);
      emit ServiceUpdated(didHash, lastService.id, lastIdHash, positionHash);
      return;
    }
    // Check both are defined before updating (or create)
    require(type_[0] != bytes32(0), "3rd param required"); // "Type cannot be 0"
    require(serviceEndpoint[0] != bytes32(0), "4th param required"); // "Service endpoint cannot be 0"
    // Store the service
    service.id = id;
    service.type_ = type_;
    service.serviceEndpoint = serviceEndpoint;
    // Mappings
    _servicePositionById[idHash] = _serviceLength[didHash];
    _serviceLength[didHash]++;
    // Emit an event
    emit ServiceUpdated(didHash, id, idHash, positionHash);
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
    if (id == bytes32(0)) {
      return _service[keccak256(abi.encodePacked(didHash, position))];
    }
    (, bytes32 positionHash, ) = _calculateServiceHashes(didHash, id);
    return _service[positionHash];
  }

  /**
   * @dev Returns the length of the service list for a given DID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return length The length of the service list.
   */
  function _getServiceListLength(bytes32 didHash) internal view returns (uint8 length) {
    return _serviceLength[didHash];
  }

  /**
   * @dev Calculates the hashes for a service based on the provided DID hash and service ID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The ID of the service.
   * @return idHash The hash of the service ID combined with the DID hash.
   * @return positionHash The hash of the service position combined with the DID hash.
   */
  function _calculateServiceHashes(
    bytes32 didHash,
    bytes32 id
  ) internal view returns (bytes32 idHash, bytes32 positionHash, uint8 position) {
    idHash = keccak256(abi.encodePacked(didHash, id));
    position = _servicePositionById[idHash];
    positionHash = keccak256(abi.encodePacked(didHash, position));
    return (idHash, positionHash, position);
  }
}
