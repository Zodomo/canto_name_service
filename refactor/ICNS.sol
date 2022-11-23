// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICNS {

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    // Announce name registration
    event Register(address indexed registrant, uint256 indexed id, uint256 indexed expiry);
    // Announce name renewal
    event Renew(address indexed owner, uint256 indexed id, uint256 indexed expiry);
    // Announce primary name set
    event Primary(address indexed owner, uint256 indexed id);
    // Announce primary name cleared
    event NoPrimary(address indexed sender);
    // Announce name delegation
    event Delegate(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce delegation extension
    event Extend(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce name burn, store both name and derived ID
    event Burn(address indexed owner, uint256 indexed id);
    // Announce registration overpayment as tip
    event Tip(address indexed sender, uint256 indexed id, uint256 indexed tip);

    function addContractOwner(address owner) external;
    function removeContractOwner(address owner) external;

    function vrgdaInitialize(uint256 VRGDA, int256 targetPrice, int256 priceDecayPercent, int256 perTimeUnit) external;
    function prepBatchInitialize(uint256 VRGDA, int256 targetPrice, int256 priceDecayPercent, int256 perTimeUnit) external;
    function vrgdaBatchInitialize() external;

    function nameToID(string memory name) external pure returns (uint256);
    function stringLength(string memory name) external pure returns (uint256);
    function priceName(uint256 length) external returns (uint256);
    function totalNamesSold() external view returns (uint256);

    function ownerSetPrimary(string memory name) external;
    function delegateSetPrimary(string memory name) external;
    function clearPrimary() external;
    function getPrimary(address target) external view returns (string memory);

    function getOwner(string memory name) external view returns (address);
  
    function reservedRegister(string memory name, uint256 term) external payable;
    function safeRegister(string memory name, uint256 term) external payable;
    function safeRegister(string memory name, uint256 term, bytes memory data) external payable;

    function safeBurn(string memory name) external;

    function transferName(string memory name, address recipient) external;

    function renewName(string memory name, uint256 term) external payable;

    function delegateName(string memory name, address delegate, uint256 term) external;
    function extendDelegation(string memory name, uint256 term) external;

    function withdraw() external;
}