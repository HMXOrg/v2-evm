// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";

import { BaseIntTest_SetWhitelist } from "@hmx-test/integration/08_BaseIntTest_SetWhitelist.i.sol";

contract BaseIntTest_Assertions is BaseIntTest_SetWhitelist, StdAssertions {
  // Token Balances

  function assertTokenBalanceOf(address _account, address _token, uint256 _balance) internal {
    assertEq(ERC20(_token).balanceOf(address(_account)), _balance, "Trader's balance is not matched");
  }

  // PLP
  function assertPLPTotalSupply(uint256 _totalSupply) internal {
    assertEq(plpV2.totalSupply(), _totalSupply, "PLPv2 Total supply is not matched");
  }

  // Vault Storage

  function assertPLPDebt(uint256 _plpDebt) internal {
    assertEq(vaultStorage.plpLiquidityDebtUSDE30(), _plpDebt, "PLP liquidity debt is not matched");
  }

  function assertPLPLiquidity(address _token, uint256 _liquidity) internal {
    assertEq(vaultStorage.plpLiquidity(_token), _liquidity, "PLP token liquidity is not matched");
  }

  function assertVaultTokenBalance(address _token, uint256 _balance) internal {
    assertEq(vaultStorage.totalAmount(_token), _balance, "Vault's Total amount of token is not matched");
    assertEq(ERC20(_token).balanceOf(address(vaultStorage)), _balance, "Vault's token balance is not matched");
  }

  function assertVaultsFees(address _token, uint256 _fee, uint256 _fundingFee, uint256 _devFee) internal {
    assertEq(vaultStorage.protocolFees(_token), _fee, "Vault's Protocol Fee is not matched");
    assertEq(vaultStorage.fundingFee(_token), _fundingFee, "Vault's Funding fee is not matched");
    assertEq(vaultStorage.devFees(_token), _devFee, "Vault's Dev fee is not matched");
  }

  function assertSubAccountTokenBalance(
    address _subAccount,
    address _token,
    bool _shouldExists,
    uint256 _balance
  ) internal {
    assertEq(vaultStorage.traderBalances(_subAccount, _token), _balance, "Trader's balance is not matched");

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
    assertEq(_found, _shouldExists, _shouldExists ? "Token should exists" : "Token should not exists");
  }

  // check all trader's token and balance
  function assertSubAccountTokensBalances(
    address _subAccount,
    address[] calldata _tokens,
    uint256[] calldata _balances
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
      "Trader's token list length is not matched"
    );
  }

  // Perp Storage

  function assertPositionInfoOf(
    address _subAccount,
    uint256 _marketIndex,
    int256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest,
    uint256 _reserveValue
  ) internal {
    bytes32 _positionId = keccak256(abi.encodePacked(_subAccount, _marketIndex));
    IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);

    assertEq(_position.positionSizeE30, _positionSize, "Position's size is not matched");
    assertEq(_position.avgEntryPriceE30, _avgPrice, "Position's average price is not matched");
    assertEq(_position.openInterest, _openInterest, "Position's open interest is not matched");
    assertEq(_position.reserveValueE30, _reserveValue, "Position's reserve value is not matched");
  }

  function assertPositionPnL(address _subAccount, uint256 _marketIndex, int256 realizedPnl) internal {
    bytes32 _positionId = keccak256(abi.encodePacked(_subAccount, _marketIndex));
    IPerpStorage.Position memory _position = perpStorage.getPositionById(_positionId);

    assertEq(_position.realizedPnl, realizedPnl, "Position's realized PNL is not matched");
  }

  function assertMarketLongPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest
  ) internal {
    IPerpStorage.GlobalMarket memory _market = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_market.longPositionSize, _positionSize, "Market's Long position size");
    assertEq(_market.longAvgPrice, _avgPrice, "Market's Long avg price size");
    assertEq(_market.longOpenInterest, _openInterest, "Market's Long open interest size");
  }

  function assertMarketShortPosition(
    uint256 _marketIndex,
    uint256 _positionSize,
    uint256 _avgPrice,
    uint256 _openInterest
  ) internal {
    IPerpStorage.GlobalMarket memory _market = perpStorage.getGlobalMarketByIndex(_marketIndex);

    assertEq(_market.shortPositionSize, _positionSize, "Market's Short position size");
    assertEq(_market.shortAvgPrice, _avgPrice, "Market's Short avg price size");
    assertEq(_market.shortOpenInterest, _openInterest, "Market's Short open interest size");
  }

  function assertGlobalTotalReserved(uint256 _totalReserve) internal {
    assertEq(perpStorage.getGlobalState().reserveValueE30, _totalReserve, "Total global Reserve value");
  }

  function assertAssetClassTotalReserved(uint8 _assetClassIndex, uint256 _reserved) internal {
    assertEq(
      perpStorage.getGlobalAssetClassByIndex(_assetClassIndex).reserveValueE30,
      _reserved,
      "Total asset class Reserve value"
    );
  }

  // Calculator

  function assertSubAccounStatus(address _subAccount, uint256 _freeCollateral, uint256 _imr, uint256 _mmr) internal {
    // note: 2,3 argument use for limited price
    // assertEq(calculator.getEquity(SUB_ACCOUNT, 0, 0), "Equity is not matched");
    assertEq(calculator.getFreeCollateral(_subAccount, 0, 0), _freeCollateral, "Free collateral is not matched");
    assertEq(calculator.getIMR(_subAccount), _imr, "IMR is not matched");
    assertEq(calculator.getMMR(_subAccount), _mmr, "MMR is not matched");
  }
}
