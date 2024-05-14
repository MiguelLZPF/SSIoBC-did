// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

struct W3CDidDocument {
  string[] context;
  string id;
  string[] controller;
  W3CVerificationMethod[] verificationMethod;
  string[] authentication;
  string[] assertionMethod;
  string[] keyAgreement;
  string[] capabilityDelegation;
  string[] capabilityInvocation;
  W3CService[] service;
  uint256 expiration; // In milliseconds
}

struct W3CVerificationMethod {
  string id;
  string type_;
  string controller;
  string publicKey; // TODO: support multibase and JWK
  string blockchainAccountId;
  string ethereumAddress;
  uint256 expiration; // In milliseconds
}

struct W3CService {
  string id;
  string[] type_;
  string[] serviceEndpoint;
}

struct W3CDidInput {
  bytes32 method0;
  bytes32 method1;
  bytes32 method2;
  bytes32 id;
}

// ! This Contract is NOT necessary, only adds ONchain DID resolution
interface IW3CResolver {
  function resolve(
    W3CDidInput memory didInput
  ) external view returns (W3CDidDocument memory didDocument);

  function resolveVm(
    W3CDidInput memory didInput,
    bytes32 vmId
  ) external view returns (W3CVerificationMethod memory vm);

  function resolveService(
    W3CDidInput memory didInput,
    bytes32 serviceId
  ) external view returns (W3CService memory service);
}
