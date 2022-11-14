// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICNS.sol";
import "./ERC721.sol";
import "./LinearVRGDA.sol";

contract CantoNameService is 
  ICNS,
  ERC721("Canto Name Service", "CNS"),
  LinearVRGDA
{

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                              STORAGE
  //////////////////////////////////////////////////////////////*/

  struct namesSold {
    uint256 one;
    uint256 two;
    uint256 three;
    uint256 four;
    uint256 five;
    uint256 sixOrMore;
  }

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor() {

  }

  /*//////////////////////////////////////////////////////////////
                       INTERNAL GENERAL LOGIC
  //////////////////////////////////////////////////////////////*/

  // Converts string name to uint256 ID
  function nameToID(string memory _name) internal returns (uint256) {
    return (uint256(keccak256(abi.encodePacked(_name))));
  }

  /*//////////////////////////////////////////////////////////////
                      INTERNAL MINT/BURN LOGIC
  //////////////////////////////////////////////////////////////*/

  function _register(string memory _name) internal {
    uint256 id = nameToID(_name);
    address owner = msg.sender;
    require(owner != address(0), "Zero address cannot mint");
    require(nameOwner[id] == address(0), "Name already minted");
    // Counter overflow is incredibly unrealistic.
    unchecked {
      _balanceOf[owner]++;
    }
    nameOwner[id] = owner;
    emit Transfer(address(0), owner, id);
  }

  function _burn(string memory _name) internal {
    uint256 id = nameToID(_name);
    address owner = nameOwner[id];
    require(owner != address(0), "NOT_MINTED");
    // Ownership check above ensures no underflow.
    unchecked {
      _balanceOf[owner]--;
    }
    delete nameOwner[id];
    delete getApproved[id];
    emit Transfer(owner, address(0), id);
  }

  /*//////////////////////////////////////////////////////////////
                    PUBLIC SAFE MINT/BURN LOGIC
  //////////////////////////////////////////////////////////////*/

  function safeRegister(string memory _name) external override {
    uint256 id = nameToID(_name);
    _register(id);
    require(
      msg.sender.code.length == 0 ||
        ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), id, "") ==
          ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
    );
  }

  function safeRegister(
    string memory _name,
    bytes memory _data
  ) external override {
    uint256 id = nameToID(_name);
    _register(id);
    require(
      msg.sender.code.length == 0 ||
        ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), id, _data) ==
          ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
    );
  }

  function ownerBurn(uint256 _id) external override {
    require(nameOwner[_id] == msg.sender, "Only name owner can burn");
    _burn(_id);
  }
}