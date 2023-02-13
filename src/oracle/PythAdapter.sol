// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Owned } from "../base/Owned.sol";
import { IPyth } from "pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "pyth-sdk-solidity/PythStructs.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";

contract PythAdapter is Owned, IOracleAdapter {
  // errors
  error PythAdapter_BrokenPythPrice();
  error PythAdapter_ConfidenceRatioTooHigh();

  // state variables
  IPyth public pyth;
  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => bytes32) public pythPriceIdOf;

  // events
  event SetPythPriceId(
    bytes32 indexed assetId,
    bytes32 prevPythPriceId,
    bytes32 pythPriceId
  );

  constructor(IPyth _pyth) {
    pyth = _pyth;
  }

  /// @notice Set the Pyth price id for the given asset.
  /// @param assetId The asset address to set.
  /// @param pythPriceId The Pyth price id to set.
  function setPythPriceId(
    bytes32 assetId,
    bytes32 pythPriceId
  ) external onlyOwner {
    emit SetPythPriceId(assetId, pythPriceIdOf[assetId], pythPriceId);
    pythPriceIdOf[assetId] = pythPriceId;
  }

  /// @notice convert Pyth's price to uint256.
  /// @dev This is partially taken from https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/examples/oracle_swap/contract/src/OracleSwap.sol#L92
  /// @param priceStruct The Pyth's price struct to convert.
  /// @param isMax Whether to use the max price or min price.
  /// @param targetDecimals The target decimals to convert to.
  function convertToUint256(
    PythStructs.Price memory priceStruct,
    bool isMax,
    uint8 targetDecimals
  ) private pure returns (uint256) {
    // TODO: when market close, price is 0, how to handle?
    if (
      priceStruct.price <= 0 || priceStruct.expo > 0 || priceStruct.expo < -255
    ) {
      revert PythAdapter_BrokenPythPrice();
    }

    uint8 priceDecimals = uint8(uint32(-1 * priceStruct.expo));
    uint64 price = isMax
      ? uint64(priceStruct.price) + priceStruct.conf
      : uint64(priceStruct.price) - priceStruct.conf;

    if (targetDecimals - priceDecimals >= 0) {
      return uint256(price) * 10 ** uint32(targetDecimals - priceDecimals);
    } else {
      return uint256(price) / 10 ** uint32(priceDecimals - targetDecimals);
    }
  }

  /// @notice Validate Pyth's confidence with given threshold. Revert if confidence ratio is too high.
  /// @dev To bypass the confidence check, the user can submit threshold = 1 ether
  /// @param priceStruct The Pyth's price struct to convert.
  /// @param confidenceThreshold The acceptable threshold confidence ratio. ex. confidenceRatio = 0.01 ether means 1%
  function validateConfidence(
    PythStructs.Price memory priceStruct,
    uint256 confidenceThreshold
  ) private pure {
    if (priceStruct.price < 0) {
      revert PythAdapter_BrokenPythPrice();
    }

    // Calculate confidenceRatio in 1e18 base.
    uint256 confidenceRatio = (priceStruct.conf * uint64(1e18)) /
      uint64(priceStruct.price);

    // Revert if confidence ratio is too high
    if (confidenceRatio > confidenceThreshold)
      revert PythAdapter_ConfidenceRatioTooHigh();
  }

  /// @notice Get the latest price of the given asset. Returned price is in 30 decimals.
  /// @dev The price returns here can be staled.
  /// @param assetId The asset id to get price.
  /// @param isMax Whether to get the max price.
  function getLatestPrice(
    bytes32 assetId,
    bool isMax,
    uint256 confidenceThreshold
  ) external view returns (uint256, uint256) {
    PythStructs.Price memory price = pyth.getPriceUnsafe(
      pythPriceIdOf[assetId]
    );

    validateConfidence(price, confidenceThreshold);
    return (convertToUint256(price, isMax, 30), price.publishTime);
  }
}
