// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidReadOps } from "@interfaces/IDidReadOps.sol";
import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";
import { IDidAuth } from "@interfaces/IDidAuth.sol";

/// @title IDidManager
/// @author Miguel Gomez Carpena
/// @notice Liskov-safe composite interface usable with ANY DID manager variant.
/// Combines shared read, write, and auth operations that both Full and Native variants implement.
interface IDidManager is IDidReadOps, IDidWriteOps, IDidAuth { }
