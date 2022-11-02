// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {wadExp, wadLn, wadMul, unsafeWadMul, unsafeWadDiv, toWadUnsafe, toDaysWadUnsafe} from "solmate/src/utils/SignedWadMath.sol";

// The below VRGDA contract is designed to sell tokens, but we will use it to sell names
// Removed abstract declaration

/// @title Variable Rate Gradual Dutch Auction
/// @author transmissions11 <t11s@paradigm.xyz>
/// @author FrankieIsLost <frankie@paradigm.xyz>
/// @notice Sell tokens roughly according to an issuance schedule.
contract LinearVRGDA {
  /*//////////////////////////////////////////////////////////////
                          VRGDA PARAMETERS
  //////////////////////////////////////////////////////////////*/

  /// @notice Target price for a token, to be scaled according to sales pace.
  /// @dev Represented as an 18 decimal fixed point number.
  int256 public targetPrice;

  /// @notice Percentage price decays per unit of time with no sales, scaled by 1e18.
  /// @dev Represented as an 18 decimal fixed point number.
  int256 public priceDecayPercent;

  /// @notice Precomputed constant that allows us to rewrite a pow() as an exp().
  /// @dev Represented as an 18 decimal fixed point number.
  int256 public decayConstant;

  /// @notice The total number of tokens to target selling every full unit of time.
  /// @dev Represented as an 18 decimal fixed point number.
  int256 public perTimeUnit;

  /// @notice Sets pricing parameters for the VRGDA
  /// @param _targetPrice The target price for a token if sold on pace, scaled by 1e18.
  /// @param _priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18.
  /// @param _perTimeUnit The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
  constructor(
    int256 _targetPrice,
    int256 _priceDecayPercent,
    int256 _perTimeUnit
  ) {
      targetPrice = _targetPrice;

      priceDecayPercent = _priceDecayPercent;

      decayConstant = wadLn(1e18 - _priceDecayPercent);

      perTimeUnit = _perTimeUnit;

      // The decay constant must be negative for VRGDAs to work.
      require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");
  }

  /*//////////////////////////////////////////////////////////////
                            PRICING LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Calculate the price of a token according to the VRGDA formula.
  /// @param timeSinceStart Time passed since the VRGDA began, scaled by 1e18.
  /// @param sold The total number of tokens that have been sold so far.
  /// @return The price of a token according to VRGDA, scaled by 1e18.
  function getVRGDAPrice(int256 timeSinceStart, uint256 sold) public payable returns (uint256) {
    unchecked {
      return uint256(wadMul(targetPrice, wadExp(unsafeWadMul(decayConstant,
        // Theoretically calling toWadUnsafe with sold can silently overflow but under
        // any reasonable circumstance it will never be large enough. We use sold + 1 as
        // the VRGDA formula's n param represents the nth token and sold is the n-1th token.
        timeSinceStart - getTargetSaleTime(toWadUnsafe(sold + 1))
      ))));
    }
  }

  /// @dev Given a number of tokens sold, return the target time that number of tokens should be sold by.
  /// @param sold A number of tokens sold, scaled by 1e18, to get the corresponding target sale time for.
  /// @return The target time the tokens should be sold by, scaled by 1e18, where the time is
  /// relative, such that 0 means the tokens should be sold immediately when the VRGDA begins.
  function getTargetSaleTime(int256 sold) public view returns (int256) {
    return unsafeWadDiv(sold, perTimeUnit);
  }
}