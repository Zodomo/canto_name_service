// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {wadExp, wadLn, wadMul, unsafeWadMul, unsafeWadDiv, toWadUnsafe, toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

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
    // Tracks whether VRGDA has been initialized to prevent multiple initialization calls
    bool initialized;
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

  /// @notice Constructor nuked in favor of initialize() function, will be called in CantoNameService constructor
  /* /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
  /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
  /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18. */
  constructor() { }

  // Sets up each of the VRGDA storage structs individually
  function initialize(
    uint256 _VRGDA,
    int256 _targetPrice,
    int256 _priceDecayPercent,
    int256 _perTimeUnit
  ) {
    if (_VRGDA == 1) {
      require(vrgdaData.one.initialized == false, "VRGDA 1 already initialized");
      vrgdaData.one.targetPrice = _targetPrice;
      vrgdaData.one.priceDecayPercent = _priceDecayPercent;
      vrgdaData.one.decayConstant = wadLn(1e18 - _priceDecayPercent);
      vrgdaData.one.perTimeUnit = _perTimeUnit;
      vrgdaData.one.startTime = int256(block.timestamp);
      vrgdaData.one.initialized = true;
    }
    else if (_VRGDA == 2) {
      require(vrgdaData.two.initialized == false, "VRGDA 2 already initialized");
      vrgdaData.two.targetPrice = _targetPrice;
      vrgdaData.two.priceDecayPercent = _priceDecayPercent;
      vrgdaData.two.decayConstant = wadLn(1e18 - _priceDecayPercent);
      vrgdaData.two.perTimeUnit = _perTimeUnit;
      vrgdaData.two.startTime = int256(block.timestamp);
      vrgdaData.two.initialized = true;
    }
    else if (_VRGDA == 3) {
      require(vrgdaData.three.initialized == false, "VRGDA 3 already initialized");
      vrgdaData.three.targetPrice = _targetPrice;
      vrgdaData.three.priceDecayPercent = _priceDecayPercent;
      vrgdaData.three.decayConstant = wadLn(1e18 - _priceDecayPercent);
      vrgdaData.three.perTimeUnit = _perTimeUnit;
      vrgdaData.three.startTime = int256(block.timestamp);
      vrgdaData.three.initialized = true;
    }
    else if (_VRGDA == 4) {
      require(vrgdaData.four.initialized == false, "VRGDA 4 already initialized");
      vrgdaData.four.targetPrice = _targetPrice;
      vrgdaData.four.priceDecayPercent = _priceDecayPercent;
      vrgdaData.four.decayConstant = wadLn(1e18 - _priceDecayPercent);
      vrgdaData.four.perTimeUnit = _perTimeUnit;
      vrgdaData.four.startTime = int256(block.timestamp);
      vrgdaData.four.initialized = true;
    }
    else if (_VRGDA == 5) {
      require(vrgdaData.four.initialized == false, "VRGDA 5 already initialized");
      vrgdaData.five.targetPrice = _targetPrice;
      vrgdaData.five.priceDecayPercent = _priceDecayPercent;
      vrgdaData.five.decayConstant = wadLn(1e18 - _priceDecayPercent);
      vrgdaData.five.perTimeUnit = _perTimeUnit;
      vrgdaData.five.startTime = int256(block.timestamp);
      vrgdaData.five.initialized = true;
    }
    else {
      revert("Zero or >five characters not applicable to VRGDA emissions");
    }
  }

  /*//////////////////////////////////////////////////////////////
                            PRICING LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Calculate the price of a token according to the VRGDA formula.
  /// @param timeSinceStart Time passed since the VRGDA began, scaled by 1e18.
  /// @param sold The total number of tokens that have been sold so far.
  /// @return The price of a token according to VRGDA, scaled by 1e18.
  function getVRGDAPrice(uint _vrgda, uint256 _sold) public payable returns (uint256) {

    // Temporary VRGDA Data storage for specific name length
    int256 targetPrice;
    int256 decayConstant;
    int256 timeSinceStart;
    int256 perTimeUnit;

    if (_vrgda == 1) {
      targetPrice = vrgdaData.one.targetPrice;
      decayConstant = vrgdaData.one.decayConstant;
      timeSinceStart = int256(block.timestamp) - vrgdaData.one.startTime;
      perTimeUnit = vrgdaData.one.perTimeUnit;
    }
    else if (_vrgda == 2) {
      targetPrice = vrgdaData.two.targetPrice;
      decayConstant = vrgdaData.two.decayConstant;
      timeSinceStart = int256(block.timestamp) - vrgdaData.two.startTime;
      perTimeUnit = vrgdaData.two.perTimeUnit;
    }
    else if (_vrgda == 3) {
      targetPrice = vrgdaData.three.targetPrice;
      decayConstant = vrgdaData.three.decayConstant;
      timeSinceStart = int256(block.timestamp) - vrgdaData.three.startTime;
      perTimeUnit = vrgdaData.three.perTimeUnit;
    }
    else if (_vrgda == 4) {
      targetPrice = vrgdaData.four.targetPrice;
      decayConstant = vrgdaData.four.decayConstant;
      timeSinceStart = int256(block.timestamp) - vrgdaData.four.startTime;
      perTimeUnit = vrgdaData.four.perTimeUnit;
    }
    else if (_vrgda == 5) {
      targetPrice = vrgdaData.five.targetPrice;
      decayConstant = vrgdaData.five.decayConstant;
      timeSinceStart = int256(block.timestamp) - vrgdaData.five.startTime;
      perTimeUnit = vrgdaData.five.perTimeUnit;
    }
    else {
      revert ("Zero or >five characters not applicable to VRGDA emissions");
    }
    unchecked {
      return uint256(wadMul(targetPrice, wadExp(unsafeWadMul(decayConstant,
        // Theoretically calling toWadUnsafe with sold can silently overflow but under
        // any reasonable circumstance it will never be large enough. We use sold + 1 as
        // the VRGDA formula's n param represents the nth token and sold is the n-1th token.
        timeSinceStart - getTargetSaleTime(toWadUnsafe(_sold + 1), perTimeUnit)
      ))));
    }
  }

  /// @dev Given a number of tokens sold, return the target time that number of tokens should be sold by.
  /// @param sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for.
  /// @return The target time the tokens should be sold by, scaled by 1e18, where the time is
  /// relative, such that 0 means the tokens should be sold immediately when the VRGDA begins.
  function getTargetSaleTime(int256 _sold, int256 _perTimeUnit) public view returns (int256) {
    return unsafeWadDiv(_sold, _perTimeUnit);
  }
}