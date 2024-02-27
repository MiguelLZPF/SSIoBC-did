// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

// Import this file to use console.log
// import "hardhat/console.sol";
import "./interfaces/IStorage.sol";
import "./interfaces/IPayableOwner.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract Storage is IStorage, IPayableOwner, AccessControlEnumerable {
  //* Stored value
  uint256 number;

  //* Role list

  // owner = DEFAULT_ADMIN_ROLE

  constructor(uint256 initialValue) {
    // Set msg.sender as DA or "Owner"
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    number = initialValue;
  }

  function store(uint256 num) public {
    number = num + 2;
    emit Stored(num);
  }

  function retrieve() public view returns (uint256) {
    return number;
  }

  function payMe() public payable {
    (bool success, ) = payable(getRoleMember(DEFAULT_ADMIN_ROLE, 0)).call{value: msg.value}("");
    require(success, "Failed to send money");
    emit ThankYou(getRoleMember(DEFAULT_ADMIN_ROLE, 0), _msgSender(), "Thanks!!");
  }
}
