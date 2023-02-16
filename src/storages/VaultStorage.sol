// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interfaces
import { IVaultStorage } from "./interfaces/IVaultStorage.sol";

/// @title VaultStorage
/// @notice storage contract to do accounting for token, and also hold physical tokens
contract VaultStorage is IVaultStorage {
  // liquidity provider address => token => amount
  mapping(address => mapping(address => uint256))
    public liquidityProviderBalances;
  mapping(address => address[]) public liquidityProviderTokens;
  // trader address (with sub-account) => token => amount
  mapping(address => mapping(address => uint256)) public traderBalances;
  // mapping(address => address[]) public traderTokens;
  mapping(address => address[]) public traderTokens;

  // EVENTs
  event LogSetTraderBalance(
    address indexed trader,
    address token,
    uint256 balance
  );

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  VALIDATION FUNCTION  ///////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function validatAddTraderToken(
    address _subAccount,
    address _token
  ) internal view {
    address[] storage traderToken = traderTokens[_subAccount];

    for (uint256 i; i < traderToken.length; ) {
      if (traderToken[i] == _token)
        revert IVaultStorage_TraderTokenAlreadyExists();
      unchecked {
        i++;
      }
    }
  }

  function validateRemoveTraderToken(
    address _subAccount,
    address _token
  ) internal view {
    if (traderBalances[_subAccount][_token] != 0)
      revert IVaultStorage_TraderBalanceRemaining();
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function getTraderTokens(
    address _subAccount
  ) external view returns (address[] memory) {
    return traderTokens[_subAccount];
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setTraderBalance(
    address _subAccount,
    address _token,
    uint256 _balance
  ) external {
    traderBalances[_subAccount][_token] = _balance;
    emit LogSetTraderBalance(_subAccount, _token, _balance);
  }

  function addTraderToken(address _subAccount, address _token) external {
    validatAddTraderToken(_subAccount, _token);
    traderTokens[_subAccount].push(_token);
  }

  function removeTraderToken(address _subAccount, address _token) external {
    validateRemoveTraderToken(_subAccount, _token);

    address[] storage traderToken = traderTokens[_subAccount];
    uint256 tokenLen = traderToken.length;
    uint256 lastTokenIndex = tokenLen - 1;

    // find and deregister the token
    for (uint256 i; i < tokenLen; ) {
      if (traderToken[i] == _token) {
        // delete the token by replacing it with the last one and then pop it from there
        if (i != lastTokenIndex) {
          traderToken[i] = traderToken[lastTokenIndex];
        }
        traderToken.pop();
        break;
      }

      unchecked {
        i++;
      }
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////
  ////////////////////////////////////////////////////////////////////////////////////
  // @todo - add only whitelisted services
  function transferToken(
    address _subAccount,
    address _token,
    uint256 _amount
  ) external {
    IERC20(_token).transfer(_subAccount, _amount);
  }
}
