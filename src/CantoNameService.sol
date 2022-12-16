// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./LinearVRGDA.sol";
import "./Allowlist.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract CantoNameService is ERC721, ERC721Enumerable, LinearVRGDA, Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a name is registered
    /// @param registrant Address of the registrant
    /// @param id Name ID
    /// @param expiry Expiry timestamp
    event Register(address indexed registrant, uint256 indexed id, uint256 indexed expiry);

    /// @notice Emitted when a name is renewed
    /// @param owner Address of the owner
    /// @param id Name ID
    /// @param expiry Expiry timestamp
    event Renew(address indexed owner, uint256 indexed id, uint256 indexed expiry);

    /// @notice Emitted when a name is set as primary
    /// @param owner Address of the owner
    /// @param id Name ID
    event Primary(address indexed owner, uint256 indexed id);

    /// @notice Emitted when a name is delegated
    /// @param delegate Address of the delegate
    /// @param id Name ID
    /// @param expiry Expiry timestamp
    event Delegate(address indexed delegate, uint256 indexed id, uint256 indexed expiry);

    /// @notice Emitted when a name delegation is extended
    /// @param delegate Address of the delegate
    /// @param id Name ID
    /// @param expiry Expiry timestamp
    event Extend(address indexed delegate, uint256 indexed id, uint256 indexed expiry);

    /// @notice Emitted when a name is burned
    /// @param owner Address of the owner
    /// @param id Name ID
    event Burn(address indexed owner, uint256 indexed id);

    /// @notice Emitted when a tip is received
    /// @param tipper Address of the tipper
    /// @param tip Amount of the tip
    event Tip(address indexed tipper, uint256 indexed tip);

    /// @notice Emitted when a withdrawal is made
    /// @param recipient Address of the recipient
    /// @param value Amount of the withdrawal
    event Withdraw(address indexed recipient, uint256 indexed value);

    /*//////////////////////////////////////////////////////////////
                STORAGE
    //////////////////////////////////////////////////////////////*/

    Allowlist allowlist;

    /*//////////////////////////////////////////////////////////////
                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _allowlist) ERC721("Canto Name Service", "CNS") {
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

    string baseURI;

    // Name data / URI(?) struct
    struct Name {
        string name;
        uint256 expiry;
        address delegate;
        uint256 delegationExpiry;
    }

    // Name data storage / registry
    mapping(uint256 => Name) public nameRegistry;
    // Primary name storage, one tokenId per address
    mapping(address => uint256) public primaryName;
    // Inverse name lookup tokenId to address
    mapping(uint256 => address) public currentPrimary;

    /// @notice sets base URI for token metadata
    /// @param _newBaseURI new base URI
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /*//////////////////////////////////////////////////////////////
                LIBRARY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts string name to uint256 tokenId
    /// @param _name Name to convert
    function nameToID(string memory _name) public pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(_name))));
    }

    /// @notice Return name owner addressa
    /// @param _name Name to check
    function getNameOwner(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ownerOf(tokenId);
    }

    /// @notice Return string length, properly counts all Unicode characters
    /// @param _string String to check
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

    /// @notice Returns price of name based on string length
    /// @param _length Length of the name
    /// @dev price is for one term
    /// @dev _length parameter directly calls corresponding VRGDA via getVRGDAPrice()
    function priceName(uint256 _length) public view returns (uint256) {
        uint256 price;
        if (_length > 0 && _length < 6) {
            price = _getVRGDAPrice(_length, tokenCounts[_length].current);
        } else {
            price = 0.01 ether; // ********* Price will be changed later ***************
        }
        return price;
    }

    /// @notice Overload of the function to calculate total price if yearly term is provided
    /// @param _length Length of the name
    /// @param _term Term of the name in years
    function priceNameWithTerm(uint256 _length, uint256 _term) public view returns (uint256) {
        return (priceName(_length) * _term);
    }

    /// @notice Increments the proper counters based on string length (accurate counts through 5)
    function _incrementCounts(uint256 _length) internal {
        if (_length > 0 && _length < 6) {
            tokenCounts[_length].current++;
            tokenCounts[_length].total++;
        } else {
            // 6 set as upper limit currently to make totalNamesSold logic easy
            tokenCounts[6].current++;
            tokenCounts[6].total++;
        }
    }

    /// @notice Returns total number of names sold
    function totalNamesSold() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 1; i < 7; i++) {
            total += tokenCounts[i].total;
        }
        return total;
    }

    /*//////////////////////////////////////////////////////////////
                VRGDA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice initializes VRGDA for calculations
    /// @param _VRGDA VRGDA ID - corresponds to string length
    /// @param _targetPrice target price for VRGDA
    /// @param _priceDecayPercent percent to decay price by
    /// @param _perTimeUnit units to sell per time unit
    /// @dev Can only be called after batch initialization
    function vrgdaInit(uint256 _VRGDA, int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit)
        public
        onlyOwner
    {
        require(batchInitialized == true, "CantoNameService::vrgdaInit::INITIALIZE_BATCH");
        _initialize(_VRGDA, _targetPrice, _priceDecayPercent, _perTimeUnit);
    }

    /// @notice prepares VRGDA for calculations
    /// @param _VRGDA VRGDA ID - corresponds to string length
    /// @dev Can only be called before batch initialization
    function vrgdaPrep(uint256 _VRGDA, int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit)
        public
        onlyOwner
    {
        require(batchInitialized == false, "CantoNameService::vrgdaPrep::BATCH_INITIALIZED");
        if (_VRGDA > 0 && _VRGDA < 6) {
            initData[_VRGDA].targetPrice = _targetPrice;
            initData[_VRGDA].priceDecayPercent = _priceDecayPercent;
            initData[_VRGDA].perTimeUnit = _perTimeUnit;
        } else {
            revert("CantoNameService::vrgdaPrep::INVALID_VRGDA");
        }
    }

    /// @notice Initialize all VRGDAs, only callable once
    /// @notice Checks to make sure all VRGDAs have data
    /// @dev vrgdaInit can only be called after vrgdaBatch
    function vrgdaBatch() public onlyOwner {
        // Iteratively check all batch parameters for completeness
        for (uint256 i = 1; i < 6; i++) {
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
        for (uint256 i = 1; i < 6; i++) {
            initData[i].targetPrice = 1e18;
            initData[i].priceDecayPercent = 0.2e18;
            initData[i].perTimeUnit = 1e18;
        }
        vrgdaBatch();
    }

    /*//////////////////////////////////////////////////////////////
                ALLOWLIST LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice admin function to reserve names
    /// @param _reserver address of the reserver
    /// @param _name name to reserve
    function adminReservation(address _reserver, string memory _name) public onlyOwner {
        uint256 tokenId = nameToID(_name);
        uint256 reservationExpiry = block.timestamp + 365 days;
        allowlist.administrativeReservation(_reserver, tokenId, reservationExpiry);
    }

    // Check to see if name is reserved
    function isReserved(uint256 _tokenId) public view returns (bool) {
        return allowlist.getReserver(_tokenId) != address(0x0);
    }

    /// @notice checks if reservation is valid
    /// @param _tokenId tokenId to check
    function _validateReservation(uint256 _tokenId) internal view {
        require(allowlist.getReserver(_tokenId) == msg.sender, "CantoNameService::_validateReservation::NOT_RESERVER");
        require(
            allowlist.getReservation(msg.sender) == _tokenId,
            "CantoNameService::_validateReservation::INVALID_RESERVATION"
        );
        require(
            allowlist.getReservationExpiry(msg.sender) >= block.timestamp,
            "CantoNameService::_validateReservation::RESERVATION_EXPIRED"
        );
    }

    /// @notice burns a reservation
    /// @param _name name to burn reservation for
    function burnReservation(string memory _name) public {
        burnReservationById(nameToID(_name));
    }

    // TODO: Add testing, I'm 60% sure this won't work since allowlist.deleteReservation(_tokenId) checks require(nameReserver[_tokenId] == msg.sender, "Allowlist::deleteReservation::NOT_RESERVER");
    // and msg.sender is this contract address, not the owner of the name.
    // FIX: Use tx.origin or call the deleteReservation function directly from the allowlist contract
    // Burn reservation, releasing it for others
    function burnReservationById(uint256 _tokenId) public {
        // Check to make sure reservation is valid
        _validateReservation(_tokenId);

        // Wipe out all reservation information
        allowlist.deleteReservation(_tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                ERC721 OVERLOADS
    //////////////////////////////////////////////////////////////*/

    /// @notice allows for checks before token transfer
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override (ERC721Enumerable, ERC721)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        require(
            nameRegistry[tokenId].delegationExpiry < block.timestamp, "ERC721::_beforeTokenTransfer::TOKEN_DELEGATED"
        );
    }

    /// @notice allows for checks after token transfer
    /// @dev requires the unused params to be named to override correctly
    function _afterTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override (ERC721)
    {
        nameRegistry[tokenId].delegate = address(0x0); // Clear delegate address
        nameRegistry[tokenId].delegationExpiry = 0; // Clear delegation expiry
        primaryName[currentPrimary[tokenId]] = 0; // Wipe primary address' primary name
        currentPrimary[tokenId] = address(0x0); // Reset inverse lookup
    }

    function ownerOfByName(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return ownerOf(tokenId);
    }

    function approveByName(address _to, string memory _name) public {
        uint256 tokenId = nameToID(_name);
        approve(_to, tokenId);
    }

    function getApprovedByName(string memory _name) public view returns (address) {
        uint256 tokenId = nameToID(_name);
        return getApproved(tokenId);
    }

    function transferFromByName(address _from, address _to, string memory _name) public {
        uint256 tokenId = nameToID(_name);
        transferFrom(_from, _to, tokenId);
    }

    function transferFrom(address _from, address _to, uint256 tokenId) public virtual override (ERC721, IERC721) {
        _afterTokenTransfer(_from, _to, tokenId, 1);
        transferFrom(_from, _to, tokenId);
    }

    function safeTransferFrom(address _from, address _to, string memory _name) public {
        safeTransferFromWithData(_from, _to, _name, "");
    }

    function safeTransferFromWithData(address _from, address _to, string memory _name, bytes memory _data) public {
        uint256 tokenId = nameToID(_name);
        safeTransferFrom(_from, _to, tokenId, _data);
    }

    /*//////////////////////////////////////////////////////////////
                REGISTER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal register logic
    /// @param _name name to register
    /// @param _tokenId tokenId to register name to
    /// @param _expiry expiry of name registration
    function _register(string memory _name, uint256 _tokenId, uint256 _expiry) internal {
        if (isReserved(_tokenId)) {
            // Consume reservation, validity will be checked during burn
            burnReservationById(_tokenId);
        }

        // Populate Name struct data
        nameRegistry[_tokenId].name = _name;
        nameRegistry[_tokenId].expiry = _expiry;

        emit Register(ownerOf(_tokenId), _tokenId, _expiry);
    }

    /// @notice registers name
    /// @param _to address to register name to
    /// @param _name name to register
    /// @param _term count of years to register _name for
    function safeRegister(address _to, string memory _name, uint256 _term) external payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);
        uint256 expiry = block.timestamp + (_term * 365 days);

        // Require valid name
        require(length > 0, "CantoNameService::safeRegister::MISSING_NAME");
        // Require term is more than 0
        require(_term > 0, "CantoNameService::safeRegister::MISSING_NAME");
        // Require price is fully paid
        require(msg.value >= price * _term, "CantoNameService::safeRegister::INSUFFICIENT_PAYMENT");

        // Call internal safe mint logic
        _safeMint(_to, tokenId, "");

        // Call internal register logic
        _register(_name, tokenId, expiry);

        // Increment counts for VRGDA logic
        _incrementCounts(length);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    /// @notice registers name without checking if the recipient can receive ERC-721 tokens
    /// @param _to address to register name to
    /// @param _name name to register
    /// @param _term count of years to register _name for
    function unsafeRegister(address _to, string memory _name, uint256 _term) external payable {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Calculate price based off name length
        uint256 price = priceName(length);
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

    /// @notice burns NFT
    /// @param _name burn this name's registration
    function burnName(string memory _name) external {
        // Generate tokenId from name string
        uint256 tokenId = nameToID(_name);
        burnNameById(tokenId);
    }

    // Checks if sender is approved via all means to manage the token
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /// @notice burns NFT
    /// @param _tokenId burn this tokenId
    function burnNameById(uint256 _tokenId) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::burnName::NOT_APPROVED");
        _burn(_tokenId);

        emit Burn(msg.sender, _tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                RENEW LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice renews name until a given expiry
    /// @param _tokenId renew registration for this tokenId
    /// @param _newExpiry expiration timestamp
    /// @dev Anyone can renew for anyone else
    function _renewByExpiry(uint256 _tokenId, uint256 _newExpiry) internal {
        // Name must not be expired to be renewed
        require(nameRegistry[_tokenId].expiry >= block.timestamp, "CantoNameService::_renew::NAME_EXPIRED");

        // Update expiry
        nameRegistry[_tokenId].expiry == _newExpiry;

        emit Renew(ownerOf(_tokenId), _tokenId, _newExpiry);
    }

    /// @notice renews name registration for a given term
    /// @param _name renew registration for this tokenId
    /// @param _term count of years to extend the delegation
    function renewName(string memory _name, uint256 _term) external payable {
        renewNameById(nameToID(_name), _term);
    }

    /// @notice renews name registration for a given term
    /// @param _tokenId renew registration for this tokenId
    /// @param _term count of years to extend the delegation
    /// @dev Anyone can renew for anyone else
    function renewNameById(uint256 _tokenId, uint256 _term) public payable {
        // Retrieve name string
        string memory name = nameRegistry[_tokenId].name;
        // Calculate name string character length
        uint256 length = stringLength(name);
        // Use name character length to calculate current price
        uint256 price = priceName(length);
        // Calculate new expiry timestamp

        uint256 newExpiry = nameRegistry[_tokenId].expiry + (_term * 365 days);

        // Require msg.value meets or exceeds renewal cost
        require(msg.value >= (price * _term), "CantoNameService::renewName::INSUFFICIENT_PAYMENT");

        // Execute internal renewal logic
        _renewByExpiry(_tokenId, newExpiry);
        (_tokenId, newExpiry);

        // Calculate overpayment tip if any and announce
        if (msg.value > price * _term) {
            emit Tip(msg.sender, msg.value - (price * _term));
        }
    }

    /*//////////////////////////////////////////////////////////////
                PRIMARY NAME LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice sets the primary name of a given name to the msg.sender
    /// @param _name name to set the primary address
    function setPrimary(string memory _name) public {
        setPrimaryById(nameToID(_name));
    }

    /// @notice sets the primary name of a given tokenId
    /// @param _tokenId tokenId to set the primary address
    function setPrimaryById(uint256 _tokenId) public {
        // Only owner or valid delegate can call
        require(
            (msg.sender == ownerOf(_tokenId) && nameRegistry[_tokenId].delegationExpiry < block.timestamp)
                || (
                    msg.sender == nameRegistry[_tokenId].delegate
                        && nameRegistry[_tokenId].delegationExpiry > block.timestamp
                ),
            "CantoNameService::setPrimary::NOT_APPROVED"
        );

        // Set primary name data
        primaryName[msg.sender] = _tokenId;
        currentPrimary[_tokenId] = msg.sender;

        emit Primary(msg.sender, _tokenId);
    }

    /// @notice return the primary name of a given address
    /// @param _target return the primary name of this address
    function getPrimary(address _target) public view returns (string memory) {
        uint256 tokenId = primaryName[_target];
        return nameRegistry[tokenId].name;
    }

    /*//////////////////////////////////////////////////////////////
                DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice delegate registered name to another address
    /// @param _tokenId tokenId to delegate
    /// @param delegate_ address to delegate the registered name to
    /// @param _expiry expiration timestamp
    function _delegate(uint256 _tokenId, address delegate_, uint256 _expiry) internal {
        // Require delegation term not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _expiry, "CantoNameService::_delegate::OWNERSHIP_EXPIRY");

        // Require not already delegated
        require(
            nameRegistry[_tokenId].delegationExpiry < block.timestamp, "CantoNameService::_delegate::DELEGATION_ACTIVE"
        );

        // Set delegate address
        nameRegistry[_tokenId].delegate = delegate_;
        // Save delegation expiry timestamp
        nameRegistry[_tokenId].delegationExpiry = _expiry;

        // If used as primary by owner, clear
        if (primaryName[ownerOf(_tokenId)] == _tokenId) {
            primaryName[currentPrimary[_tokenId]] = 0; // Wipe primary address' primary name
            currentPrimary[_tokenId] = address(0x0); // Reset inverse lookup
        }

        emit Delegate(delegate_, _tokenId, _expiry);
    }

    /// @notice delegate registered name to another address
    /// @param _name name to delegate to another address
    /// @param delegate_ address to delegate the registered name to
    /// @param _term count of years to extend the delegation
    function delegateName(string memory _name, address delegate_, uint256 _term) public {
        delegateNameById(nameToID(_name), delegate_, _term);
    }

    /// @notice delegate registered name to other address
    /// @param _tokenId tokenId to delegate
    /// @param delegate_ address to delegate the registered name to
    /// @param _term count of years to extend the delegation
    function delegateNameById(uint256 _tokenId, address delegate_, uint256 _term) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::delegateName::NOT_APPROVED");

        // Calculate expiry timestamp
        uint256 delegationExpiry = block.timestamp + (_term * 365 days);

        _delegate(_tokenId, delegate_, delegationExpiry);
    }

    /// @notice delegate registered name to other address with timestamp precision
    /// @param _name name to delegate to another address
    /// @param delegate_ address to delegate the registered name to
    /// @param _expiry expiration timestamp
    function delegateNameWithPrecision(string memory _name, address delegate_, uint256 _expiry) public {
        delegateNameWithPrecisionById(nameToID(_name), delegate_, _expiry);
    }

    /// @notice delegate registered name to other address with timestamp precision
    /// @param _tokenId tokenId to delegate
    /// @param delegate_ address to delegate the registered name to
    /// @param _expiry expiration timestamp
    function delegateNameWithPrecisionById(uint256 _tokenId, address delegate_, uint256 _expiry) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::delegateNameWithPrecision::NOT_APPROVED");

        _delegate(_tokenId, delegate_, _expiry);
    }

    /// @notice extend delegation expiry to other address
    /// @param _tokenId tokenId to extend the delegation
    /// @param _newExpiry new expiration timestamp
    function _extend(uint256 _tokenId, uint256 _newExpiry) internal {
        // Require new delegation expiry not meet or exceed owner's expiry
        require(nameRegistry[_tokenId].expiry > _newExpiry, "CantoNameService::_extend::OWNERSHIP_EXPIRY");

        uint256 delegationExpiry = nameRegistry[_tokenId].delegationExpiry;

        require(_newExpiry > delegationExpiry, "CantoNameService::_extend::NEW_EXPIRY_DOES_NOT_EXTEND");

        require(delegationExpiry >= block.timestamp, "CantoNameService::_extend::DELEGATION_INACTIVE");

        nameRegistry[_tokenId].delegationExpiry = _newExpiry;

        emit Extend(nameRegistry[_tokenId].delegate, _tokenId, _newExpiry);
    }

    /// @notice allow token holder to extend delegation to other address
    /// @param _name name to extend the delegation for
    /// @param _term count of years to extend the delegation
    function extendDelegation(string memory _name, uint256 _term) public {
        extendDelegationById(nameToID(_name), _term);
    }

    /// @notice allow token holder to extend delegation to other address
    /// @param _tokenId tokenId to extend the delegation
    /// @param _term count of years to extend the delegation
    function extendDelegationById(uint256 _tokenId, uint256 _term) public {
        // Require owner/approved/operator
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::extendDelegation::NOT_APPROVED");

        // Calculate expiry timestamp
        uint256 newDelegationExpiry =
            block.timestamp + (nameRegistry[_tokenId].delegationExpiry - block.timestamp) + (_term * 365 days);

        _extend(_tokenId, newDelegationExpiry);
    }

    /// @notice allow token holder to extend delegation expiry with timestamp precision
    /// @param _name name to extend the delegation for
    /// @param _newExpiry new expiration timestamp
    function extendDelegationWithPrecision(string memory _name, uint256 _newExpiry) external {
        extendDelegationWithPrecisionById(nameToID(_name), _newExpiry);
    }

    /// @notice allow token holder to extend delegation to other address with timestamp precision
    /// @param _tokenId tokenId to extend the delegation
    /// @param _newExpiry new expiration timestamp
    function extendDelegationWithPrecisionById(uint256 _tokenId, uint256 _newExpiry) public {
        require(
            _isApprovedOrOwner(msg.sender, _tokenId), "CantoNameService::extendDelegationWithPrecision::NOT_APPROVED"
        );

        _extend(_tokenId, _newExpiry);
    }

    /*//////////////////////////////////////////////////////////////
                PAYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function withdraw() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "CantoNameService::withdraw::WITHDRAW_FAILED");

        emit Withdraw(msg.sender, address(this).balance);
    }

    receive() external payable {}
    fallback() external payable {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC721, ERC721Enumerable)
        returns (bool)
    {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }
}
