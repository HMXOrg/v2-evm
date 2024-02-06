// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Libraries
import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

// Interfaces
import { IBlast, YieldMode } from "src/interfaces/blast/IBlast.sol";
import { IWNative } from "src/interfaces/IWNative.sol";

/// @title MockYbETH - Copied from HMXORg/yb-blast with compatiability adjustments
contract MockYbETH is ERC20 {
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  // Errors
  error ZeroAssets();
  error ZeroShares();

  // Configs
  IWNative public immutable weth;
  IBlast public immutable blast;

  // States
  uint256 internal _totalAssets;

  // Events
  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  constructor(IWNative _weth, IBlast _blast) ERC20("ybETH", "ybETH", 18) {
    // Effect
    weth = _weth;
    blast = _blast;

    // Interaction
    blast.configureClaimableYield();
  }

  function asset() external pure returns (address) {
    return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  /// @notice Claim all pending yield and update _totalAssets.
  function claimAllYield() public {
    _totalAssets += blast.claimAllYield(address(this), address(this));
  }

  /// @notice Deposit ETH to mint ybETH.
  /// @dev This is an extension of ERC-4626 function to support native asset deposit.
  /// @param _receiver The receiver of ybETH.
  function depositETH(address _receiver) public payable returns (uint256 _shares) {
    // Claim all pending yield
    claimAllYield();

    // Check for rounding error.
    if ((_shares = previewDeposit(msg.value)) == 0) revert ZeroShares();

    // Effect
    // Update totalAssets
    _totalAssets += msg.value;
    // Mint ybETH
    _mint(_receiver, _shares);

    // Log
    emit Deposit(msg.sender, _receiver, msg.value, _shares);
  }

  /// @notice Deposit WETH to mint ybETH.
  /// @dev This function follows ERC-4626 standard.
  /// @param _assets The amount of WETH to deposit.
  /// @param _receiver The receiver of ybETH.
  function deposit(uint256 _assets, address _receiver) external returns (uint256 _shares) {
    // Claim all pending yield
    claimAllYield();

    // Check for rounding error.
    if ((_shares = previewDeposit(_assets)) == 0) revert ZeroShares();

    // Transfer from depositor
    weth.transferFrom(msg.sender, address(this), _assets);
    weth.withdraw(_assets);

    // Effect
    // Update totalAssets
    _totalAssets += _assets;
    // Mint ybETH
    _mint(_receiver, _shares);

    // Log
    emit Deposit(msg.sender, _receiver, _assets, _shares);
  }

  /// @notice Mint ybETH by specifying the amount of ybETH to mint.
  /// @dev Only work with WETH as we can't transferFrom ETH.
  /// @param _shares The amount of ybETH to mint.
  /// @param _receiver The receiver of ybETH.
  function mint(uint256 _shares, address _receiver) external returns (uint256 _assets) {
    // Claim all pending yield
    claimAllYield();

    _assets = previewMint(_shares);

    // Transfer from depositor
    weth.transferFrom(msg.sender, address(this), _assets);
    weth.withdraw(_assets);

    // Effect
    // Update totalAssets
    _totalAssets += _assets;
    // Mint ybETH
    _mint(_receiver, _shares);

    // Log
    emit Deposit(msg.sender, _receiver, _assets, _shares);
  }

  /// @notice The actual implementation of redeem
  /// @dev if msg.sender is not the owner, the caller must have allowance from the owner.
  /// @dev if allowance is unlimited, then the allowance is not decreased.
  /// @param _isEthOut Whether to withdraw ETH or WETH.
  /// @param _shares The amount of ybETH to redeem.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function _redeem(
    bool _isEthOut,
    uint256 _shares,
    address _receiver,
    address _owner
  ) internal returns (uint256 _assets) {
    // Claim all pending yield
    claimAllYield();

    if (msg.sender != _owner) {
      // If msg.sender is not the owner, then check allowance
      uint256 _allowed = allowance[_owner][msg.sender];
      if (_allowed != type(uint256).max) {
        // If not unlimited allowance, then decrease allowance.
        // This should be reverted if the allowance is not enough.
        allowance[_owner][msg.sender] = _allowed - _shares;
      }
    }

    // Check for rounding error.
    if ((_assets = previewRedeem(_shares)) == 0) revert ZeroAssets();

    // Effect
    _burn(_owner, _shares);
    _totalAssets -= _assets;

    // Interaction
    // Transfer assets out
    if (_isEthOut) {
      address(_receiver).safeTransferETH(_assets);
    } else {
      address(weth).safeTransferETH(_assets);
      weth.transfer(_receiver, _assets);
    }

    emit Withdraw(msg.sender, _receiver, _owner, _assets, _shares);
  }

  /// @notice Redeem ybETH to ETH by specifying the amount of ybETH to redeem.
  /// @param _shares The amount of ybETH to redeem.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function redeemETH(uint256 _shares, address _receiver, address _owner) public returns (uint256 _assets) {
    return _redeem(true, _shares, _receiver, _owner);
  }

  /// @notice Redeem ybETH to WETH by specifying the amount of ybETH to redeem.
  /// @dev This function follows ERC-4626 standard.
  /// @param _shares The amount of ybETH to redeem.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function redeem(uint256 _shares, address _receiver, address _owner) public returns (uint256 _assets) {
    return _redeem(false, _shares, _receiver, _owner);
  }

  /// @notice The actual implementation of withdraw.
  /// @dev if msg.sender is not the owner, the caller must have allowance from the owner.
  /// @dev if allowance is unlimited, then the allowance is not decreased.
  /// @param _isEthOut Whether to withdraw ETH or WETH.
  /// @param _assets The amount of assets that user wishes to receive.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function _withdraw(
    bool _isEthOut,
    uint256 _assets,
    address _receiver,
    address _owner
  ) internal returns (uint256 _shares) {
    // Claim all pending yield
    claimAllYield();

    _shares = previewWithdraw(_assets);

    if (msg.sender != _owner) {
      // If msg.sender is not the owner, then check allowance
      uint256 _allowed = allowance[_owner][msg.sender];
      if (_allowed != type(uint256).max) {
        // If not unlimited allowance, then decrease allowance.
        // This should be reverted if the allowance is not enough.
        allowance[_owner][msg.sender] = _allowed - _shares;
      }
    }

    // Effect
    _burn(_owner, _shares);
    _totalAssets -= _assets;

    // Interaction
    // Transfer assets out
    if (_isEthOut) {
      address(_receiver).safeTransferETH(_assets);
    } else {
      address(weth).safeTransferETH(_assets);
      weth.transfer(_receiver, _assets);
    }

    emit Withdraw(msg.sender, _receiver, _owner, _assets, _shares);
  }

  /// @notice Withdraw ETH by specifying the amount of assets that user wishes to receive.
  /// @param _assets The amount of assets that user wishes to receive.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function withdrawETH(uint256 _assets, address _receiver, address _owner) public returns (uint256 _shares) {
    return _withdraw(true, _assets, _receiver, _owner);
  }

  /// @notice Withdraw WETH by specifying the amount of assets that user wishes to receive.
  /// @dev This function follows ERC-4626 standard.
  /// @param _assets The amount of assets that user wishes to receive.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybETH.
  function withdraw(uint256 _assets, address _receiver, address _owner) public returns (uint256 _shares) {
    return _withdraw(false, _assets, _receiver, _owner);
  }

  /// @notice Return the total assets managed by this contract.
  /// @dev Unclaimed yield is included.
  function totalAssets() public view returns (uint256) {
    return _totalAssets + blast.readClaimableYield(address(this));
  }

  /// @notice Preview the amount of ybETH to mint by specifying the amount of assets to deposit.
  /// @param _assets The amount of assets to deposit.
  function previewDeposit(uint256 _assets) public view returns (uint256 _shares) {
    return convertToShares(_assets);
  }

  /// @notice Preview the amount of assets to receive by specifying the amount of ybETH to redeem.
  /// @param _shares The amount of ybETH to redeem.
  function previewRedeem(uint256 _shares) public view returns (uint256 _assets) {
    return convertToAssets(_shares);
  }

  /// @notice Preview the amount of WETH/ETH needed to mint by specifying the amount of ybETH.
  /// @param _shares The amount of ybETH to mint.
  function previewMint(uint256 _shares) public view returns (uint256 _assets) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _shares : _shares.mulDivUp(totalAssets(), _totalSupply);
  }

  /// @notice Preview the amount of ybETH needed by specifying the amount of WETH/ETH wishes to receive.
  /// @param _assets The amount of WETH/ETH wishes to receive.
  function previewWithdraw(uint256 _assets) public view returns (uint256 _shares) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _assets : _assets.mulDivUp(_totalSupply, totalAssets());
  }

  /// @notice Convert the amount of assets to ybETH.
  /// @param _assets The amount of assets to convert.
  function convertToShares(uint256 _assets) public view returns (uint256 _shares) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _assets : _assets.mulDivDown(_totalSupply, totalAssets());
  }

  /// @notice Convert the amount of ybETH to assets.
  /// @param _shares The amount of ybETH to convert.
  function convertToAssets(uint256 _shares) public view returns (uint256 _assets) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _shares : _shares.mulDivDown(totalAssets(), _totalSupply);
  }

  /// @notice Return the amount of assets that can be deposited to ybETH.
  function maxDeposit(address) public pure returns (uint256) {
    return type(uint256).max;
  }

  /// @notice Return the amount of ybETH that can be minted.
  function maxMint(address) public pure returns (uint256) {
    return type(uint256).max;
  }

  /// @notice Return the amount of ETH/WETH that can be withdrawn from ybETH.
  /// @param _owner The owner of the ybETH.
  function maxWithdraw(address _owner) public view returns (uint256) {
    return convertToAssets(balanceOf[_owner]);
  }

  /// @notice Return the amount of ybETH that can be redeemed.
  /// @param _owner The owner of the ybETH.
  function maxRedeem(address _owner) public view returns (uint256) {
    return balanceOf[_owner];
  }

  receive() external payable {
    if (msg.sender != address(weth)) {
      depositETH(msg.sender);
    }
  }
}
