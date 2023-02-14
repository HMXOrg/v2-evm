// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interfaces
import { ICrossMarginService } from "./interfaces/ICrossMarginService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";

contract CrossMarginService is Ownable, ReentrancyGuard, ICrossMarginService {
  address public configStorage;
  address public vaultStorage;

  // EVENTs
  event LogSetConfigStorage(
    address indexed oldConfigStorage,
    address newConfigStorage
  );

  event LogSetVaultStorage(
    address indexed oldVaultStorage,
    address newVaultStorage
  );

  event LogIncreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint amount
  );

  event LogDecreaseTokenLiquidity(
    address indexed trader,
    address token,
    uint amount
  );

  constructor(address _configStorage, address _vaultStorage) {
    if (_configStorage == address(0) || _vaultStorage == address(0))
      revert ICrossMarginService_InvalidAddress();
    configStorage = _configStorage;
    vaultStorage = _vaultStorage;
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////  SETTER FUNCTION  ///////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function setConfigStorage(address _configStorage) external onlyOwner {
    if (_configStorage == address(0))
      revert ICrossMarginService_InvalidAddress();
    address oldConfigStorage = configStorage;
    configStorage = _configStorage;
    emit LogSetConfigStorage(oldConfigStorage, configStorage);
  }

  function setVaultStorage(address _vaultStorage) external onlyOwner {
    if (_vaultStorage == address(0))
      revert ICrossMarginService_InvalidAddress();
    address oldVaultStorage = vaultStorage;
    vaultStorage = _vaultStorage;
    emit LogSetVaultStorage(oldVaultStorage, vaultStorage);
  }

  ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////
  ////////////////////////////////////////////////////////////////////////////////////

  function increaseTokenLiquidity(
    address _trader,
    address _token,
    uint256 _amount
  ) external nonReentrant {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);

    uint oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _trader,
      _token
    );
    uint newBalance = oldBalance + _amount;
    IVaultStorage(vaultStorage).setTraderBalance(_trader, _token, newBalance);

    // register new token to a user
    if (oldBalance == 0 && newBalance != 0) {
      IVaultStorage(vaultStorage).addTraderToken(_trader, _token);
    }

    IERC20(_token).transferFrom(msg.sender, vaultStorage, _amount);

    emit LogIncreaseTokenLiquidity(_trader, _token, _amount);
  }

  function decreaseTokenLiquidity(
    address _trader,
    address _token,
    uint256 _amount
  ) external nonReentrant {
    IConfigStorage(configStorage).validateServiceExecutor(
      address(this),
      msg.sender
    );
    IConfigStorage(configStorage).validateAcceptedCollateral(_token);

    uint oldBalance = IVaultStorage(vaultStorage).traderBalances(
      _trader,
      _token
    );
    if (_amount > oldBalance) revert ICrossMarginService_InsufficientBalance();

    uint newBalance = oldBalance - _amount;
    IVaultStorage(vaultStorage).setTraderBalance(_trader, _token, newBalance);

    // deregister token, if the user remove all of the token out
    if (oldBalance != 0 && newBalance == 0) {
      IVaultStorage(vaultStorage).removeTraderToken(_trader, _token);
    }

    IERC20(_token).transferFrom(vaultStorage, msg.sender, _amount);

    emit LogDecreaseTokenLiquidity(_trader, _token, _amount);
  }
}
