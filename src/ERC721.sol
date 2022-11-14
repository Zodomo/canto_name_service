// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IERC721.sol";

// Borrowed from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

// Inspired by Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721 is IERC165, IERC721, ERC721TokenReceiver {

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    // Used to confirm we accept ERC721 assets
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd; // ERC165 Interface ID for ERC721
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Used by transfer functions
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    // Announces approval address for any name, name can only have one single approval at any time
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    // Announces operator address for any name owner, giving them full control of all names
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    // Should store "Canto Name Service"
    string public name;
    // Should store "CNS"
    string public symbol;

    // Not currently implemented
    // function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    // uint256(bytes32) converted name to owner address
    mapping(uint256 => address) public nameOwner;
    // Store how many names any owner owns
    mapping(address => uint256) public _balanceOf;

    // Return owner of name id
    function ownerOf(uint256 _id) public view override returns (address owner) {
        require((owner = nameOwner[_id]) != address(0), "NOT_MINTED");
        return nameOwner[_id];
    }

    // Return how many names any owner has
    function balanceOf(address _owner) public view override returns (uint256) {
        require(_owner != address(0), "ZERO_ADDRESS");
        return _balanceOf[_owner];
    }

    /*//////////////////////////////////////////////////////////////
                        ERC721 NAME DATA STORAGE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    // Store single address approval for any name id
    mapping(uint256 => address) public approvals;

    // Owner address => (operator address => approved boolean)
    // Operators allowed to interact with all names
    // Owner address should always be msg.sender
    mapping (address => mapping(address => bool)) public operatorApprovals;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    // Sets single address approval, allowing one specific address control of specific name
    function approve(
        address _spender,
        uint256 _id
    ) public override {
        address owner = nameOwner[_id];
        require(msg.sender == owner || operatorApprovals[owner][msg.sender], "NOT_AUTHORIZED");
        approvals[_id] = _spender;
        emit Approval(owner, _spender, _id);
    }

    function getApproved(uint256 _id) public view override returns (address operator) { 
        return approvals[_id];
    }

    // Sets operator address to control all names owned by msg.sender
    function setApprovalForAll(
        address _operator,
        bool _approved
    ) public override {
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // Checks if msg.sender is operator for name owner
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view override returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    // Handles transferring name from owner to receiver
    // Can be called by operator
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(from == nameOwner[id], "SELF_TRANSFER");
        require(to != address(0), "ZERO_ADDRESS");
        require(
            msg.sender == from || operatorApprovals[from][msg.sender] || msg.sender == approvals[id],
            "NOT_AUTHORIZED"
        );

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }

        // Set new name owner
        nameOwner[id] = to;

        // Clear approvals after transfer
        delete approvals[id];

        emit Transfer(from, to, id);
    }

    // Used to ensure name is received by ERC721 compatible contract or EoA wallet
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    // Used to ensure name is received by ERC721 compatible contract or EoA wallet
    // Also passes calldata
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public override {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}
