// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { IDidWriteOps } from "@interfaces/IDidWriteOps.sol";

/**
 * @title MockContractKeys
 * @notice Contracts that hold a verification method bound to their own address, and the
 * intermediaries around them. Used by the contract-VM unit tests (v1.8.0).
 */

/// @dev Forwards a call and bubbles the callee's revert data unchanged.
abstract contract Bubble {
  function _forward(address to, bytes memory data) internal returns (bytes memory ret) {
    bool ok;
    (ok, ret) = to.call(data);
    if (!ok) {
      assembly {
        revert(add(ret, 32), mload(ret))
      }
    }
  }
}

/// @dev A contract key restricted to its admin (an EOA or a contract). Expiration is fixed in code.
contract ReferenceIssuer is Bubble {
  error NotAdmin();

  address internal immutable MANAGER;
  address internal immutable ADMIN;

  constructor(address manager, address admin) {
    MANAGER = manager;
    ADMIN = admin;
  }

  function validate(bytes32 positionHash) external {
    if (msg.sender != ADMIN) revert NotAdmin();
    IDidWriteOps(MANAGER).validateVm(positionHash, 0);
  }

  function exec(address to, bytes calldata data) external returns (bytes memory) {
    if (msg.sender != ADMIN) revert NotAdmin();
    return _forward(to, data);
  }
}

/// @dev Executes arbitrary calls for arbitrary callers (a multicall, a flash-loan callback).
contract OpenCaller is Bubble {
  function exec(address to, bytes calldata data) external returns (bytes memory) {
    return _forward(to, data);
  }
}

/// @dev A multisig stand-in: anyone may drive it in tests. Used as a contract admin.
contract MockMultisig is Bubble {
  function exec(address to, bytes calldata data) external {
    _forward(to, data);
  }
}

/// @dev Validates its own VM inside its constructor, then optionally destroys itself.
contract ConstructorValidator {
  constructor(address manager, bytes32 positionHash, bool destroy) {
    IDidWriteOps(manager).validateVm(positionHash, 0);
    if (destroy) {
      selfdestruct(payable(msg.sender));
    }
  }
}

/// @dev The EIP-7702 delegate: no access control, so a relayer can drive the delegating account.
contract RelayedDelegate is Bubble {
  function execute(address to, bytes calldata data) external {
    _forward(to, data);
  }
}

/// @dev Same init code for every deployment, so the CREATE2 address depends on the salt only.
/// The constructor asks the factory what to do: validate the VM and self-destruct, or return the
/// runtime code the factory holds.
contract MetamorphicInit {
  constructor() {
    (address manager, bytes32 positionHash, bytes memory runtime) = MetamorphicFactory(msg.sender).pending();
    if (runtime.length == 0) {
      IDidWriteOps(manager).validateVm(positionHash, 0);
      selfdestruct(payable(msg.sender));
    }
    assembly {
      return(add(runtime, 32), mload(runtime))
    }
  }
}

contract MetamorphicFactory {
  address internal pendingManager;
  bytes32 internal pendingPositionHash;
  bytes internal pendingRuntime;

  function pending() external view returns (address, bytes32, bytes memory) {
    return (pendingManager, pendingPositionHash, pendingRuntime);
  }

  function deployValidator(bytes32 salt, address manager, bytes32 positionHash) external returns (address) {
    pendingManager = manager;
    pendingPositionHash = positionHash;
    delete pendingRuntime;
    return address(new MetamorphicInit{ salt: salt }());
  }

  function deployRuntime(bytes32 salt, bytes calldata runtime) external returns (address) {
    pendingRuntime = runtime;
    return address(new MetamorphicInit{ salt: salt }());
  }

  function predict(bytes32 salt) external view returns (address) {
    return address(
      uint160(
        uint256(
          keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(type(MetamorphicInit).creationCode)))
        )
      )
    );
  }
}
