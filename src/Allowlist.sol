// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Inspired by ERC721C https://github.com/transmissions11/ERC721C
contract Allowlist {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Log verified users
    event Verified(address indexed user);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Require CAPTCHA passed
    modifier passCAPTCHA() {
        require(hasPassedCAPTCHA[msg.sender], "MUST_PASS_CAPTCHA");
        _;
    }

    // Require reservation not used, currently restricts to one reservation
    modifier reservationValid() {
        require(reservationUsed[msg.sender] != true, "RESERVATION_USED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                     VERIFICATION/ALLOWLIST STORAGE
    //////////////////////////////////////////////////////////////*/

    // User CAPTCHA verification
    mapping(address => bool) public hasPassedCAPTCHA;
    // Tracks whether user has used their one reservation
    mapping(address => bool) public reservationUsed;
    // Stores reservation expiry timestamp, currently 365 days after reservation
    mapping(address => uint256) public reservationExpiry;

    // Name reservation mappings to assist with lookups
    mapping(address => uint256) public nameReservation;
    mapping(uint256 => address) public nameReserver;

    // Return reserved ID
    function getReservation(address _reserver) public view returns (uint256) {
        return nameReservation[_reserver];
    }
    // Return reserver address
    function getReserver(uint256 _id) public view returns (address) {
        return nameReserver[_id];
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    /*//////////////////////////////////////////////////////////////
                              EIP-712 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("CAPTCHA"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                           VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    // Borrowed from https://solidity-by-example.org/signature/
    function splitSignature(bytes memory _sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        // Check signature length
        require(_sig.length == 65, "SIGNATURE_LENGTH");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    // Signature verification logic
    function _verify(uint8 _v, bytes32 _r, bytes32 _s) internal {
        address recoveredAddress = ecrecover(
            keccak256(abi.encodePacked("\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("CAPTCHA()"))))),
            _v,
            _r,
            _s
        );

        require(recoveredAddress == msg.sender, "INVALID_SIGNER");

        hasPassedCAPTCHA[msg.sender] = true;

        emit Verified(msg.sender);
    }

    // Callable verify function that only requires signature argument
    function verify(bytes memory _sig) public {
        // Split signature to prep _verify call args
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_sig);
        _verify(v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                           ALLOWLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    // Reserve name after passing CAPTCHA and ensuring reservation hasn't been used
    function reserveName(uint256 _id) public passCAPTCHA reservationValid {
        // Confirm name hasn't been reserved
        require(nameReserver[_id] == address(0), "NAME_RESERVED");
        // Block redundant reservations
        require(nameReserver[_id] != msg.sender, "ALREADY_RESERVED");

        // If another name has been reserved, clear the old name's reserver before processing new name
        if (nameReservation[msg.sender] != 0) {
            nameReserver[nameReservation[msg.sender]] = address(0);
        }
        
        // Set new name reservation
        nameReservation[msg.sender] = _id;
        nameReserver[_id] = msg.sender;
        reservationExpiry[msg.sender] = block.timestamp + 365 days;
    }
}
