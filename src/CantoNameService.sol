// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICNS.sol";
import "./ERC721.sol";
import "./LinearVRGDA.sol";

contract CantoNameService is ICNS, ERC721("Canto Name Service", "CNS"), LinearVRGDA {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    // Announce new contract owner added
    event Owner(address indexed caller, address indexed owner);
    // Announce when contract owner withdraws
    event Withdraw(address indexed owner, uint256 indexed value);

    // Announce name registration
    event Register(address indexed registrant, uint256 indexed id, uint256 indexed expiry);
    // Announce primary name set
    event Primary(address indexed owner, uint256 indexed id);
    // Announce primary name cleared
    event NoPrimary(address indexed sender);
    // Announce name delegation
    event Delegate(address indexed delegate, uint256 indexed id, uint256 indexed expiry);
    // Announce name burn, store both name and derived ID
    event Burn(address indexed owner, uint256 indexed id);
    // Announce registration overpayment as tip
    event Tip(address indexed sender, uint256 indexed id, uint256 indexed tip);

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
        require(nameOwner[id] != address(0), "NOT_OWNED");
        require(nameRegistry[id].expiry > block.timestamp, "NAME_EXPIRED");
        require(ownerOf(id) == msg.sender, "NOT_NAME_OWNER");
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

    function addContractOwner(address _owner) public onlyContractOwner {
        owners[payable(_owner)] = true;
        emit Owner(msg.sender, _owner);
    }

    /*//////////////////////////////////////////////////////////////
                          VRDGA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    // Initialize a single VRGDA
    // Can only be performed after batch initialization
    function vrgdaInitialize(uint256 _VRGDA, int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit)
        public
        onlyContractOwner
    {
        require(vrgdaBatch.batchInitialized == true, "VRGDA_BATCH_INIT");
        initialize(_VRGDA, _targetPrice, _priceDecayPercent, _perTimeUnit);
    }

    // Prep VRGDA data for batch initialization
    function prepBatchInitialize(uint256 _VRGDA, int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit)
        public
        onlyContractOwner
    {
        if (_VRGDA == 1) {
            vrgdaBatch.oneTargetPrice = _targetPrice;
            vrgdaBatch.onePriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.onePerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 2) {
            vrgdaBatch.twoTargetPrice = _targetPrice;
            vrgdaBatch.twoPriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.twoPerTimeUnit = _perTimeUnit;
        } else if (_VRGDA == 3) {
            vrgdaBatch.threeTargetPrice = _targetPrice;
            vrgdaBatch.threePriceDecayPercent = _priceDecayPercent;
            vrgdaBatch.threePerTimeUnit = _perTimeUnit;
            // } else if (_VRGDA == 4) {
            //     vrgdaBatch.fourTargetPrice = _targetPrice;
            //     vrgdaBatch.fourPriceDecayPercent = _priceDecayPercent;
            //     vrgdaBatch.fourPerTimeUnit = _perTimeUnit;
            // } else if (_VRGDA == 5) {
            //     vrgdaBatch.fiveTargetPrice = _targetPrice;
            //     vrgdaBatch.fivePriceDecayPercent = _priceDecayPercent;
            //     vrgdaBatch.fivePerTimeUnit = _perTimeUnit;
        } else {
            revert("Zero or >five characters not applicable to VRGDA emissions");
        }
    }

    // Initialize all VRGDAs
    // Can only be called once
    // Must be called before individual VRGDAs can be reinitialized
    function vrgdaBatchInitialize() public onlyContractOwner {
        // Check to make sure all batch init data is supplied
        // Identify which VRGDA has missing data
        require(
            vrgdaBatch.oneTargetPrice > 0 && vrgdaBatch.onePriceDecayPercent > 0 && vrgdaBatch.onePerTimeUnit > 0,
            "VRGDA_ONE_MISSING_DATA"
        );
        require(
            vrgdaBatch.twoTargetPrice > 0 && vrgdaBatch.twoPriceDecayPercent > 0 && vrgdaBatch.twoPerTimeUnit > 0,
            "VRGDA_TWO_MISSING_DATA"
        );
        require(
            vrgdaBatch.threeTargetPrice > 0 && vrgdaBatch.threePriceDecayPercent > 0 && vrgdaBatch.threePerTimeUnit > 0,
            "VRGDA_THREE_MISSING_DATA"
        );
        // require(
        //     vrgdaBatch.fourTargetPrice > 0 && vrgdaBatch.fourPriceDecayPercent > 0 && vrgdaBatch.fourPerTimeUnit > 0,
        //     "VRGDA_FOUR_MISSING_DATA"
        // );
        // require(
        //     vrgdaBatch.fiveTargetPrice > 0 && vrgdaBatch.fivePriceDecayPercent > 0 && vrgdaBatch.fivePerTimeUnit > 0,
        //     "VRGDA_FIVE_MISSING_DATA"
        // );

        // After all checks, batch initialize
        batchInitialize();
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL/LIBRARY LOGIC
    //////////////////////////////////////////////////////////////*/

    // Converts string name to uint256 ID
    function nameToID(string memory _name) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(_name))));
    }

    // Clear unnecessary information from previous owner
    function clearName(uint256 id) internal {
        nameRegistry[id].delegate = address(0);
        nameRegistry[id].delegationExpiry = 0;
    }

    // Erase all name data for burn
    function eraseName(uint256 id) internal {
        nameRegistry[id].name = "";
        nameRegistry[id].expiry = 0;
        nameRegistry[id].delegate = address(0);
        nameRegistry[id].delegationExpiry = 0;
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
    function priceName(uint256 _length) internal returns (uint256) {
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
    function incrementCounts(uint256 _length) internal {
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
    function setPrimary(string memory _name) public onlyNameOwner(_name) {
        uint256 id = nameToID(_name);
        primaryName[msg.sender] = id;
        emit Primary(msg.sender, id);
    }

    // Clear primary name
    function clearPrimary() public {
        primaryName[msg.sender] = 0;
        emit NoPrimary(msg.sender);
    }

    function getPrimary(address _address) public view returns (string memory) {
        uint256 id = primaryName[_address];
        return nameRegistry[id].name;
    }

    function getOwner(string memory _name) public view returns (address owner) {
        uint256 id = nameToID(_name);
        return ownerOf(id);
    }

    /*//////////////////////////////////////////////////////////////
                   INTERNAL MINT/REGISTER/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(string memory _name) internal {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        // Set name ownership
        nameOwner[id] = msg.sender;
        // Instantiate name data / URI(?)
        nameRegistry[id].name = _name;
    }

    function _register(string memory _name, uint256 _term) internal {
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
        if (nameOwner[id] == address(0)) {
            // Increase owner's name count by 1
            // Counter overflow is incredibly unrealistic.
            unchecked {
                _balanceOf[owner]++;
            }

            // Mint name
            _mint(_name);
        }
        // Else, transfer from owner
        else {
            clearName(id);
            safeTransferFrom(ownerOf(id), msg.sender, id);
        }

        // Update expiry
        nameRegistry[id].expiry = expiry;
        // Update counts
        incrementCounts(length);

        emit Register(owner, id, expiry);
    }

    function _burn(string memory _name) internal {
        // Convert name string to uint256 id
        uint256 id = nameToID(_name);
        address owner = ownerOf(id); // For cleanliness

        // Make sure name is owned
        require(owner != address(0), "NOT_MINTED");

        // Ownership check ensures no underflow.
        unchecked {
            _balanceOf[owner]--;
        }

        // Erase all name data
        delete approvals[id];
        delete nameOwner[id];
        eraseName(id);

        emit Burn(owner, id);
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC SAFE REGISTER/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function safeRegister(string memory _name, uint256 _term) external payable {
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

    function safeRegister(string memory _name, uint256 _term, bytes memory _data) external payable {
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

    function safeBurn(string memory _name) public onlyNameOwner(_name) {
        _burn(_name);
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
