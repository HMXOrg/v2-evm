// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

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
    uint balance
  );

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  VALIDATION FUNCTION  ///////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function validatAddTraderToken(address _trader, address _token) public view {
    address[] storage traderToken = traderTokens[_trader];

    for (uint256 i; i < traderToken.length; ) {
      if (traderToken[i] == _token)
        revert IVaultStorage_TraderTokenAlreadyExists();
      unchecked {
        i++;
      }
    }
  }

  function validateRemoveTraderToken(
    address _trader,
    address _token
  ) public view {
    if (traderBalances[_trader][_token] != 0)
      revert IVaultStorage_TraderBalanceRemaining();
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  GETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function getTraderTokens(
    address _trader
  ) external view returns (address[] memory) {
    return traderTokens[_trader];
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setTraderBalance(
    address _trader,
    address _token,
    uint256 _balance
  ) external {
    traderBalances[_trader][_token] = _balance;
    emit LogSetTraderBalance(_trader, _token, _balance);
  }

  function addTraderToken(address _trader, address _token) external {
    validatAddTraderToken(_trader, _token);
    traderTokens[_trader].push(_token);
  }

  function removeTraderToken(address _trader, address _token) external {
    validateRemoveTraderToken(_trader, _token);

    address[] storage traderToken = traderTokens[_trader];
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
}
