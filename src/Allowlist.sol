// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/access/Ownable2Step.sol";

// Inspired by ERC721C by transmissions11 https://github.com/transmissions11/ERC721C
contract Allowlist is Ownable2Step {

    /*//////////////////////////////////////////////////////////////
                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Require CAPTCHA passed
    modifier passCAPTCHA() {
        require(hasPassedCAPTCHA[msg.sender], "Allowlist::passCAPTCHA::PASS_CAPTCHA");
        _;
    }

    // Require reservation not used, currently restricts to one reservation
    modifier reservationValid() {
        require(reservationUsed[msg.sender] != true, "Allowlist::reservationValid::RESERVATION_USED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                VERIFICATION/ALLOWLIST STORAGE
    //////////////////////////////////////////////////////////////*/

    // Cutoff timestamp
    uint256 cutoff;
    
    // CantoNameService contract address
    // Used for whitelisting deleteReservation() logic to prevent tx.phishing
    address CNS;

    // User CAPTCHA verification
    mapping(address => bool) internal hasPassedCAPTCHA;
    // Tracks whether user has used their one reservation
    mapping(address => bool) internal reservationUsed;

    // Name reservation mappings to assist with lookups
    mapping(address => uint256) public nameReservation;
    mapping(uint256 => address) public nameReserver;
    // Stores reservation expiry timestamp, currently 365 days after reservation
    mapping(address => uint256) public reservationExpiry;

    /*//////////////////////////////////////////////////////////////
                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Log verified users
    event Verify(address indexed user);
    // Log reservations
    event Reserve(address indexed reserver, uint256 indexed tokenId, uint256 indexed expiry);
    // Log releases
    event Release(address indexed reserver, uint256 indexed tokenId);

    /*//////////////////////////////////////////////////////////////
                MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Set the CNS contract address
    function setCNSAddress(address _CNS) public onlyOwner {
        CNS = _CNS;
    }

    // Allow admin to manually set registrations
    function administrativeReservation(
        address _reserver,
        uint256 _tokenId,
        uint256 _expiry
    ) public onlyOwner {
        nameReserver[_tokenId] = _reserver;
        nameReservation[_reserver] = _tokenId;
        reservationExpiry[_reserver] = _expiry;
    }

    /*//////////////////////////////////////////////////////////////
                GENERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // TODO: Why not change the nameReservation mapping to a public mapping and remove this function?
    // Return reserved ID
    function getReservation(address _reserver) public view returns (uint256) {
        return nameReservation[_reserver];
    }
    // TODO: Why not change the nameReserver mapping to a public mapping and remove this function?
    // Return reserver address
    function getReserver(uint256 _tokenId) public view returns (address) {
        return nameReserver[_tokenId];
    }

    // TODO: Why not change the reservationExpiry mapping to a public mapping and remove this function?
    // Return reservation expiry timestamp
    function getReservationExpiry(address _reserver) public view returns (uint256) {
        return reservationExpiry[_reserver];
    }

    // Delete the above data
    function deleteReservation(address _reserver, uint256 _tokenId) public {
        // Confirm _reserver is the _tokenId reserver
        require(nameReserver[_tokenId] == _reserver, "Allowlist::deleteReservation::INCORRECT_RESERVER");
        // If tx.origin isn't the reserver (contract wallets), only allow CantoNameService to call
        if (nameReserver[_tokenId] != tx.origin) {
            require(msg.sender == CNS, "Allowlist::deleteReservation::NOT_CANTONAMESERVICE");
        }
        // Otherwise, make sure msg.sender is the reserver
        else if (nameReserver[_tokenId] != msg.sender) {
            revert("Allowlist::deleteReservation::NOT_RESERVER");
        }
        
        // Delete reservation data
        delete nameReserver[_tokenId];
        delete nameReservation[_reserver];
        delete reservationExpiry[_reserver];

        emit Release(_reserver, _tokenId);
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
                keccak256("CAPTCHA()"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // _cutoff is the amount of time the Allowlist should be open for
    // It is not an exact timestamp. It is added to block.timestamp
    constructor(uint256 _cutoff) {
        transferOwnership(msg.sender);
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
        cutoff = block.timestamp + _cutoff;
    }

    /*//////////////////////////////////////////////////////////////
                VERIFICATION LOGIC
    //////////////////////////////////////////////////////////////*/

    // Borrowed from https://solidity-by-example.org/signature/
    function splitSignature(bytes memory _sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        // Check signature length
        require(_sig.length == 65, "Allowlist::splitSignature::SIGNATURE_LENGTH");

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

        require(recoveredAddress == msg.sender, "Allowlist::_verify::INVALID_SIGNER");

        hasPassedCAPTCHA[msg.sender] = true;

        emit Verify(msg.sender);
    }

    // Callable verify function that only requires signature argument
    function verify(bytes memory _sig) public {
        // Require cutoff hasn't been reached
        require(cutoff >= block.timestamp, "Allowlist::verify::RESERVATIONS_CLOSED");
        // Split signature to prep _verify call args
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_sig);
        _verify(v, r, s);
    }

    /*//////////////////////////////////////////////////////////////
                ALLOWLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    // Reserve name after passing CAPTCHA and ensuring reservation hasn't been used
    function reserveName(uint256 _tokenId) public passCAPTCHA reservationValid {
        // Require cutoff hasn't been reached
        require(cutoff >= block.timestamp, "Allowlist::reserveName::RESERVATIONS_CLOSED");
        // Confirm name hasn't been reserved
        require(nameReserver[_tokenId] == address(0), "Allowlist::reserveName::NAME_RESERVED");
        // Block redundant reservations
        require(nameReserver[_tokenId] != msg.sender, "Allowlist::reserveName::RESERVATION_PROCESSED");

        // Set reservation expiry
        uint256 expiry = block.timestamp + 365 days;

        // If another name has been reserved, clear the old name's reserver before processing new name
        if (nameReservation[msg.sender] != 0) {
            nameReserver[nameReservation[msg.sender]] = address(0);
            
            emit Release(msg.sender, nameReservation[msg.sender]);
        }
        
        // Set new name reservation data
        nameReservation[msg.sender] = _tokenId;
        nameReserver[_tokenId] = msg.sender;
        // Expiry calculation can be unchecked as block.timestamp cannot force an overflow
        unchecked {
            reservationExpiry[msg.sender] = expiry;
        }

        emit Reserve(msg.sender, _tokenId, expiry);
    }
}