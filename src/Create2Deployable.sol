// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Create2.sol";

contract Create2Deployable {
  event Deployed(address indexed contractAddress, address indexed sender);

  function deploy(
    uint256 amount,
    bytes32 salt,
    bytes calldata bytecode
  ) external returns (address addr) {
    addr = Create2.deploy(amount, salt, bytecode);
    emit Deployed(addr, msg.sender);
    return addr;
  }

  function computeAddress(
    bytes32 salt,
    bytes32 bytecodeHash,
    address deployer
  ) external view returns (address addr) {
    if (deployer == address(0)) {
      return Create2.computeAddress(salt, bytecodeHash);
    }
    return Create2.computeAddress(salt, bytecodeHash, deployer);
  }
}
