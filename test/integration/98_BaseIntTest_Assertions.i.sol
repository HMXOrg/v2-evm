// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { BaseIntTest_SetWhitelist } from "@hmx-test/integration/08_BaseIntTest_SetWhitelist.i.sol";

contract BaseIntTest_Assertions is BaseIntTest_SetWhitelist, StdAssertions {
  // Token Balances

  function assertTokenBalanceOf(address _account, address _token, uint256 _balance, string memory _str) internal {
    assertEq(
      ERC20(_token).balanceOf(address(_account)),
      _balance,
      string.concat(_str, "Trader's balance is not matched")
    );
  }

  function assertTokenBalanceOf(address _account, address _token, uint256 _balance) internal {
    assertTokenBalanceOf(_account, _token, _balance, "");
  }

  // PLP
  function assertPLPTotalSupply(uint256 _totalSupply, string memory _str) internal {
    assertEq(plpV2.totalSupply(), _totalSupply, string.concat(_str, "PLPv2 Total supply is not matched"));
  }

  function assertPLPTotalSupply(uint256 _totalSupply) internal {
    assertPLPTotalSupply(_totalSupply, "");
  }

  // Vault Storage

  function assertPLPDebt(uint256 _plpDebt, string memory _str) internal {
    assertEq(vaultStorage.plpLiquidityDebtUSDE30(), _plpDebt, string.concat(_str, "PLP liquidity debt is not matched"));
  }

  function assertPLPDebt(uint256 _plpDebt) internal {
    assertPLPDebt(_plpDebt, "");
  }

  function assertPLPLiquidity(address _token, uint256 _liquidity, string memory _str) internal {
    assertEq(vaultStorage.plpLiquidity(_token), _liquidity, string.concat(_str, "PLP token liquidity is not matched"));
  }

  function assertPLPLiquidity(address _token, uint256 _liquidity) internal {
    assertPLPLiquidity(_token, _liquidity, "");
  }

  function assertVaultTokenBalance(address _token, uint256 _balance, string memory _str) internal {
    assertEq(
      vaultStorage.totalAmount(_token),
      _balance,
      string.concat(_str, "Vault's Total amount of token is not matched")
    );
    assertEq(
      ERC20(_token).balanceOf(address(vaultStorage)),
      _balance,
      string.concat(_str, "Vault's token balance is not matched")
    );
  }

  function assertVaultTokenBalance(address _token, uint256 _balance) internal {
    assertVaultTokenBalance(_token, _balance, "");
  }

  function assertVaultsFees(
    address _token,
    uint256 _fee,
    uint256 _devFee,
    uint256 _fundingFee,
    string memory _str
  ) internal {
    assertEq(vaultStorage.protocolFees(_token), _fee, string.concat(_str, "Vault's Fee is not matched"));
    assertEq(vaultStorage.devFees(_token), _devFee, string.concat(_str, "Vault's Dev fee is not matched"));
    assertEq(vaultStorage.fundingFee(_token), _fundingFee, string.concat(_str, "Vault's Funding fee is not matched"));
  }

  function assertVaultsFees(address _token, uint256 _fee, uint256 _devFee, uint256 _fundingFee) internal {
    assertVaultsFees(_token, _fee, _devFee, _fundingFee, "");
  }

  function assertSubAccountTokenBalance(
    address _subAccount,
    address _token,
    bool _shouldExists,
    uint256 _balance,
    string memory _str
  ) internal {
    assertEq(
      vaultStorage.traderBalances(_subAccount, _token),
      _balance,
      string.concat(_str, "Trader's balance is not matched")
    );

    address[] memory _tokenAddresses = vaultStorage.getTraderTokens(_subAccount);
    uint256 _len = _tokenAddresses.length;
    bool _found = false;
    // Check token should exists in sub account's token
    for (uint256 _i; _i < _len; ) {
      if (_tokenAddresses[_i] == _token) {
        _found = true;
        break;
      }

      unchecked {
        ++_i;
      }
    }
    // normally if found token
    assertEq(
      _found,
      _shouldExists,
      string.concat(_str, _shouldExists ? "Token should exists" : "Token should not exists")
    );
  }

  function assertSubAccountTokenBalance(
    address _subAccount,
    address _token,
    bool _shouldExists,
    uint256 _balance
  ) internal {
    assertSubAccountTokenBalance(_subAccount, _token, _shouldExists, _balance, "");
  }

  // check all trader's token and balance
  function assertSubAccountTokensBalances(
    address _subAccount,
    address[] calldata _tokens,
    uint256[] calldata _balances,
    string memory _str
  ) internal {
    uint256 _len = _tokens.length;
    for (uint256 _i; _i < _len; ) {
      assertEq(
        vaultStorage.traderBalances(_subAccount, _tokens[_i]),
        _balances[_i],
        string.concat(vm.toString(_i), "Trader's balance")
      );

      unchecked {
        ++_i;
      }
    }

    assertEq(
      vaultStorage.getTraderTokens(_subAccount).length,
      _tokens.length,
      string.concat(_str, "Trader's token list length is not matched")
    );
  }

  function assertSubAccountTokensBalances(
    address _subAccount,
    address[] calldata _tokens,
    uint256[] calldata _balances
  ) internal {
    assertSubAccountTokensBalances(_subAccount, _tokens, _balances, "");
  }

  // Perp Storage

  function assertPositionInfoOf(
    address _subAccount,
    uint256 _marketIndex,
    int256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest,
    uint256 _reserveValue,
    int256 _realizedPnl,
    uint256 _entryBorrowingRate,
    int256 _entryFundingRate,
    string memory _str
  ) internal {
    bytes32 _positionId = keccak256(abi.encodePacked(_subAccount, _marketIndex));
    IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);

    assertEq(_position.positionSizeE30, _positionSize, string.concat(_str, "Position's size is not matched"));
    assertEq(_position.avgEntryPriceE30, _avgPrice, string.concat(_str, "Position's average price is not matched"));
    assertEq(_position.openInterest, _openInterest, string.concat(_str, "Position's open interest is not matched"));
    assertEq(_position.reserveValueE30, _reserveValue, string.concat(_str, "Position's reserve value is not matched"));
    assertEq(_position.realizedPnl, _realizedPnl, string.concat(_str, "Position's realized pnl is not matched"));
    assertEq(
      _position.entryBorrowingRate,
      _entryBorrowingRate,
      string.concat(_str, "Position's entry borrowing rate is not matched")
    );
    assertEq(
      _position.entryFundingRate,
      _entryFundingRate,
      string.concat(_str, "Position's entry funding rate is not matched")
    );
  }

  function assertPositionInfoOf(
    address _subAccount,
    uint256 _marketIndex,
    int256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest,
    uint256 _reserveValue,
    int256 _realizedPnl,
    uint256 _entryBorrowingRate,
    int256 _entryFundingRate
  ) internal {
    assertPositionInfoOf(
      _subAccount,
      _marketIndex,
      _positionSize,
      _avgPrice,
      _openInterest,
      _reserveValue,
      _realizedPnl,
      _entryBorrowingRate,
      _entryFundingRate,
      ""
    );
  }

  function assertMarketFundingRate(
    uint256 _marketIndex,
    int256 _currentFundingRate,
    uint256 _lastFundingTime,
    string memory _str
  ) internal {
    IPerpStorage.GlobalMarket memory _market = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_market.currentFundingRate, _currentFundingRate, string.concat(_str, "Market's Funding rate"));
    assertEq(_market.lastFundingTime, _lastFundingTime, string.concat(_str, "Market's Last funding time"));
  }

  function assertMarketFundingRate(
    uint256 _marketIndex,
    int256 _currentFundingRate,
    uint256 _lastFundingTime
  ) internal {
    assertMarketFundingRate(_marketIndex, _currentFundingRate, _lastFundingTime, "");
  }

  function assertMarketLongPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest,
    string memory _str
  ) internal {
    IPerpStorage.GlobalMarket memory _market = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_market.longPositionSize, _positionSize, string.concat(_str, "Market's Long position size"));
    assertEq(_market.longAvgPrice, _avgPrice, string.concat(_str, "Market's Long avg price size"));
    assertEq(_market.longOpenInterest, _openInterest, string.concat(_str, "Market's Long open interest size"));
  }

  function assertMarketLongPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest
  ) internal {
    assertMarketLongPosition(_marketIndex, _positionSize, _avgPrice, _openInterest, "");
  }

  function assertMarketShortPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest,
    string memory _str
  ) internal {
    IPerpStorage.GlobalMarket memory _market = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_market.shortPositionSize, _positionSize, string.concat(_str, "Market's Short position size"));
    assertEq(_market.shortAvgPrice, _avgPrice, string.concat(_str, "Market's Short avg price size"));
    assertEq(_market.shortOpenInterest, _openInterest, string.concat(_str, "Market's Short open interest size"));
  }

  function assertMarketShortPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest
  ) internal {
    assertMarketShortPosition(_marketIndex, _positionSize, _avgPrice, _openInterest, "");
  }

  function assertAssetClassReserve(uint8 _assetClassIndex, uint256 _reserved, string memory _str) internal {
    IPerpStorage.GlobalAssetClass memory _assetClass = perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);
    assertEq(_assetClass.reserveValueE30, _reserved, string.concat(_str, "Asset class's Reserve value"));
  }

  function assertAssetClassSumBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _sumBorrowingRate,
    uint256 _lastBorrowingTime,
    string memory _str
  ) internal {
    IPerpStorage.GlobalAssetClass memory _assetClass = perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);
    assertEq(
      _assetClass.sumBorrowingRate,
      _sumBorrowingRate,
      string.concat(_str, "Asset class's Sum of Borrowing rate")
    );

    assertEq(
      _assetClass.lastBorrowingTime,
      _lastBorrowingTime,
      string.concat(_str, "Asset class's Last borrowing time")
    );
  }

  function assertAssetClassReserve(uint8 _assetClassIndex, uint256 _reserved) internal {
    assertAssetClassReserve(_assetClassIndex, _reserved, "");
  }

  function assertAssetClassSumBorrowingRate(
    uint8 _assetClassIndex,
    uint256 _sumBorrowingRate,
    uint256 _lastBorrowingTime
  ) internal {
    assertAssetClassSumBorrowingRate(_assetClassIndex, _sumBorrowingRate, _lastBorrowingTime, "");
  }

  // todo - remove
  function assertAssetClassState(
    uint8 _assetClassIndex,
    uint256 _reserved,
    uint256 _sumBorrowingRate,
    uint256 _lastBorrowingTime,
    string memory _str
  ) internal {
    IPerpStorage.GlobalAssetClass memory _assetClass = perpStorage.getGlobalAssetClassByIndex(_assetClassIndex);
    assertEq(_assetClass.reserveValueE30, _reserved, string.concat(_str, "Asset class's Reserve value"));

    assertEq(
      _assetClass.sumBorrowingRate,
      _sumBorrowingRate,
      string.concat(_str, "Asset class's Sum of Borrowing rate")
    );

    assertEq(
      _assetClass.lastBorrowingTime,
      _lastBorrowingTime,
      string.concat(_str, "Asset class's Last borrowing time")
    );
  }

  // todo - remove
  function assertAssetClassState(
    uint8 _assetClassIndex,
    uint256 _reserved,
    uint256 _sumBorrowingRate,
    uint256 _lastBorrowingTime
  ) internal {
    assertAssetClassState(_assetClassIndex, _reserved, _sumBorrowingRate, _lastBorrowingTime, "");
  }

  // Calculator
  function assertSubAccountStatus(address _subAccount, uint256 _imr, uint256 _mmr, string memory _str) internal {
    assertEq(calculator.getIMR(_subAccount), _imr, string.concat(_str, "IMR is not matched"));
    assertEq(calculator.getMMR(_subAccount), _mmr, string.concat(_str, "MMR is not matched"));
  }

  function assertSubAccountStatus(address _subAccount, uint256 _imr, uint256 _mmr) internal {
    assertSubAccountStatus(_subAccount, _imr, _mmr, "");
  }
}
