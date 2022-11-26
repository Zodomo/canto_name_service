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

// Used to report what batch data is missing during batch initialization
error MissingBatchData(uint256 vrgda, bool targetPrice, bool priceDecayPercent, bool perTimeUnit);

/// @title Variable Rate Gradual Dutch Auction
/// @notice Sell tokens roughly according to an issuance schedule.
contract LinearVRGDA {
    /*//////////////////////////////////////////////////////////////
                VRGDA STORAGE
    //////////////////////////////////////////////////////////////*/

    event Initialized(uint256 indexed vrgda, uint256 indexed timestamp);

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
    // Mapping tracks each VRGDA struct via uint256 length
    mapping(uint256 => VRGDA) private vrgdaData;

    // Used to pre-stage data for batch initializing VRGDA structs
    struct batchData {
        int256 targetPrice;
        int256 priceDecayPercent;
        int256 perTimeUnit;
    }
    // Mapping allows for dynamic access of all batch data for batch initialization
    mapping(uint256 => batchData) internal initData;

    // Tracks whether batch initialization has happened
    // Prevents resetting everything accidentally by only allowing batch initialization once
    bool internal batchInitialized;

    // Stores token sold counts for VRGDA math
    struct counts {
        uint256 current;
        uint256 total;
    }
    // Mapping tracks counts for each name length via uint256 length
    mapping(uint256 => counts) public tokenCounts;

    /*//////////////////////////////////////////////////////////////
                          VRGDA MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor nuked in favor of initialize() function, will be called in CantoNameService constructor
    /* /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
    /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
    /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18. */
    constructor() {}

    // Initializes an individual VRGDA (can also reinitialize)
    function _initialize(
        uint256 _VRGDA,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) internal {
        if (_VRGDA > 0 && _VRGDA < 6) {
            vrgdaData[_VRGDA].targetPrice = _targetPrice;
            vrgdaData[_VRGDA].priceDecayPercent = _priceDecayPercent;
            vrgdaData[_VRGDA].decayConstant = wadLn(1e18 - _priceDecayPercent);
            vrgdaData[_VRGDA].perTimeUnit = _perTimeUnit;
            vrgdaData[_VRGDA].startTime = int256(block.timestamp);
            tokenCounts[_VRGDA].current = 0;
            
            emit Initialized(_VRGDA, block.timestamp);
        } else {
            revert("LinearVRGDA::_initialize::INVALID_VRGDA");
        }
    }

    // Initializes all of the VRGDAs at once
    function _batchInitialize() internal {
        // Require batch initialization hasn't happened
        require(batchInitialized != true, "LinearVRGDA::_batchInitialize::BATCH_INITIALIZED");

        // Initialize all five VRGDAs
        for (uint i = 1; i < 6; i++) {
            _initialize(i,
                initData[i].targetPrice,
                initData[i].priceDecayPercent,
                initData[i].perTimeUnit);
        }

        // Set batchInitialized to prevent further calls
        batchInitialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                            PRICING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate the price of a token according to the VRGDA formula.
    /// @param _sold The total number of tokens that have been sold so far.
    /// @return The price of a token according to VRGDA, scaled by 1e18.
    function _getVRGDAPrice(uint256 _vrgda, uint256 _sold) internal view returns (uint256) {
        // Temporary VRGDA Data storage for specific name length
        int256 targetPrice;
        int256 decayConstant;
        int256 timeSinceStart;
        int256 perTimeUnit;

        if (_vrgda > 0 && _vrgda < 6) {
            targetPrice = vrgdaData[_vrgda].targetPrice;
            decayConstant = vrgdaData[_vrgda].decayConstant;
            timeSinceStart = int256(block.timestamp) - vrgdaData[_vrgda].startTime;
            perTimeUnit = vrgdaData[_vrgda].perTimeUnit;
        } else {
            revert("LinearVRGDA::_getVRGDAPrice::INVALID_VRGDA");
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
                            timeSinceStart - _getTargetSaleTime(toWadUnsafe(_sold + 1), perTimeUnit)
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
    function _getTargetSaleTime(int256 _sold, int256 _perTimeUnit) internal pure returns (int256) {
        return unsafeWadDiv(_sold, _perTimeUnit);
    }
}