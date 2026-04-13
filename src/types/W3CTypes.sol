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
  string[] capabilityInvocation;
  string[] capabilityDelegation;
  W3CService[] service;
  uint256 expiration; // In milliseconds
}

struct W3CVerificationMethod {
  string id;
  string type_;
  string controller;
  string publicKeyMultibase;
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
