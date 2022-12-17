// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/access/Ownable2Step.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

// Inspired by ERC721C by transmissions11 https://github.com/transmissions11/ERC721C
contract Allowlist is Ownable2Step {

    /*//////////////////////////////////////////////////////////////
                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Require CAPTCHA passed
    modifier passCAPTCHA() {
        require(_hasPassedCAPTCHA[msg.sender], "Allowlist::passCAPTCHA::PASS_CAPTCHA");
        _;
    }

    // Require reservation not used, currently restricts to one reservation
    modifier reservationValid() {
        require(!_reservationUsed[msg.sender], "Allowlist::reservationValid::RESERVATION_USED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                VERIFICATION/ALLOWLIST STORAGE
    //////////////////////////////////////////////////////////////*/

    // Cutoff timestamp
    uint256 immutable cutoff;
    
    // CantoNameService contract address
    // Used for whitelisting deleteReservation() logic to prevent tx.phishing
    address CNS;

    // User CAPTCHA verification
    mapping(address => bool) internal _hasPassedCAPTCHA;
    // Tracks whether user has used their one reservation
    mapping(address => bool) internal _reservationUsed;

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
                EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    /*//////////////////////////////////////////////////////////////
                EIP-712 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
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
    constructor(uint256 _cutoff) payable {
        transferOwnership(msg.sender);
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
        cutoff = block.timestamp + _cutoff;
    }

    /*//////////////////////////////////////////////////////////////
                ALLOWLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    // Callable verify function that only requires signature argument
    function verify(bytes memory _sig) public {
        // Require cutoff hasn't been reached
        require(cutoff >= block.timestamp, "Allowlist::verify::RESERVATIONS_CLOSED");
        
        // Generate verification message hash
        bytes32 msgHash = keccak256(abi.encodePacked("\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("CAPTCHA()")))));

        // Use OZ ECDSA.recover to recover signature address
        address recoveredAddress = ECDSA.recover(msgHash, _sig);

        // Verify recoveredAddress is msg.sender
        require(msg.sender == recoveredAddress, "Allowlist::verify::NOT_SIGNER");

        // Set verification/CAPTCHA pass
        _hasPassedCAPTCHA[msg.sender] = true;

        emit Verify(msg.sender);
    }

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
            delete nameReserver[nameReservation[msg.sender]];
            
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
}