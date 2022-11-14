// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICNS {
  
    function safeRegister(string memory name, uint256 term) external payable;
    function safeRegister(string memory name, uint256 term, bytes memory data) external payable;

    function safeBurn(string memory name) external;
}