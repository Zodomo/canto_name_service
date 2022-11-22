// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC721.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract CantoNameService is ERC721("Canto Name Service", "CNS"), Ownable, ReentrancyGuard {

}