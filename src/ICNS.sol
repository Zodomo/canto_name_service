// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICNS {

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    // Announce new contract owner added
    event OwnerAdded(address indexed caller, address indexed owner);
    // Announce new contract owner removed
    event OwnerRemoved(address indexed caller, address indexed owner);
    // Announce when contract owner withdraws
    event Withdraw(address indexed owner, uint256 indexed value);

    // Announce name registration
    event Register(address indexed registrant, uint256 indexed id, uint256 indexed expiry);
    // Announce primary name set
    event Primary(address indexed owner, uint256 indexed id);
    // Announce primary name cleared
    event NoPrimary(address indexed sender);
    // Announce name delegation
    event Delegate(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce name burn, store both name and derived ID
    event Burn(address indexed owner, uint256 indexed id);
    // Announce registration overpayment as tip
    event Tip(address indexed sender, uint256 indexed id, uint256 indexed tip);

    function setPrimary(string memory name) external;
    function clearPrimary() external;
    function getPrimary(address target) external view returns (string memory);

    function getOwner(string memory name) external view returns (address);
  
    function safeRegister(string memory name, uint256 term) external payable;
    function safeRegister(string memory name, uint256 term, bytes memory data) external payable;

    function safeBurn(string memory name) external;

    function transferName(string memory name, address recipient) external;

    function withdraw() external;
}