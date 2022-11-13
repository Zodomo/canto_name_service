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

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor() {

  }

  /*//////////////////////////////////////////////////////////////
                      INTERNAL MINT/BURN LOGIC
  //////////////////////////////////////////////////////////////*/

  function _register(uint256 _id) internal {
    address owner = msg.sender;
    require(owner != address(0), "Zero address cannot mint");
    require(nameOwner[_id] == address(0), "Name already minted");
    // Counter overflow is incredibly unrealistic.
    unchecked {
      _balanceOf[owner]++;
    }
    nameOwner[_id] = owner;
    emit Transfer(address(0), owner, _id);
  }

  function _burn(uint256 _id) internal {
    address owner = nameOwner[_id];
    require(owner != address(0), "NOT_MINTED");
    // Ownership check above ensures no underflow.
    unchecked {
      _balanceOf[owner]--;
    }
    delete nameOwner[_id];
    delete getApproved[_id];
    emit Transfer(owner, address(0), _id);
  }

  /*//////////////////////////////////////////////////////////////
                    PUBLIC SAFE MINT/BURN LOGIC
  //////////////////////////////////////////////////////////////*/

  function safeRegister(uint256 _id) external override {
    _register(_id);
    require(
      msg.sender.code.length == 0 ||
        ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), _id, "") ==
          ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
    );
  }

  function safeRegister(
    uint256 _id,
    bytes memory _data
  ) external override {
    _register(_id);
    require(
      msg.sender.code.length == 0 ||
        ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), _id, _data) ==
          ERC721TokenReceiver.onERC721Received.selector,
        "UNSAFE_RECIPIENT"
    );
  }

  function ownerBurn(uint256 _id) external override {
    require(nameOwner[_id] == msg.sender, "Only name owner can burn");
    _burn(_id);
  }
}
