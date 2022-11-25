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
}
