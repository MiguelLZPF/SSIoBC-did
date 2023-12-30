// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

struct VerificationMethod {
  bytes32 id;
  bytes32 type_;
  bytes32[16] publicKey;
  bytes32[5] blockchainAccountId; // firstPart:secondPart:thirdPart = 32:32:32x3 // External blockchain account ID
  address thisBCAddress; // An address (account ID) of the blockchain where the VM is stored
  bool authentication;
  bool assertionMethod;
  bool keyAgreement;
  bool capabilityInvocation;
  bool capabilityDelegation;
  uint expiration;
}

interface IVMStorage {
  function createVM(
    bytes32 didHash,
    bytes32 id,
    bytes32 type_,
    bytes32[16] calldata publicKey,
    bytes32[5] calldata blockchainAccountId,
    address thisBCAddress,
    uint expiration /* onlyTrusted */
  ) external returns (bytes32 vmIdHash, bytes32 positionHash);

  function validateVM(
    bytes32 positionHash /* onlyTrusted */,
    uint expiration
  ) external returns (bytes32 id);
}
