// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICNS.sol";
import "./ERC721.sol";
import "./LinearVRGDA.sol";
import "./Allowlist.sol";

contract CantoNameService is ICNS, ERC721("Canto Name Service", "CNS"), LinearVRGDA, Allowlist {

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Require contract owner
    modifier onlyContractOwner() {
        require(owners[msg.sender], "NOT_CONTRACT_OWNER");
        _;
    }

    // Require valid name owner
    modifier onlyNameOwner(string memory _name) {
        uint256 id = nameToID(_name);
        require(_nameOwner[id] != address(0), "NOT_OWNED");
        require(nameRegistry[id].expiry > block.timestamp, "NAME_EXPIRED");
        require(ownerOf(id) == msg.sender, "NOT_NAME_OWNER");
        _;
    }

    // Require name delegate
    modifier onlyDelegate(string memory _name) {
        uint256 id = nameToID(_name);
        require(_nameOwner[id] != address(0), "NOT_DELEGATED");
        require(nameRegistry[id].delegate > msg.sender, "NOT_DELEGATE");
        _;
    }

    // Require name to not be delegated
    modifier notDelegated(string memory _name) {
        uint256 id = nameToID(_name);
        require(nameRegistry[id].delegationExpiry < block.timestamp, "NAME_DELEGATED");
        _;
    }

    // Require name to not be reserved for safeRegister
    modifier notReserved(string memory _name) {
        uint256 id = nameToID(_name);
        require(nameReserver[id] == address(0) ||
            reservationExpiry[msg.sender] < block.timestamp, "NAME_RESERVED");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Contract owners
    mapping(address => bool) public owners;

    // Name data / URI(?) struct
    struct Name {
        string name;
        uint256 expiry;
        address delegate;
        uint256 delegationExpiry;
    }
    // Name data storage / registry
    mapping(uint256 => Name) public nameRegistry;

    // Primary name storage, one name per address
    mapping(address => uint256) public primaryName;

    // Counts per character length kept for VRGDA functions
    // Stored here instead of LinearVRGDA because counts are a function of this instead of VRGDA
    struct namesSold {
        uint256 one;
        uint256 two;
        uint256 three;
        uint256 four;
        uint256 five;
        uint256 sixOrMore;
    }
    // storage for namesSold struct
    namesSold public soldCounts;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owners[payable(msg.sender)] = true;
    }

    /*//////////////////////////////////////////////////////////////
                          MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    // Add contract owner
    function addContractOwner(address _owner) public override onlyContractOwner {
        owners[payable(_owner)] = true;
        emit OwnerAdded(msg.sender, _owner);
    }

    // Remove contract owner
    function removeContractOwner(address _owner) public onlyContractOwner {
        delete owners[payable(_owner)];
        emit OwnerRemoved(msg.sender, _owner);
    }

    /*//////////////////////////////////////////////////////////////
                          VRDGA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // Initialize a single VRGDA
    // Can only be performed after batch initialization
    function vrgdaInitialize(
        uint256 _VRGDA,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) public override onlyContractOwner {
        require(vrgdaBatch.batchInitialized == true, "VRGDA_BATCH_INIT");
        initialize(_VRGDA, _targetPrice, _priceDecayPercent, _perTimeUnit);
    }

    // Prep VRGDA data for batch initialization
    function prepBatchInitialize(
        uint256 _VRGDA,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) public override onlyContractOwner {
        if (_VRGDA == 1) {
            vrgdaBatch.vrgdaOne.individualTargetPrice = _targetPrice;
            vrgdaBatch.vrgdaOne.individualPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.vrgdaOne.individualPerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 2) {
            vrgdaBatch.vrgdaTwo.individualTargetPrice = _targetPrice;
            vrgdaBatch.vrgdaTwo.individualPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.vrgdaTwo.individualPerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 3) {
            vrgdaBatch.vrgdaThree.individualTargetPrice = _targetPrice;
            vrgdaBatch.vrgdaThree.individualPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.vrgdaThree.individualPerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 4) {
            vrgdaBatch.vrgdaFour.individualTargetPrice = _targetPrice;
            vrgdaBatch.vrgdaFour.individualPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.vrgdaFour.individualPerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 5) {
            vrgdaBatch.vrgdaFive.individualTargetPrice = _targetPrice;
            vrgdaBatch.vrgdaFive.individualPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.vrgdaFive.individualPerTimeUnit = _perTimeUnit;
        } else {
            revert("Zero or >five characters not applicable to VRGDA emissions");
        }
    }

    // Initialize all VRGDAs
    // Can only be called once
    // Must be called before individual VRGDAs can be reinitialized
    function vrgdaBatchInitialize() public override onlyContractOwner {
        // Check to make sure all batch init data is supplied
        // Identify which VRGDA has missing data
        require(
            vrgdaBatch.vrgdaOne.individualTargetPrice > 0 && 
            vrgdaBatch.vrgdaOne.individualPriceDecayPercent > 0 && 
            vrgdaBatch.vrgdaOne.individualPerTimeUnit > 0,
            "VRGDA_ONE_MISSING_DATA"
        );
        require(
            vrgdaBatch.vrgdaTwo.individualTargetPrice > 0 && 
            vrgdaBatch.vrgdaTwo.individualPriceDecayPercent > 0 && 
            vrgdaBatch.vrgdaTwo.individualPerTimeUnit > 0,
            "VRGDA_TWO_MISSING_DATA"
        );
        require(
            vrgdaBatch.vrgdaThree.individualTargetPrice > 0 && 
            vrgdaBatch.vrgdaThree.individualPriceDecayPercent > 0 && 
            vrgdaBatch.vrgdaThree.individualPerTimeUnit > 0,
            "VRGDA_THREE_MISSING_DATA"
        );
        require(
            vrgdaBatch.vrgdaFour.individualTargetPrice > 0 && 
            vrgdaBatch.vrgdaFour.individualPriceDecayPercent > 0 && 
            vrgdaBatch.vrgdaFour.individualPerTimeUnit > 0,
            "VRGDA_FOUR_MISSING_DATA"
        );
        require(
            vrgdaBatch.vrgdaFive.individualTargetPrice > 0 && 
            vrgdaBatch.vrgdaFive.individualPriceDecayPercent > 0 && 
            vrgdaBatch.vrgdaFive.individualPerTimeUnit > 0,
            "VRGDA_FIVE_MISSING_DATA"
        );

        // After all checks, batch initialize
        batchInitialize();
    }

    // ************** THIS FUNCTION IS FOR TESTING PURPOSES ONLY AND SHOULD BE REMOVED BEFORE PRODUCTION ***************
    // Junk batch initialization so _register can query VRGDA function properly
    function testingInitialize() public onlyContractOwner {
        vrgdaBatch.vrgdaOne.individualTargetPrice = 
            vrgdaBatch.vrgdaOne.individualPriceDecayPercent = 
            vrgdaBatch.vrgdaOne.individualPerTimeUnit = 
        vrgdaBatch.vrgdaTwo.individualTargetPrice = 
            vrgdaBatch.vrgdaTwo.individualPriceDecayPercent = 
            vrgdaBatch.vrgdaTwo.individualPerTimeUnit = 
        vrgdaBatch.vrgdaThree.individualTargetPrice = 
            vrgdaBatch.vrgdaThree.individualPriceDecayPercent = 
            vrgdaBatch.vrgdaThree.individualPerTimeUnit = 
        vrgdaBatch.vrgdaFour.individualTargetPrice = 
            vrgdaBatch.vrgdaFour.individualPriceDecayPercent = 
            vrgdaBatch.vrgdaFour.individualPerTimeUnit = 
        vrgdaBatch.vrgdaFive.individualTargetPrice = 
            vrgdaBatch.vrgdaFive.individualPriceDecayPercent = 
            vrgdaBatch.vrgdaFive.individualPerTimeUnit = 1;
        vrgdaBatchInitialize();
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL/LIBRARY LOGIC
    //////////////////////////////////////////////////////////////*/

    // Converts string name to uint256 ID
    function nameToID(string memory _name) public pure override returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(_name))));
    }

    // Clear unnecessary information from previous owner
    function _clearName(uint256 id) internal {
        nameRegistry[id].delegate = address(0);
        nameRegistry[id].delegationExpiry = 0;
    }

    // Erase all name data for burn
    function _eraseName(uint256 id) internal {
        nameRegistry[id].name = "";
        nameRegistry[id].expiry = 0;
        nameRegistry[id].delegate = address(0);
        nameRegistry[id].delegationExpiry = 0;
    }

    // Return string length, properly counts all Unicode characters
    function stringLength(string memory _string) public pure override returns (uint256) {
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
    function priceName(uint256 _length) public override returns (uint256) {
        uint256 price;
        if (_length == 1) {
            price = getVRGDAPrice(_length, soldCounts.one);
        } else if (_length == 2) {
            price = getVRGDAPrice(_length, soldCounts.two);
        } else if (_length == 3) {
            price = getVRGDAPrice(_length, soldCounts.three);
        } else if (_length == 4) {
            price = getVRGDAPrice(_length, soldCounts.four);
        } else if (_length == 5) {
            price = getVRGDAPrice(_length, soldCounts.five);
        } else {
            price = 1 ether;
        }
        return price;
    }

    // Increments the proper sale counter based on string length
    function _incrementCounts(uint256 _length) internal {
        if (_length == 1) {
            soldCounts.one++;
        } else if (_length == 2) {
            soldCounts.two++;
        } else if (_length == 3) {
            soldCounts.three++;
        } else if (_length == 4) {
            soldCounts.four++;
        } else if (_length == 5) {
            soldCounts.five++;
        } else if (_length >= 6) {
            soldCounts.sixOrMore++;
        } else {
            revert("ZERO_CHARACTERS");
        }
    }

    // Return total number of names sold
    function totalNamesSold() public view returns (uint256) {
        return (
            soldCounts.one + soldCounts.two + soldCounts.three + soldCounts.four + soldCounts.five
                + soldCounts.sixOrMore
        );
    }

    /*//////////////////////////////////////////////////////////////
                      PRIMARY NAME SERVICE LOGIC
    //////////////////////////////////////////////////////////////*/

    // Set primary name, only callable by owner
    function ownerSetPrimary(string memory _name) public override onlyNameOwner(_name) notDelegated(_name) {
        uint256 id = nameToID(_name);
        primaryName[msg.sender] = id;
        emit Primary(msg.sender, id);
    }

    // Set primary name, only callable by delegate
    function delegateSetPrimary(string memory _name) public override onlyDelegate(_name) {
        uint256 id = nameToID(_name);
        primaryName[msg.sender] = id;
        emit Primary(msg.sender, id);
    }

    // Clear primary name
    function clearPrimary() public override {
        primaryName[msg.sender] = 0;
        emit NoPrimary(msg.sender);
    }

    // Return address' primary name
    function getPrimary(address _target) external view override returns (string memory) {
        uint256 id = primaryName[_target];
        return nameRegistry[id].name;
    }

    // Return name owner address
    function getOwner(string memory _name) external view override returns (address) {
        uint256 id = nameToID(_name);
        return ownerOf(id);
    }

    /*//////////////////////////////////////////////////////////////
                   INTERNAL MINT/REGISTER/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    // Mint logic
    function _mint(string memory _name) internal {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        // Set name ownership
        _nameOwner[id] = msg.sender;
        // Instantiate name data / URI(?)
        nameRegistry[id].name = _name;
    }

    // Registration logic
    function _register(
        string memory _name,
        uint256 _term
    ) internal {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 expiry = block.timestamp + (_term * 365 days);
        address owner = msg.sender; // For cleanliness
        // Calculate name character length
        uint256 length = stringLength(_name);

        // Require real address and name availability
        require(owner != address(0), "ZERO_ADDRESS");
        require(nameRegistry[id].expiry < block.timestamp, "NOT_AVAILABLE");

        // If no owner, register
        if (_nameOwner[id] == address(0)) {
            // Increase owner's name count by 1
            // Counter overflow is incredibly unrealistic.
            unchecked {
                _balanceOf[owner]++;
            }

            // Mint name
            _mint(_name);
        }
        // Else, clear name and transfer from owner
        else {
            // Clears ancillary data
            _clearName(id);
            // If owner or delegate (if any) set as primary name, remove it
            if (primaryName[msg.sender] == id || primaryName[nameRegistry[id].delegate] == id) {
                clearPrimary();
            }
            // Setting approval allows new owner to call safeTransferFrom()
            approvals[id] = owner;
            safeTransferFrom(ownerOf(id), msg.sender, id);
        }

        // Update expiry
        nameRegistry[id].expiry = expiry;
        // Update counts
        _incrementCounts(length);

        emit Register(owner, id, expiry);
    }

    // Burn logic
    function _burn(string memory _name) internal {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        address owner = ownerOf(id); // For cleanliness

        // Ownership check ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        // Erase all name data
        delete approvals[id];
        delete _nameOwner[id];
        _eraseName(id);

        emit Burn(owner, id);
    }

    /*//////////////////////////////////////////////////////////////
                      ALLOWLISTED REGISTER LOGIC
    //////////////////////////////////////////////////////////////*/

    // Validate reservation information
    function validateReservation(uint256 id) internal view {
        // Confirm privileged assignment
        require(nameReserver[id] == msg.sender, "NOT_RESERVER");
        require(nameReservation[msg.sender] == id, "NOT_RESERVATION");
    }

    // Use reservation and process allowlist changes
    function burnReservation(uint256 id) internal {
        delete nameReservation[msg.sender];
        delete nameReserver[id];
        delete reservationExpiry[msg.sender];
        reservationUsed[msg.sender] = true;
    }

    // Process reservation registration
    function reservedRegister(
        string memory _name,
        uint256 _term
    ) public override payable reservationValid {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        
        // Validate reservation
        validateReservation(id);

        // ****************** IMPLEMENT ALLOWLIST BENEFITS HERE ************************
        // REMOVE PAYABLE MODIFIER IF UNNEEDED

        // Call registration logic
        _register(_name, _term);

        // Use registration and remove from allowlist
        burnReservation(id);
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC SAFE REGISTER/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    // Process all safety checks before registration
    function safeRegister(
        string memory _name,
        uint256 _term
    ) public override payable notReserved(_name) {
        // Calculate name ID and string length
        uint256 id = nameToID(_name);
        uint256 length = stringLength(_name);
        require(length > 0, "MISSING_NAME");

        // Calculate price
        uint256 price = priceName(length);
        // Require msg.value meets or exceeds price
        require(msg.value >= (price * _term), "INSUFFICIENT_FUNDS");

        // Register name
        _register(_name, _term);

        // Log overpayment as tip
        if (msg.value > price) {
            emit Tip(msg.sender, id, msg.value - price);
        }

        // Confirm recipient can receive
        require(
            msg.sender.code.length == 0
                || ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), id, "")
                    == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    // Process all safety checks before registration
    function safeRegister(
        string memory _name,
        uint256 _term,
        bytes memory _data
    ) public override payable notReserved(_name) {
        // Calculate name ID and string length
        uint256 id = nameToID(_name);
        uint256 length = stringLength(_name);
        require(length > 0, "MISSING_NAME");

        // Calculate price
        uint256 price = priceName(length);
        // Require msg.value meets or exceeds price
        require(msg.value >= (price * _term), "INSUFFICIENT_FUNDS");

        // Register name
        _register(_name, _term);

        // Log overpayment as tip
        if (msg.value > price) {
            emit Tip(msg.sender, id, msg.value - price);
        }

        // Confirm recipient can receive
        require(
            msg.sender.code.length == 0
                || ERC721TokenReceiver(msg.sender).onERC721Received(msg.sender, address(0), id, _data)
                    == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    // Impose ownership and delegation checks before allowing burn
    function safeBurn(string memory _name) public override onlyNameOwner(_name) notDelegated(_name) {
        _burn(_name);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal transfer logic
    function _transfer(
        uint256 _id,
        address _recipient
    ) internal {
        // Clear out ancillary name data
        _clearName(_id);
        // If owner or delegate (if any) set as primary name, remove it
        if (primaryName[msg.sender] == _id || primaryName[nameRegistry[_id].delegate] == _id) {
            clearPrimary();
        }
        safeTransferFrom(msg.sender, _recipient, _id);
    }

    // Callable transfer function
    // So far, the only thing needed for transfer is clearing ancillary name data and no delegation
    function transferName(
        string memory _name,
        address _recipient
    ) public onlyNameOwner(_name) notDelegated(_name) {
        uint256 id = nameToID(_name);
        _transfer(id, _recipient);
    }

    /*//////////////////////////////////////////////////////////////
                              RENEW LOGIC
    //////////////////////////////////////////////////////////////*/

    // Internal renewal logic
    function _renew(uint256 _id, uint256 _term) internal {
        // Calculate new expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 renewalTime = (_term * 365 days);
        // Extend expiry by renewalTime
        nameRegistry[_id].expiry += renewalTime;

        emit Renew(msg.sender, _id, nameRegistry[_id].expiry);
    }

    // Process renewal by extending expiry
    function renewName(
        string memory _name,
        uint256 _term
    ) public payable override onlyNameOwner(_name) {
        // Generate name ID
        uint256 id = nameToID(_name);
        // Calculate name character length
        uint256 length = stringLength(_name);
        // Use name character length to calculate current price
        uint256 price = priceName(length);

        // Require msg.value meets or exceeds renewal cost
        require(msg.value >= (price * _term), "INSUFFICIENT_FUNDS");
        
        // Execute internal _renew logic
        _renew(id, _term);

        // Log overpayment as tip
        if (msg.value > price) {
            emit Tip(msg.sender, id, msg.value - price);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    // Delegate name utilization rights to another address
    function delegateName(
        string memory _name,
        address _delegate,
        uint256 _term
    ) public override onlyNameOwner(_name) notDelegated(_name) {
        // Calculate name ID
        uint256 id = nameToID(_name);

        // If primary name, remove it
        if (primaryName[msg.sender] == id) {
            clearPrimary();
        }

        // Assign delegate address to name
        nameRegistry[id].delegate = _delegate;

        // Calculate expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 expiry = block.timestamp + (_term * 365 days);

        // Save delegation expiry timestamp to registry storage
        nameRegistry[id].delegationExpiry = expiry;

        emit Delegate(_delegate, id, expiry);
    }

    // Extend name delegation
    function extendDelegation(
        string memory _name,
        uint256 _term
    ) public override onlyNameOwner(_name) {
        // Calculate name ID
        uint256 id = nameToID(_name);

        // Calculate new expiry timestamp
        // ********************** FIX THIS TO SUPPORT LEAP YEARS **************************
        uint256 renewalTime = (_term * 365 days);
        // Extend delegation expiry by renewalTime
        nameRegistry[id].delegationExpiry += renewalTime;

        emit Extend(nameRegistry[id].delegate, id, nameRegistry[id].delegationExpiry);
    }

    /*//////////////////////////////////////////////////////////////
                          PAYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Payment handling functions if we need them
    // Currently allows withdrawal to any owner
    function withdraw() public onlyContractOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
        emit Withdraw(msg.sender, address(this).balance);
    }

    receive() external payable {}
    fallback() external payable {}
}