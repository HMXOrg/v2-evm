// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "../base/Owned.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";
import {OracleAdapterInterface} from "../interfaces/OracleAdapterInterface.sol";

contract PythAdapter is Owned, OracleAdapterInterface {
  // state variables
  IPyth public pyth;
  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => bytes32) public pythPriceIdOf;

  // events
  event SetPythPriceId(
    bytes32 indexed assetId, bytes32 prevPythPriceId, bytes32 pythPriceId
  );

  constructor(IPyth _pyth) {
    pyth = _pyth;
  }

  /// @notice Set the Pyth price id for the given asset.
  /// @param assetId The asset address to set.
  /// @param pythPriceId The Pyth price id to set.
  function setPythPriceId(bytes32 assetId, bytes32 pythPriceId)
    external
    onlyOwner
  {
    emit SetPythPriceId(assetId, pythPriceIdOf[assetId], pythPriceId);
    pythPriceIdOf[assetId] = pythPriceId;
  }

  /// @notice convert Pyth's price to uint256.
  /// @dev This is taken from https://github.com/pyth-network/pyth-crosschain/blob/main/target_chains/ethereum/examples/oracle_swap/contract/src/OracleSwap.sol#L92
  /// @param price The Pyth price to convert.
  /// @param targetDecimals The target decimals to convert to.
  function convertToUint(PythStructs.Price memory price, uint8 targetDecimals)
    private
    pure
    returns (uint256)
  {
    if (price.price < 0 || price.expo > 0 || price.expo < -255) {
      revert();
    }

    uint8 priceDecimals = uint8(uint32(-1 * price.expo));

    if (targetDecimals - priceDecimals >= 0) {
      return uint256(uint64(price.price))
        * 10 ** uint32(targetDecimals - priceDecimals);
    } else {
      return uint256(uint64(price.price))
        / 10 ** uint32(priceDecimals - targetDecimals);
    }
  }

  /// @notice Get the latest price of the given asset. Returned price is in 30 decimals.
  /// @param assetId The asset id to get price.
  function getLatestPrice(bytes32 assetId)
    external
    view
    returns (uint256, uint256)
  {
    PythStructs.Price memory price = pyth.getPrice(pythPriceIdOf[assetId]);

    return (convertToUint(price, 30), price.publishTime);
  }
}
