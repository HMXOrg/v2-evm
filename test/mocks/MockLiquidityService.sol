// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { MockErc20 } from "./MockErc20.sol";

contract MockLiquidityService {
  address public configStorage;
  address public perpStorage;
  address public vaultStorage;

  bool public reverted;
  //is reverted is true, it can set to revert as bytes or revert as message
  bool public revertAsMessage;

  bool public plpEnabled;
  error LiquidityService_CircuitBreaker();
  error LiquidityService_BadAmount();
  error LiquidityService_RevertAsBytes();

  constructor(address _configStorage, address _perpStorage, address _vaultStorage) {
    configStorage = _configStorage;
    perpStorage = _perpStorage;
    vaultStorage = _vaultStorage;
  }

  function setConfigStorage(address _address) external {
    configStorage = _address;
  }

  function setPerpStorage(address _address) external {
    perpStorage = _address;
  }

  function setVaultStorage(address _address) external {
    vaultStorage = _address;
  }

  function setReverted(bool _reverted) external {
    reverted = _reverted;
  }

  function setRevertAsMessage(bool isRevertMessage) external {
    revertAsMessage = isRevertMessage;
  }

  function setPlpEnabled(bool _plpEnabled) external {
    plpEnabled = _plpEnabled;
  }

  function addLiquidity(
    address /*_lpProvider*/,
    address /* _token */,
    uint256 /* _amount */,
    uint256 /* _minAmount */
  ) external view returns (uint256) {
    if (reverted) {
      if (revertAsMessage) {
        require(false, "Reverted as Message");
      } else {
        revert LiquidityService_RevertAsBytes();
      }
    }

    return 1;
  }

  function removeLiquidity(
    address /*_lpProvider*/,
    address _tokenOut,
    uint256 _amount, // amountIn
    uint256 /*_minAmount*/
  ) external returns (uint256) {
    if (reverted) {
      if (revertAsMessage) {
        require(false, "Reverted as Message");
      } else {
        revert LiquidityService_RevertAsBytes();
      }
    }

    MockErc20(_tokenOut).mint(msg.sender, _amount);

    return _amount;
  }

  /// @notice validatePreAddRemoveLiquidity used in Handler,Service
  /// @param _amount amountIn
  function validatePreAddRemoveLiquidity(uint256 _amount) public view {
    if (!plpEnabled) {
      revert LiquidityService_CircuitBreaker();
    }

    if (_amount == 0) {
      revert LiquidityService_BadAmount();
    }
  }
}
