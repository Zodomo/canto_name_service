// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC721.sol";
import "./LinearVRGDA.sol";
import "./Allowlist.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract CantoNameService is ERC721("Canto Name Service", "CNS"), LinearVRGDA, Ownable, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Announce name registration
    event Register(address indexed registrant, uint256 indexed id, uint256 indexed expiry);
    // Announce name renewal
    event Renew(address indexed owner, uint256 indexed id, uint256 indexed expiry);
    // Announce primary name set
    event Primary(address indexed owner, uint256 indexed id);
    // Announce name delegation
    event Delegate(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce delegation extension
    event Extend(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce name burn, store both name and derived ID
    event Burn(address indexed owner, uint256 indexed id);
    // Announce payable function overpayments as tips
    event Tip(address indexed tipper, uint256 indexed tip);
    // Announce contract withdrawals
    event Withdraw(address indexed recipient, uint256 indexed value);

    /*//////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////*/

    Allowlist allowlist;

    /*//////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _allowlist) {
        transferOwnership(msg.sender);
        setAllowlist(_allowlist);
    }

    /*//////////////////////////////////////////////////////////////
                MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Set Allowlist contract address
    // Can only be called if VRGDA batch initialization has not occurred
    function setAllowlist(address _allowlist) public onlyOwner {
        require(batchInitialized != true, "CantoNameService::_setAllowlist::BATCH_INITIALIZED");
        allowlist = Allowlist(_allowlist);
    }

    // Change base URI
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /*//////////////////////////////////////////////////////////////
                LIBRARY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Converts string name to uint256 tokenId
    function nameToID(string memory _name) public pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(_name))));
    }

    // Return name owner address
    function getNameOwner(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ownerOf(tokenId);
    }

    // Return string length, properly counts all Unicode characters
    function stringLength(string memory _string) public pure returns (uint256) {
        uint256 charCount; // Number of characters in _string regardless of char byte length
        uint256 charByteCount = 0; // Number of bytes in char (a = 1, € = 3)
        uint256 byteLength = bytes(_string).length; // Total length of string in raw bytes

        // Determine how many bytes each character in string has
        for (charCount = 0; charByteCount < byteLength; charCount++) {
            bytes1 b = bytes(_string)[charByteCount]; // if tree uses first byte to determine length
            if (b < 0x80) {
                charByteCount += 1;
            } else if (b < 0xE0) {
                charByteCount += 2;
            } else if (b < 0xF0) {
                charByteCount += 3;
            } else if (b < 0xF8) {
                charByteCount += 4;
            } else if (b < 0xFC) {
                charByteCount += 5;
            } else {
                charByteCount += 6;
            }
        }
        return charCount;
    }

    // Returns proper VRGDA price for name based off string length
    // _length parameter directly calls corresponding VRGDA via getVRGDAPrice()
    function priceName(uint256 _length) public view returns (uint256) {
        uint256 price;
        if (_length > 0 && _length < 6) {
            price = _getVRGDAPrice(_length, tokenCounts[_length].current);
        } else {
            price = 1 ether;
        }
        return price;
    }

    // Increments the proper counters based on string length (accurate counts through 5)
    function _incrementCounts(uint256 _length) internal {
        if (_length > 0 && _length < 6) {
            tokenCounts[_length].current++;
            tokenCounts[_length].total++;
        } else { // 6 set as upper limit currently to make totalNamesSold logic easy
            tokenCounts[6].current++;
            tokenCounts[6].total++;
        }
    }

    // Return total number of names sold
    function totalNamesSold() public view returns (uint256) {
        uint256 total;
        for (uint i = 1; i < 7; i++) {
            total += tokenCounts[i].total;
        }
        return total;
    }

    /*//////////////////////////////////////////////////////////////
                VRGDA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // Initialize / Reset a single VRGDA
    // Can only be performed after batch initialization
    function vrgdaInit(
        uint256 _VRGDA,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) public onlyOwner {
        require(batchInitialized == true, "CantoNameService::vrgdaInit::INITIALIZE_BATCH");
        _initialize(_VRGDA, _targetPrice, _priceDecayPercent, _perTimeUnit);
    }

    // Prepare initialization data for each VRGDA
    // Can only be called before batch initialization
    function vrgdaPrep(
        uint256 _VRGDA,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) public onlyOwner {
        require(batchInitialized == false, "CantoNameService::vrgdaPrep::BATCH_INITIALIZED");
        if (_VRGDA > 0 && _VRGDA < 6) {
            initData[_VRGDA].targetPrice = _targetPrice;
            initData[_VRGDA].priceDecayPercent = _priceDecayPercent;
            initData[_VRGDA].perTimeUnit = _perTimeUnit;
        } else {
            revert("CantoNameService::vrgdaPrep::INVALID_VRGDA");
        }
    }

    // Initialize all VRGDAs, only callable once
    // Checks to make sure all VRGDAs have data
    // vrgdaInit can only be called after vrgdaBatch
    function vrgdaBatch() public onlyOwner {
        // Iteratively check all batch parameters for completeness
        for (uint i = 1; i < 6; i++) {
            if (initData[i].targetPrice == 0) {
                revert MissingBatchData(i, true, false, false);
            }
            if (initData[i].priceDecayPercent == 0) {
                revert MissingBatchData(i, false, true, false);
            }
            if (initData[i].perTimeUnit == 0) {
                revert MissingBatchData(i, false, false, true);
            }
        }
        _batchInitialize();
    }

    // ************** THIS FUNCTION IS FOR TESTING PURPOSES ONLY AND SHOULD BE REMOVED BEFORE PRODUCTION ***************
    // Cheat batch init for testing purposes
    function vrgdaTest() public {
        for (uint i = 1; i < 6; i++) {
            initData[i].targetPrice = 1e18;
            initData[i].priceDecayPercent = 0.2e18;
            initData[i].perTimeUnit = 1e18;
        }
        vrgdaBatch();
    }

    /*//////////////////////////////////////////////////////////////
                ALLOWLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    // Administratively add reservations
    function adminReservation(address _reserver, string memory _name) public onlyOwner {
        uint256 tokenId = nameToID(_name);
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 reservationExpiry = block.timestamp + 365 days;
        allowlist.administrativeReservation(_reserver, tokenId, reservationExpiry);
    }

    // Check to see if name is reserved
    function isReserved(uint256 _tokenId) public view returns (bool) {
        if (allowlist.getReserver(_tokenId) != address(0x0)) {
            return true;
        } else {
            return false;
        }
    }

    // Check to make sure reservation is valid
    function _validateReservation(uint256 _tokenId) internal view {
        require(allowlist.getReserver(_tokenId) == msg.sender, "CantoNameService::_validateReservation::NOT_RESERVER");
        require(allowlist.getReservation(msg.sender) == _tokenId, "CantoNameService::_validateReservation::INVALID_RESERVATION");
        require(allowlist.getReservationExpiry(msg.sender) >= block.timestamp, "CantoNameService::_validateReservation::RESERVATION_EXPIRED");
    }

    // Pass call with string through to primary logic
    function burnReservation(string memory _name) public {
        uint256 tokenId = nameToID(_name);
        burnReservation(tokenId);
    }

    // Burn reservation, releasing it for others
    function burnReservation(uint256 _tokenId) public {
        // Check to make sure reservation is valid
        _validateReservation(_tokenId);

        // Wipe out all reservation information
        allowlist.deleteReservation(_tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                ERC721 OVERLOADS
    //////////////////////////////////////////////////////////////*/

    function ownerOf(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ERC721.ownerOf(tokenId);
    }

    function approve(address _to, string memory _name) public {
        uint256 tokenId = nameToID(_name);
        ERC721.approve(_to, tokenId);
    }

    function getApproved(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ERC721.getApproved(tokenId);
    }

    function transferFrom(
        address _from,
        address _to,
        string memory _name
    ) public {
        uint256 tokenId = nameToID(_name);
        ERC721.transferFrom(_from, _to, tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        string memory _name
    ) public {
        CantoNameService.safeTransferFrom(_from, _to, _name, "");
    }

    function safeTransferFrom(
        address _from,
        address _to,
        string memory _name,
        bytes memory _data
    ) public {
        uint256 tokenId = nameToID(_name);
        ERC721.safeTransferFrom(_from, _to, tokenId, _data);
    }

    /*//////////////////////////////////////////////////////////////
                REGISTER LOGIC
    //////////////////////////////////////////////////////////////*/

    // Register functions are not overloaded because the name string is required
    // Can't generate name from tokenId
    // Expired names will be minted again, internal logic blocks mints of current names
    // Anyone can register names to anyone

    // Internal register logic
    function _register(
        string memory _name,
        uint256 _tokenId,
        uint256 _expiry
    ) internal {
        if (isReserved(_tokenId)) {
            // Consume reservation, validity will be checked during burn
            burnReservation(_tokenId);
        }

        // Populate Name struct data
        nameRegistry[_tokenId].name = _name;
        nameRegistry[_tokenId].expiry = _expiry;

        emit Register(ERC721.ownerOf(_tokenId), _tokenId, _expiry);
    }

    // Pass call with no extra calldata through to primary logic
    function safeRegister(
        address _to,
        string memory _name,
        uint256 _term
    ) public payable {
        safeRegister(_to, _name, _term, "");
    }

    // Register name to ERC721-compatible destination
    function safeRegister(
        address _to,
        string memory _name,
        uint256 _term,
        bytes memory _data
    ) public payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 expiry = block.timestamp + (_term * 365 days);

        // Require valid name
        require(length > 0, "CantoNameService::safeRegister::MISSING_NAME");
        // Require price is fully paid
        require(msg.value >= price * _term, "CantoNameService::safeRegister::INSUFFICIENT_PAYMENT");

        // Call internal safe mint logic
        _safeMint(_to, tokenId, _data);

        // Call internal register logic
        _register(_name, tokenId, expiry);

        // Increment counts for VRGDA logic
        _incrementCounts(length);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    // Recipient checking is not processed with this call
    function unsafeRegister(
        address _to,
        string memory _name,
        uint256 _term
    ) public payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 expiry = block.timestamp + (_term * 365 days);

        // Require valid name
        require(length > 0, "CantoNameService::unsafeRegister::MISSING_NAME");
        // Require price is fully paid
        require(msg.value >= price * _term, "CantoNameService::unsafeRegister::INSUFFICIENT_PAYMENT");
        
        // Call internal mint logic
        _mint(_to, tokenId);

        // Call internal register logic
        _register(_name, tokenId, expiry);

        // Increment counts for VRGDA logic
        _incrementCounts(length);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    /*//////////////////////////////////////////////////////////////
                BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    // burnName function call using name
    function burnName(string memory _name) public {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        burnName(tokenId);
    }

    // Name is only burnable if undelegated
    function burnName(uint256 _tokenId) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::burnName::NOT_APPROVED");
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                RENEW LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal renewal logic
    function _renew(uint256 _tokenId, uint256 _newExpiry) internal {
        // Name must not be expired to be renewed
        require(nameRegistry[_tokenId].expiry >= block.timestamp, "CantoNameService::_renew::NAME_EXPIRED");

        // Update expiry
        nameRegistry[_tokenId].expiry == _newExpiry;

        emit Renew(ERC721.ownerOf(_tokenId), _tokenId, _newExpiry);
    }

    // Pass call with string through to primary logic
    function renewName(string memory _name, uint256 _term) public payable {
        // Generate name ID
        uint256 tokenId = nameToID(_name);
        renewName(tokenId, _term);
    }

    // Primary renewal function that calls all renewal logic
    // Payment must be sufficient before renewal logic executes
    // Anyone can renew for anyone else
    function renewName(uint256 _tokenId, uint256 _term) public payable {
        // Retrieve name string
        string memory name = nameRegistry[_tokenId].name;
        // Calculate name string character length
        uint256 length = stringLength(name);
        // Use name character length to calculate current price
        uint256 price = priceName(length);
        // Calculate new expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 newExpiry = nameRegistry[_tokenId].expiry + (_term * 365 days);

        // Require msg.value meets or exceeds renewal cost
        require(msg.value >= (price * _term), "CantoNameService::renewName::INSUFFICIENT_PAYMENT");

        // Execute internal renewal logic
        _renew(_tokenId, newExpiry);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    /*//////////////////////////////////////////////////////////////
                PRIMARY NAME LOGIC
    //////////////////////////////////////////////////////////////*/

    // Pass call with string through to primary logic
    function setPrimary(string memory _name) public {
        uint256 tokenId = nameToID(_name);
        setPrimary(tokenId);
    }

    // Set primary name
    // Allow owner to call only if undelegated
    function setPrimary(uint256 _tokenId) public {
        // Only owner or valid delegate can call
        require((msg.sender == ERC721.ownerOf(_tokenId) &&
                nameRegistry[_tokenId].delegationExpiry < block.timestamp) || 
            (msg.sender == nameRegistry[_tokenId].delegate && 
                nameRegistry[_tokenId].delegationExpiry > block.timestamp),
            "CantoNameService::setPrimary::NOT_APPROVED");

        // Set primary name data
        primaryName[msg.sender] = _tokenId;
        currentPrimary[_tokenId] = msg.sender;

        emit Primary(msg.sender, _tokenId);
    }

    // Return address' primary name
    function getPrimary(address _target) public view returns (string memory) {
        uint256 tokenId = primaryName[_target];
        return nameRegistry[tokenId].name;
    }

    /*//////////////////////////////////////////////////////////////
                DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal delegation logic
    // _expiry requires exact timestamp
    function _delegate(
        uint256 _tokenId,
        address delegate_,
        uint256 _expiry
    ) internal {
        // Require delegation term not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _expiry, "CantoNameService::_delegate::OWNERSHIP_EXPIRY");
        // Require not already delegated
        require(nameRegistry[_tokenId].delegationExpiry < block.timestamp, "CantoNameService::_delegate::DELEGATION_ACTIVE");

        // Set delegate address 
        nameRegistry[_tokenId].delegate = delegate_;
        // Save delegation expiry timestamp
        nameRegistry[_tokenId].delegationExpiry = _expiry;

        // If used as primary by owner, clear
        if (primaryName[ERC721.ownerOf(_tokenId)] == _tokenId) {
            primaryName[currentPrimary[_tokenId]] = 0; // Wipe primary address' primary name
            currentPrimary[_tokenId] = address(0x0); // Reset inverse lookup
        }

        emit Delegate(delegate_, _tokenId, _expiry);
    }

    // Pass call with string through to primary logic
    function delegateName(
        string memory _name,
        address delegate_,
        uint256 _term
    ) public {
        // Generate name ID
        uint256 tokenId = nameToID(_name);
        delegateName(tokenId, delegate_, _term);
    }

    // Allow owner, approved, or operator to delegate a name for a specific term in years
    function delegateName(
        uint256 _tokenId,
        address delegate_,
        uint256 _term
    ) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::delegateName::NOT_APPROVED");

        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 delegationExpiry = block.timestamp + (_term * 365 days);

        _delegate(_tokenId, delegate_, delegationExpiry);
    }

    // Pass call with string through to primary logic
    function delegateNameWithPrecision(
        string memory _name,
        address delegate_,
        uint256 _expiry
    ) public {
        uint256 tokenId = nameToID(_name);
        delegateNameWithPrecision(tokenId, delegate_, _expiry);
    }

    // Process delegation with precise expiry timestamp if yearly term is too imprecise
    function delegateNameWithPrecision(
        uint256 _tokenId,
        address delegate_,
        uint256 _expiry
    ) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::delegateNameWithPrecision::NOT_APPROVED");

        _delegate(_tokenId, delegate_, _expiry);
    }

    // Internal delegation logic
    function _extend(uint256 _tokenId, uint256 _newExpiry) internal {
        // Require new delegation expiry not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _newExpiry, "CantoNameService::_extend::OWNERSHIP_EXPIRY");
        // Require existing delegation to extend
        require(nameRegistry[_tokenId].delegationExpiry >= block.timestamp, "CantoNameService::_extend::DELEGATION_INACTIVE");

        nameRegistry[_tokenId].delegationExpiry = _newExpiry;

        emit Extend(nameRegistry[_tokenId].delegate, _tokenId, _newExpiry);
    }

    // Pass call with string through to primary logic
    function extendDelegation(string memory _name, uint256 _term) public {
        uint256 tokenId = nameToID(_name);
        extendDelegation(tokenId, _term);
    }

    // Extend name delegation
    function extendDelegation(uint256 _tokenId, uint256 _term) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::extendDelegation::NOT_APPROVED");

        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 newDelegationExpiry = 
            block.timestamp + 
            (nameRegistry[_tokenId].delegationExpiry - block.timestamp) + 
            (_term * 365 days);

        _extend(_tokenId, newDelegationExpiry);
    }

    // Pass call with string through to primary logic
    function extendDelegationWithPrecision(string memory _name, uint256 _newExpiry) public {
        uint256 tokenId = nameToID(_name);
        extendDelegationWithPrecision(tokenId, _newExpiry);
    }

    function extendDelegationWithPrecision(uint256 _tokenId, uint256 _newExpiry) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::extendDelegationWithPrecision::NOT_APPROVED");

        _extend(_tokenId, _newExpiry);
    }

    /*//////////////////////////////////////////////////////////////
                PAYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Payment handling functions if we need them
    function withdraw() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "CantoNameService::withdraw::WITHDRAW_FAILED");

        emit Withdraw(msg.sender, address(this).balance);
    }

    receive() external payable {}
    fallback() external payable {}
}
