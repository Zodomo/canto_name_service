// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    wadExp,
    wadLn,
    wadMul,
    unsafeWadMul,
    unsafeWadDiv,
    toWadUnsafe,
    toDaysWadUnsafe
} from "solmate/utils/SignedWadMath.sol";

// The below VRGDA contract is designed to sell tokens, but we will use it to sell names
// Heavily modified version of LinearVRGDA from transmissions11 to allow for concurrent VRGDAs
// Removed abstract declaration

/// @title Variable Rate Gradual Dutch Auction
/// @author transmissions11 <t11s@paradigm.xyz>
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @author Zodomo <zodomo@proton.me>
/// @notice Sell tokens roughly according to an issuance schedule.
contract LinearVRGDA {
    /*//////////////////////////////////////////////////////////////
                          VRGDA PARAMETERS
    //////////////////////////////////////////////////////////////*/

    // All values in VRGDA represent 18 decimal fixed point number
    struct VRGDA {
        // Target price for a tokenamen, to be scaled according to sales pace.
        int256 targetPrice;
        // Percentage price decays per unit of time with no sales, scaled by 1e18.
        int256 priceDecayPercent;
        // Precomputed constant that allows us to rewrite a pow() as an exp().
        int256 decayConstant;
        // The total number of tokens to target selling every full unit of time.
        int256 perTimeUnit;
        // Block timestamp VRGDA initialized in
        int256 startTime;
    }

    // VRGDA struct name corresponds with how many characters in name length
    struct vrgdaData {
        VRGDA one;
        VRGDA two;
        VRGDA three;
        VRGDA four;
        VRGDA five;
    }

    vrgdaData public VRGDAData;

    // Stores VRGDA init data for batch initialization
    struct vrgdaBatchData {
        int256 oneTargetPrice;
        int256 twoTargetPrice;
        int256 threeTargetPrice;
        int256 fourTargetPrice;
        int256 fiveTargetPrice;
        int256 onePriceDecayPercent;
        int256 twoPriceDecayPercent;
        int256 threePriceDecayPercent;
        int256 fourPriceDecayPercent;
        int256 fivePriceDecayPercent;
        int256 onePerTimeUnit;
        int256 twoPerTimeUnit;
        int256 threePerTimeUnit;
        // int256 fourPerTimeUnit;
        // int256 fivePerTimeUnit;
        bool batchInitialized;
    }

    vrgdaBatchData public vrgdaBatch;

    /// @notice Constructor nuked in favor of initialize() function, will be called in CantoNameService constructor
    /* /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
    /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
    /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18. */
    constructor() {}

    // Sets up each of the VRGDA storage structs individually
    function initialize(uint256 _VRGDA, int256 _targetPrice, int256 _priceDecayPercent, int256 _perTimeUnit) internal {
        if (_VRGDA == 1) {
            VRGDAData.one.targetPrice = _targetPrice;
            VRGDAData.one.priceDecayPercent = _priceDecayPercent;
            VRGDAData.one.decayConstant = wadLn(1e18 - _priceDecayPercent);
            VRGDAData.one.perTimeUnit = _perTimeUnit;
            VRGDAData.one.startTime = int256(block.timestamp);
        } else if (_VRGDA == 2) {
            VRGDAData.two.targetPrice = _targetPrice;
            VRGDAData.two.priceDecayPercent = _priceDecayPercent;
            VRGDAData.two.decayConstant = wadLn(1e18 - _priceDecayPercent);
            VRGDAData.two.perTimeUnit = _perTimeUnit;
            VRGDAData.two.startTime = int256(block.timestamp);
        } else if (_VRGDA == 3) {
            VRGDAData.three.targetPrice = _targetPrice;
            VRGDAData.three.priceDecayPercent = _priceDecayPercent;
            VRGDAData.three.decayConstant = wadLn(1e18 - _priceDecayPercent);
            VRGDAData.three.perTimeUnit = _perTimeUnit;
            VRGDAData.three.startTime = int256(block.timestamp);
            // } else if (_VRGDA == 4) {
            //     VRGDAData.four.targetPrice = _targetPrice;
            //     VRGDAData.four.priceDecayPercent = _priceDecayPercent;
            //     VRGDAData.four.decayConstant = wadLn(1e18 - _priceDecayPercent);
            //     VRGDAData.four.perTimeUnit = _perTimeUnit;
            //     VRGDAData.four.startTime = int256(block.timestamp);
            // } else if (_VRGDA == 5) {
            //     VRGDAData.five.targetPrice = _targetPrice;
            //     VRGDAData.five.priceDecayPercent = _priceDecayPercent;
            //     VRGDAData.five.decayConstant = wadLn(1e18 - _priceDecayPercent);
            //     VRGDAData.five.perTimeUnit = _perTimeUnit;
            //     VRGDAData.five.startTime = int256(block.timestamp);
        } else {
            revert("Zero or >five characters not applicable to VRGDA emissions");
        }
    }

    function batchInitialize() internal {
        require(vrgdaBatch.batchInitialized == false, "VRGDA batch already initialized");
        initialize(1, vrgdaBatch.oneTargetPrice, vrgdaBatch.onePriceDecayPercent, vrgdaBatch.onePerTimeUnit);
        initialize(2, vrgdaBatch.twoTargetPrice, vrgdaBatch.twoPriceDecayPercent, vrgdaBatch.twoPerTimeUnit);
        initialize(3, vrgdaBatch.threeTargetPrice, vrgdaBatch.threePriceDecayPercent, vrgdaBatch.threePerTimeUnit);
        // initialize(4, vrgdaBatch.fourTargetPrice, vrgdaBatch.fourPriceDecayPercent, vrgdaBatch.fourPerTimeUnit);
        // initialize(5, vrgdaBatch.fiveTargetPrice, vrgdaBatch.fivePriceDecayPercent, vrgdaBatch.fivePerTimeUnit);
        vrgdaBatch.batchInitialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                            PRICING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate the price of a token according to the VRGDA formula.
    /// @param _sold The total number of tokens that have been sold so far.
    /// @return The price of a token according to VRGDA, scaled by 1e18.
    function getVRGDAPrice(uint256 _vrgda, uint256 _sold) public payable returns (uint256) {
        // Temporary VRGDA Data storage for specific name length
        int256 targetPrice;
        int256 decayConstant;
        int256 timeSinceStart;
        int256 perTimeUnit;

        if (_vrgda == 1) {
            targetPrice = VRGDAData.one.targetPrice;
            decayConstant = VRGDAData.one.decayConstant;
            timeSinceStart = int256(block.timestamp) - VRGDAData.one.startTime;
            perTimeUnit = VRGDAData.one.perTimeUnit;
        } else if (_vrgda == 2) {
            targetPrice = VRGDAData.two.targetPrice;
            decayConstant = VRGDAData.two.decayConstant;
            timeSinceStart = int256(block.timestamp) - VRGDAData.two.startTime;
            perTimeUnit = VRGDAData.two.perTimeUnit;
        } else if (_vrgda == 3) {
            targetPrice = VRGDAData.three.targetPrice;
            decayConstant = VRGDAData.three.decayConstant;
            timeSinceStart = int256(block.timestamp) - VRGDAData.three.startTime;
            perTimeUnit = VRGDAData.three.perTimeUnit;
        } else if (_vrgda == 4) {
            targetPrice = VRGDAData.four.targetPrice;
            decayConstant = VRGDAData.four.decayConstant;
            timeSinceStart = int256(block.timestamp) - VRGDAData.four.startTime;
            perTimeUnit = VRGDAData.four.perTimeUnit;
        } else if (_vrgda == 5) {
            targetPrice = VRGDAData.five.targetPrice;
            decayConstant = VRGDAData.five.decayConstant;
            timeSinceStart = int256(block.timestamp) - VRGDAData.five.startTime;
            perTimeUnit = VRGDAData.five.perTimeUnit;
        } else {
            revert("Zero or >five characters not applicable to VRGDA emissions");
        }
        unchecked {
            return uint256(
                wadMul(
                    targetPrice,
                    wadExp(
                        unsafeWadMul(
                            decayConstant,
                            // Theoretically calling toWadUnsafe with sold can silently overflow but under
                            // any reasonable circumstance it will never be large enough. We use sold + 1 as
                            // the VRGDA formula's n param represents the nth token and sold is the n-1th token.
                            timeSinceStart - getTargetSaleTime(toWadUnsafe(_sold + 1), perTimeUnit)
                        )
                    )
                )
            );
        }
    }

    /// @dev Given a number of tokens sold, return the target time that number of tokens should be sold by.
    /// @param _sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for.
    /// @return The target time the tokens should be sold by, scaled by 1e18, where the time is
    /// relative, such that 0 means the tokens should be sold immediately when the VRGDA begins.
    function getTargetSaleTime(int256 _sold, int256 _perTimeUnit) public pure returns (int256) {
        return unsafeWadDiv(_sold, _perTimeUnit);
    }
}
