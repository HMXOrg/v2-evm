// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// Libraries
import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

// Interfaces
import { IERC20Rebasing, YieldMode } from "src/interfaces/blast/IERC20Rebasing.sol";

/// @title MockYbUSDB - Copied from HMXORg/yb-blast with compatiability adjustments
contract MockYbUSDB is ERC20 {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;

  // Errors
  error ZeroAssets();
  error ZeroShares();

  // Configs
  IERC20Rebasing public immutable asset;

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

  constructor(IERC20Rebasing _usdb) ERC20("ybUSDB", "ybUSDB", 18) {
    // Effect
    asset = _usdb;

    asset.configure(YieldMode.CLAIMABLE);
  }

  /// @notice Claim all pending yield and update _totalAssets.
  function claimAllYield() public {
    _totalAssets += asset.claim(address(this), asset.getClaimableAmount(address(this)));
  }

  /// @notice Deposit USDB to mint ybUSDB.
  /// @dev This function follows ERC-4626 standard.
  /// @param _assets The amount of USDB to deposit.
  /// @param _receiver The receiver of ybUSDB.
  function deposit(uint256 _assets, address _receiver) external returns (uint256 _shares) {
    // Claim all pending yield
    claimAllYield();

    // Check for rounding error.
    if ((_shares = previewDeposit(_assets)) == 0) revert ZeroShares();

    // Transfer from depositor
    asset.transferFrom(msg.sender, address(this), _assets);

    // Effect
    // Update totalAssets
    _totalAssets += _assets;
    // Mint ybUSDB
    _mint(_receiver, _shares);

    // Log
    emit Deposit(msg.sender, _receiver, _assets, _shares);
  }

  /// @notice Mint ybUSDB by specifying the amount of ybUSDB to mint.
  /// @param _shares The amount of ybUSDB to mint.
  /// @param _receiver The receiver of ybUSDB.
  function mint(uint256 _shares, address _receiver) external returns (uint256 _assets) {
    // Claim all pending yield
    claimAllYield();

    _assets = previewMint(_shares);

    // Transfer from depositor
    asset.transferFrom(msg.sender, address(this), _assets);

    // Effect
    // Update totalAssets
    _totalAssets += _assets;
    // Mint ybUSDB
    _mint(_receiver, _shares);

    // Log
    emit Deposit(msg.sender, _receiver, _assets, _shares);
  }

  /// @notice Redeem ybUSDB to USDB by specifying the amount of ybUSDB to redeem.
  /// @dev This function follows ERC-4626 standard.
  /// @param _shares The amount of ybUSDB to redeem.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybUSDB.
  function redeem(uint256 _shares, address _receiver, address _owner) public returns (uint256 _assets) {
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
    asset.transfer(_receiver, _assets);

    emit Withdraw(msg.sender, _receiver, _owner, _assets, _shares);
  }

  /// @notice Withdraw WETH by specifying the amount of assets that user wishes to receive.
  /// @dev This function follows ERC-4626 standard.
  /// @param _assets The amount of assets that user wishes to receive.
  /// @param _receiver The receiver of the assets.
  /// @param _owner The owner of the ybUSDB.
  function withdraw(uint256 _assets, address _receiver, address _owner) public returns (uint256 _shares) {
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
    asset.transfer(_receiver, _assets);

    emit Withdraw(msg.sender, _receiver, _owner, _assets, _shares);
  }

  /// @notice Return the total assets managed by this contract.
  /// @dev Unclaimed yield is included.
  function totalAssets() public view returns (uint256) {
    return _totalAssets + asset.getClaimableAmount(address(this));
  }

  /// @notice Preview the amount of ybUSDB to mint by specifying the amount of assets to deposit.
  /// @param _assets The amount of assets to deposit.
  function previewDeposit(uint256 _assets) public view returns (uint256 _shares) {
    return convertToShares(_assets);
  }

  /// @notice Preview the amount of assets to receive by specifying the amount of ybUSDB to redeem.
  /// @param _shares The amount of ybUSDB to redeem.
  function previewRedeem(uint256 _shares) public view returns (uint256 _assets) {
    return convertToAssets(_shares);
  }

  /// @notice Preview the amount of WETH/ETH needed to mint by specifying the amount of ybUSDB.
  /// @param _shares The amount of ybUSDB to mint.
  function previewMint(uint256 _shares) public view returns (uint256 _assets) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _shares : _shares.mulDivUp(totalAssets(), _totalSupply);
  }

  /// @notice Preview the amount of ybUSDB needed by specifying the amount of WETH/ETH wishes to receive.
  /// @param _assets The amount of WETH/ETH wishes to receive.
  function previewWithdraw(uint256 _assets) public view returns (uint256 _shares) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _assets : _assets.mulDivUp(_totalSupply, totalAssets());
  }

  /// @notice Convert the amount of assets to ybUSDB.
  /// @param _assets The amount of assets to convert.
  function convertToShares(uint256 _assets) public view returns (uint256 _shares) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _assets : _assets.mulDivDown(_totalSupply, totalAssets());
  }

  /// @notice Convert the amount of ybUSDB to assets.
  /// @param _shares The amount of ybUSDB to convert.
  function convertToAssets(uint256 _shares) public view returns (uint256 _assets) {
    // SLOAD
    uint256 _totalSupply = totalSupply;
    return _totalSupply == 0 ? _shares : _shares.mulDivDown(totalAssets(), _totalSupply);
  }

  /// @notice Return the amount of assets that can be deposited to ybUSDB.
  function maxDeposit(address) public pure returns (uint256) {
    return type(uint256).max;
  }

  /// @notice Return the amount of ybUSDB that can be minted.
  function maxMint(address) public pure returns (uint256) {
    return type(uint256).max;
  }

  /// @notice Return the amount of ETH/WETH that can be withdrawn from ybUSDB.
  /// @param _owner The owner of the ybUSDB.
  function maxWithdraw(address _owner) public view returns (uint256) {
    return convertToAssets(balanceOf[_owner]);
  }

  /// @notice Return the amount of ybUSDB that can be redeemed.
  /// @param _owner The owner of the ybUSDB.
  function maxRedeem(address _owner) public view returns (uint256) {
    return balanceOf[_owner];
  }
}
