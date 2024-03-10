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
  event ServiceCreated(
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
   * @dev Creates a new service and stores it in the contract.
   * @param didHash The hash of the decentralized identifier (DID) associated with the service.
   * @param id The unique identifier of the service.
   * @param type_ An array of service types.
   * @param serviceEndpoint An array of service endpoints.
   */
  function _createService(
    bytes32 didHash,
    bytes32 id,
    bytes32[SERVICE_MAX_LENGTH] memory type_,
    bytes32[SERVICE_MAX_LENGTH] memory serviceEndpoint
  ) internal {
    // Check parameters
    require(didHash != bytes32(0), "1st param required"); // "DID hash cannot be 0"
    require(id != bytes32(0), "2nd param required"); // "ID cannot be 0"
    require(type_[0] != bytes32(0), "3rd param required"); // "Type cannot be 0"
    require(serviceEndpoint[0] != bytes32(0), "4th param required"); // "Service endpoint cannot be 0"
    // Get service
    (bytes32 idHash, bytes32 positionHash) = _calculateServiceHashes(didHash, id);
    Service storage service = _service[positionHash];
    require(service.id == bytes32(0), "Service already exists");
    // Store the service
    service.id = id;
    service.type_ = type_;
    service.serviceEndpoint = serviceEndpoint;
    // Mappings
    _servicePositionById[idHash] = _serviceLength[didHash];
    _serviceLength[didHash]++;
    // Emit an event
    emit ServiceCreated(didHash, id, idHash, positionHash);
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
  ) internal view returns (bytes32 idHash, bytes32 positionHash) {
    idHash = keccak256(abi.encodePacked(didHash, id));
    uint8 position = _servicePositionById[idHash];
    positionHash = keccak256(abi.encodePacked(didHash, position));
    return (idHash, positionHash);
  }
}
