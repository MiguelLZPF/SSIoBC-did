// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { Controller, CONTROLLERS_MAX_LENGTH } from "@types/DidTypes.sol";
import { Service } from "@types/ServiceTypes.sol";

/// @title IDidReadOps
/// @author Miguel Gomez Carpena
/// @notice Read-only DID operations (ISP: Interface Segregation Principle)
interface IDidReadOps {
  /// @dev Returns the expiration timestamp for a given DID or VM ID.
  function getExpiration(bytes32 methods, bytes32 id, bytes32 vmId) external view returns (uint256 exp);

  /// @dev Returns the list of controllers for a given DID.
  function getControllerList(bytes32 methods, bytes32 id)
    external
    view
    returns (Controller[CONTROLLERS_MAX_LENGTH] memory controllerList);

  /// @dev Returns the service for a given ID and (service position or service ID).
  function getService(bytes32 methods, bytes32 id, bytes32 serviceId, uint8 position)
    external
    view
    returns (Service memory service);

  /// @dev Returns the length of the service list for a given ID.
  function getServiceListLength(bytes32 methods, bytes32 id) external view returns (uint8 length);
}
