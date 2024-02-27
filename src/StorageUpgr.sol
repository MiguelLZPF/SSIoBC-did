// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

// Import this file to use console.log
// import "hardhat/console.sol";
import "./interfaces/IStorage.sol";
import "./interfaces/IPayableOwner.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract StorageUpgr is
  IStorage,
  IPayableOwner,
  AccessControlEnumerableUpgradeable,
  UUPSUpgradeable
{
  //* Stored value
  uint256 number;
  //* Role list
  // Create a new role identifier for the "UpgradeAdmin"
  bytes32 public constant UPGRADE_ADMIN_ROLE = keccak256("UPGRADE_ADMIN_ROLE");

  // owner = DEFAULT_ADMIN_ROLE

  function initialize(uint256 initialValue) external initializer {
    __UUPSUpgradeable_init();
    __AccessControl_init();
    // Set msg.sender as DA or "Owner"
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // Set msg.sender as UA
    _grantRole(UPGRADE_ADMIN_ROLE, _msgSender());
    number = initialValue;
  }

  function store(uint256 num) public {
    number = num;
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

  // UUPS
  function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ADMIN_ROLE) {}
}
