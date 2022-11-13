// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IERC1155.sol";

// https://github.com/ensdomains/ens-contracts/blob/master/contracts/wrapper/ERC1155Fuse.sol
// https://github.com/enjin/erc-1155/blob/master/contracts/ERC1155.sol
// solmate ERC1155

contract ERC1155 is IERC1155, ERC1155TokenReceiver {

  /*//////////////////////////////////////////////////////////////
                              ERC165
  //////////////////////////////////////////////////////////////*/

  // Borrowed from solmate ERC1155
  function supportsInterface(bytes4 _interfaceId)
    public view virtual override returns (bool) 
  {
    return
      _interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
      _interfaceId == 0xd9b67a26 || // ERC165 Interface ID for ERC1155
      _interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
  }

  /*//////////////////////////////////////////////////////////////
                          ERC1155 STORAGE
  //////////////////////////////////////////////////////////////*/
  
  // Hashed name in bytes32 => owner address
  // Only one owner per name
  mapping (bytes32 => address) internal nameOwner;

  // Owner address => (operator address => approved boolean)
  // Operators allowed to interact with all names
  // Owner address should always be msg.sender
  mapping (address => mapping(address => bool)) internal operatorApprovals;

  /*//////////////////////////////////////////////////////////////
                          ERC1155 METADATA
  //////////////////////////////////////////////////////////////*/



  /*//////////////////////////////////////////////////////////////
                           ERC1155 LOGIC
  //////////////////////////////////////////////////////////////*/

  // DONE
  function setApprovalForAll(address _operator, bool _approved)
    public virtual override
  {
    operatorApprovals[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _id,
    uint256 _value,
    bytes calldata _data
  ) public virtual override 
  {
    // Require sender to be owner or approved operator
    require(
      _from == msg.sender || operatorApprovals[_from][msg.sender] == true,
      "Caller must be owner or approved operator"
    );

    // Require _value to be one as there's only one of each name
    require(_value == 1, "_value must be 1 as name objects are non-fungible");

    // Borrowed from solmate ERC1155
    // Require recipient not be zero address or contract with no ERC1155 support
    require(
      _to.code.length == 0
        ? _to != address(0)
        : ERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, _id, _value, _data) ==
          ERC1155TokenReceiver.onERC1155Received.selector,
      "UNSAFE_RECIPIENT: 0x0 | Not ERC1155 Compatible Contract"
    );

    // Execute core transfer logic
    _transfer(_from, _to, _id, _value, _data);
  }

  /*//////////////////////////////////////////////////////////////
                            CORE LOGIC
  //////////////////////////////////////////////////////////////*/

  function _transfer(
    address _from,
    address _to,
    uint256 _id,
    uint256 _value,
    bytes calldata _data
  ) internal {

  }
}