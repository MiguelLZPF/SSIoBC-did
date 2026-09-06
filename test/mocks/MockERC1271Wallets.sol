// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

bytes4 constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

/// @title MockERC1271Wallet
/// @notice Minimal ERC-1271 smart wallet: accepts signatures produced by `owner`.
/// @dev `owner` is immutable so it survives `vm.etch` (immutables live in runtime code,
///      not storage) — this is what lets tests simulate an EIP-7702 delegated EOA.
contract MockERC1271Wallet {
  address public immutable owner;

  constructor(address owner_) {
    owner = owner_;
  }

  function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
    (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
    if (err == ECDSA.RecoverError.NoError && recovered == owner) {
      return ERC1271_MAGIC_VALUE;
    }
    return 0xffffffff;
  }
}

/// @notice ERC-1271 wallet that rejects every signature.
contract MockERC1271AlwaysReject {
  function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
    return 0xffffffff;
  }
}

/// @notice ERC-1271 wallet whose `isValidSignature` reverts.
contract MockERC1271Reverting {
  error AlwaysReverts();

  function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
    revert AlwaysReverts();
  }
}

/// @notice Contract with no `isValidSignature` at all (fallback returns empty data).
contract MockNotAWallet {
  uint256 public value;

  function setValue(uint256 v) external {
    value = v;
  }
}
