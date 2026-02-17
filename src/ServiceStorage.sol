// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
  IServiceStorage,
  Service,
  SERVICE_NAMESPACE,
  MAX_SERVICE_TYPE_LENGTH,
  MAX_SERVICE_ENDPOINT_LENGTH
} from "src/interfaces/IServiceStorage.sol";
import { HashUtils } from "src/HashUtils.sol";

// Example of a service:
// {
//   "service": [{
//     "id":"did:example:123#linked-domain",
//     "type": "LinkedDomains",
//     "serviceEndpoint": "https://bar.example.com"
//   }]
// }

/// @title ServiceStorage
/// @author Miguel Gómez Carpena
/// @notice W3C DID service endpoints storage
abstract contract ServiceStorage is IServiceStorage {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  //* Storage
  // Per service DID hash (namespaced), maintain the set of service IDs
  mapping(bytes32 => EnumerableSet.Bytes32Set) private _serviceIds;
  // service DID hash => service ID => Service
  mapping(bytes32 => mapping(bytes32 => Service)) private _serviceByNsAndId;
  // service DID hash => service ID => 1-based position (for event positionHash compatibility)
  mapping(bytes32 => mapping(bytes32 => uint8)) private _servicePositionByNsAndId;

  /**
   * @dev Updates, creates or removes a service in the contract.
   * Uses dynamic bytes for flexible storage following VMStorage v1.0 pattern.
   * @param didHash The hash of the decentralized identifier (DID) associated with the service.
   * @param id The unique identifier of the service.
   * @param type_ Packed service types with '\x00' delimiter.
   * @param serviceEndpoint Packed service endpoints with '\x00' delimiter.
   */
  function _updateService(bytes32 didHash, bytes32 id, bytes memory type_, bytes memory serviceEndpoint) internal {
    bytes32 serviceDidHash = _addServiceNameSpace(didHash);
    // Check parameters
    if (id == bytes32(0)) revert ServiceIdCannotBeZero();

    // Validate size limits
    if (type_.length > MAX_SERVICE_TYPE_LENGTH) revert ServiceTypeTooLarge();
    if (serviceEndpoint.length > MAX_SERVICE_ENDPOINT_LENGTH) revert ServiceEndpointTooLarge();

    bytes32 idHash = HashUtils.calculateIdHash(serviceDidHash, id);
    bool exists = _serviceIds[serviceDidHash].contains(id);
    uint8 position = _servicePositionByNsAndId[serviceDidHash][id];

    // Delete path: both type and endpoint are empty
    if (exists && type_.length == 0 && serviceEndpoint.length == 0) {
      uint256 len = _serviceIds[serviceDidHash].length();
      bytes32 lastId = _serviceIds[serviceDidHash].at(len - 1);
      // Remove id
      _serviceIds[serviceDidHash].remove(id);
      delete _serviceByNsAndId[serviceDidHash][id];
      delete _servicePositionByNsAndId[serviceDidHash][id];
      // Emit deletion event
      emit ServiceUpdated(didHash, id, idHash, 0);
      // Always emit second event to mirror previous behavior (swap-with-last notification)
      // If lastId is different, update its stored position to the freed slot
      if (lastId != id) {
        _servicePositionByNsAndId[serviceDidHash][lastId] = position;
      }
      bytes32 lastIdHash = HashUtils.calculateIdHash(serviceDidHash, lastId);
      bytes32 newPositionHash = HashUtils.calculatePositionHash(serviceDidHash, position);
      emit ServiceUpdated(didHash, lastId, lastIdHash, newPositionHash);
      return;
    }

    // Create/update path
    if (type_.length == 0) revert ServiceTypeCannotBeEmpty();
    if (serviceEndpoint.length == 0) revert ServiceEndpointCannotBeEmpty();

    bytes32 positionHash;
    if (!exists) {
      bool added = _serviceIds[serviceDidHash].add(id);
      assert(added);
      position = uint8(_serviceIds[serviceDidHash].length());
      _servicePositionByNsAndId[serviceDidHash][id] = position;
      positionHash = HashUtils.calculatePositionHash(serviceDidHash, position);
    } else {
      positionHash = HashUtils.calculatePositionHash(serviceDidHash, position);
    }

    // Store the service payload by ID
    Service storage service = _serviceByNsAndId[serviceDidHash][id];
    service.id = id;
    service.type_ = type_;
    service.serviceEndpoint = serviceEndpoint;

    // Emit event
    emit ServiceUpdated(didHash, id, idHash, positionHash);
  }

  /**
   * @dev Removes all services associated with a given DID.
   * @param didHash The hash of the decentralized identifier (DID).
   */
  function _removeAllServices(bytes32 didHash) internal {
    bytes32 serviceDidHash = _addServiceNameSpace(didHash);
    uint256 len = _serviceIds[serviceDidHash].length();
    while (len > 0) {
      bytes32 lastId = _serviceIds[serviceDidHash].at(len - 1);
      delete _serviceByNsAndId[serviceDidHash][lastId];
      delete _servicePositionByNsAndId[serviceDidHash][lastId];
      _serviceIds[serviceDidHash].remove(lastId);
      len--;
    }
  }

  /**
   * @dev Returns the service for a given DID and (service position or service ID).
   * @param didHash The hash of the decentralized identifier (DID).
   * @param id The ID of the service.
   * @param position The position of the service.
   * @return service The service.
   */
  function _getService(bytes32 didHash, bytes32 id, uint8 position) internal view returns (Service memory service) {
    bytes32 ns = _addServiceNameSpace(didHash);
    if (id == bytes32(0)) {
      uint256 len = _serviceIds[ns].length();
      if (position == 0 || uint256(position) > len) {
        return service; // empty
      }
      bytes32 atId = _serviceIds[ns].at(uint256(position) - 1);
      return _serviceByNsAndId[ns][atId];
    }
    return _serviceByNsAndId[ns][id];
  }

  /**
   * @dev Returns the length of the service list for a given DID.
   * @param didHash The hash of the decentralized identifier (DID).
   * @return length The length of the service list.
   */
  function _getServiceListLength(bytes32 didHash) internal view returns (uint8 length) {
    return uint8(_serviceIds[_addServiceNameSpace(didHash)].length());
  }

  function _addServiceNameSpace(bytes32 didHash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(didHash, SERVICE_NAMESPACE));
  }
}
