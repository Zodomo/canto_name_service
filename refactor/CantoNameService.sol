// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICNS.sol";
import "./ERC721.sol";
import "./LinearVRGDA.sol";
import "./Allowlist.sol";

contract CantoNameService is ICNS, ERC721("Canto Name Service", "CNS"), LinearVRGDA, Allowlist {

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
}
