// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICNS {
  
    function safeRegister(uint256 id) external;
    function safeRegister(uint256 id, bytes memory data) external;

    function ownerBurn(uint256 id) external;
}