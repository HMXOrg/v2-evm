// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { StdAssertions } from "forge-std/StdAssertions.sol";

import { BaseIntTest_SetWhitelist } from "@hmx-test/integration/08_BaseIntTest_SetWhitelist.i.sol";

contract BaseIntTest_Assertions is BaseIntTest_SetWhitelist, StdAssertions {
  function assertPLPTotalSupply(uint256 _totalSupply) internal {
    assertEq(plpV2.totalSupply(), _totalSupply, "PLPv2 Total supply is not matched");
  }

  function assertAccountTokenBalance(address _account, address _token, uint256 _balance) internal {
    assertEq(ERC20(_token).balanceOf(address(_account)), _balance, "Trader's balance is not matched");
  }

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
    assertEq(vaultStorage.fees(_token), _fee, "Vault's Fee is not matched");
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
}
