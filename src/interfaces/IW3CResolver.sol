// SPDX-License-Identifier: Apache-2.0
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
  string publicKeyMultibase; // TODO: add support JWK?
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
  bytes32 methods;
  bytes32 id;
  bytes32 fragment; // Optional
}

// ! This Contract is NOT necessary, only adds ONchain DID resolution
/**
 * @title IW3CResolver
 * @author Miguel Gómez Carpena
 * @dev Interface for resolving W3C Decentralized Identifiers (DIDs).
 */
interface IW3CResolver {
  /**
   * @dev Resolves a W3C DID and returns the corresponding DID document.
   * @param didInput The input parameters for resolving the DID.
   * @param includeExpired Flag indicating whether to include expired DID documents.
   * @return didDocument The resolved DID document.
   */
  function resolve(W3CDidInput memory didInput, bool includeExpired)
    external
    view
    returns (W3CDidDocument memory didDocument);

  /**
   * @dev Resolves a specific verification method (VM) within a W3C DID and returns the corresponding VM.
   * @param didInput The input parameters for resolving the DID.
   * @param vmId The ID of the verification method.
   * @return vm The resolved verification method.
   */
  function resolveVm(W3CDidInput memory didInput, bytes32 vmId) external view returns (W3CVerificationMethod memory vm);

  /**
   * @dev Resolves a specific service within a W3C DID and returns the corresponding service.
   * @param didInput The input parameters for resolving the DID.
   * @param serviceId The ID of the service.
   * @return service The resolved service.
   */
  function resolveService(W3CDidInput memory didInput, bytes32 serviceId)
    external
    view
    returns (W3CService memory service);
}
