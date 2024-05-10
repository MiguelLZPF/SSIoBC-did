// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import { IW3CResolver, W3CDidDocument, W3CVerificationMethod, W3CService, W3CDidInput } from "./interfaces/IW3CResolver.sol";
import { IDidManager, METHOD0, METHOD1, METHOD2 } from "./interfaces/IDidManager.sol";
import { VerificationMethod } from "./VMStorage.sol";
import { Service, SERVICE_MAX_LENGTH } from "./ServiceStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// ! This Contract is NOT necessary, only adds ONchain DID resolution
contract W3CResolver is IW3CResolver {
  // * The DID Manager contract
  IDidManager internal _didManager;

  constructor(IDidManager didManager) {
    _didManager = didManager;
  }

  function resolve(
    W3CDidInput memory didInput
  ) external view returns (W3CDidDocument memory didDocument) {
    // * Check parameters
    // Required
    _checkDidInput(didInput);
  }

  function resolveVm(
    W3CDidInput memory didInput,
    bytes32 vmId
  ) external view returns (W3CVerificationMethod memory vm) {
    // * Check parameters
    // Required
    _checkDidInput(didInput);
    // * Implementation
    return
      _toW3cVerificationMethod(
        _didManager.getVm(
          didInput.method0,
          didInput.method1,
          didInput.method2,
          didInput.id,
          vmId,
          0
        ),
        didInput
      );
  }

  function resolveService(
    W3CDidInput memory didInput,
    bytes32 serviceId
  ) external view returns (W3CService memory service) {
    // * Check parameters
    // Required
    _checkDidInput(didInput);
    // * Implementation
    return
      _toW3cService(
        _didManager.getService(
          didInput.method0,
          didInput.method1,
          didInput.method2,
          didInput.id,
          serviceId,
          0
        )
      );
  }

  function _checkDidInput(W3CDidInput memory didInput) internal pure {
    // * Check parameters
    // Required
    require(didInput.id != bytes32(0), "DID cant be 0");
    // Optional
    // -- reverse order to check method0 before is changed
    if (didInput.method0 == bytes32(0) && didInput.method2 == bytes32(0)) {
      didInput.method2 = METHOD2;
    }
    if (didInput.method0 == bytes32(0) && didInput.method1 == bytes32(0)) {
      didInput.method1 = METHOD1;
    }
    if (didInput.method0 == bytes32(0)) {
      didInput.method0 = METHOD0;
    }
  }

  function _toW3cVerificationMethod(
    VerificationMethod memory vm,
    W3CDidInput memory didInput
  ) internal pure returns (W3CVerificationMethod memory w3cVm) {
    return
      W3CVerificationMethod({
        id: string(_trimBytes(abi.encodePacked(vm.id))),
        type_: string(_trimBytes(abi.encodePacked(vm.type_))),
        controller: _formatDid(didInput),
        publicKey: string(_trimBytes(abi.encodePacked(vm.publicKey))),
        blockchainAccountId: string(_trimBytes(abi.encodePacked(vm.blockchainAccountId))),
        ethereumAddress: Strings.toHexString(vm.ethereumAddress),
        expiration: Strings.toString(vm.expiration * 1000) // expiration in ms
      });
  }

  function _toW3cService(
    Service memory service
  ) internal pure returns (W3CService memory w3cService) {
    uint8 typesLength = 0;
    uint8 serviceEndpointLength = 0;
    for (uint8 i = 0; i < SERVICE_MAX_LENGTH; i++) {
      if (service.type_[i] != bytes32(0)) {
        typesLength++;
      }
      if (service.serviceEndpoint[i] != bytes32(0)) {
        serviceEndpointLength++;
      }
      // Break if both are empty
      if (service.type_[i] == bytes32(0) && service.serviceEndpoint[i] == bytes32(0)) {
        break;
      }
    }
    string[] memory types = new string[](typesLength);
    string[] memory serviceEndpoints = new string[](serviceEndpointLength);
    for (uint8 i = 0; i < typesLength; i++) {
      types[i] = string(abi.encodePacked(service.type_[i]));
    }
    for (uint8 i = 0; i < serviceEndpointLength; i++) {
      serviceEndpoints[i] = string(abi.encodePacked(service.serviceEndpoint[i]));
    }
    return
      W3CService({
        id: string(abi.encodePacked(service.id)),
        type_: types,
        serviceEndpoint: serviceEndpoints
      });
  }

  function _formatDid(W3CDidInput memory didInput) internal pure returns (string memory did) {
    bytes memory methods = abi.encodePacked(didInput.method0, ":");
    if (didInput.method1 != bytes32(0)) {
      methods = abi.encodePacked(methods, didInput.method1, ":");
    }
    if (didInput.method2 != bytes32(0)) {
      methods = abi.encodePacked(methods, didInput.method2, ":");
    }

    return
      string(
        _trimBytes(abi.encodePacked(methods, bytesToHexString(abi.encodePacked(didInput.id))))
      );
  }

  function _trimBytes(bytes memory input) internal pure returns (bytes memory output) {
    if (input[0] == 0x00) {
      return new bytes(0);
    }
    bytes memory withoutZeros = new bytes(input.length);
    uint8 length = 0;
    for (uint8 i = 0; i < input.length; i++) {
      if (input[i] != 0x00) {
        withoutZeros[length] = input[i];
        length++;
      }
    }
    output = new bytes(length);
    for (uint8 i = 0; i < length; i++) {
      output[i] = withoutZeros[i];
    }
    return output;
  }

  function bytesToHexString(bytes memory input) public pure returns (string memory hexString) {
    // Fixed buffer size for hexadecimal convertion
    bytes memory converted = new bytes(input.length * 2);
    bytes memory _base = "0123456789abcdef";

    for (uint256 i = 0; i < input.length; i++) {
      converted[i * 2] = _base[uint8(input[i]) / _base.length];
      converted[i * 2 + 1] = _base[uint8(input[i]) % _base.length];
    }

    return string(converted);
  }
}
