// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ITraderLoyaltyCredit } from "@hmx/tokens/interfaces/ITraderLoyaltyCredit.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract TraderLoyaltyCredit is OwnableUpgradeable, ITraderLoyaltyCredit {
  event SetMinter(address indexed minter, bool mintable);

  mapping(uint256 => mapping(address => uint256)) private _balances;

  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 private _totalSupply;
  mapping(uint256 => uint256) public totalSupplyByEpoch;

  string private constant _name = "Trader Loyalty Credit";
  string private constant _symbol = "TLC";
  uint256 public constant epochLength = 1 weeks;

  mapping(address => bool) public minter;

  modifier onlyMinter() {
    if (!minter[msg.sender]) revert TLC_NotMinter();
    _;
  }

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();
  }

  /**
   * @dev Returns the name of the token.
   */
  function name() external pure returns (string memory) {
    return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function symbol() external pure returns (string memory) {
    return _symbol;
  }

  /**
   * @dev Returns the number of decimals used to get its user representation.
   * For example, if `decimals` equals `2`, a balance of `505` tokens should
   * be displayed to a user as `5.05` (`505 / 10 ** 2`).
   *
   * Tokens usually opt for a value of 18, imitating the relationship between
   * Ether and Wei. This is the value {ERC20} uses, unless this function is
   * overridden;
   *
   * NOTE: This information is only used for _display_ purposes: it in
   * no way affects any of the arithmetic of the contract, including
   * {IERC20-balanceOf} and {IERC20-transfer}.
   */
  function decimals() external pure returns (uint8) {
    return 18;
  }

  /**
   * @dev See {IERC20-totalSupply}.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {IERC20-balanceOf}.
   */
  function balanceOf(address account) external view returns (uint256) {
    return _balances[getCurrentEpochTimestamp()][account];
  }

  function balanceOf(uint256 epochTimestamp, address account) external view returns (uint256) {
    return _balances[epochTimestamp][account];
  }

  /**
   * @dev See {IERC20-transfer}.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address to, uint256 amount) public returns (bool) {
    _transfer(getCurrentEpochTimestamp(), msg.sender, to, amount);
    return true;
  }

  /**
   * @dev See {IERC20-allowance}.
   */
  function allowance(address user, address spender) public view returns (uint256) {
    return _allowances[user][spender];
  }

  /**
   * @dev See {IERC20-approve}.
   *
   * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
   * `transferFrom`. This is semantically equivalent to an infinite approval.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) public returns (bool) {
    address user = msg.sender;
    _approve(user, spender, amount);
    return true;
  }

  /**
   * @dev See {IERC20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {ERC20}.
   *
   * NOTE: Does not update the allowance if the current allowance
   * is the maximum `uint256`.
   *
   * Requirements:
   *
   * - `from` and `to` cannot be the zero address.
   * - `from` must have a balance of at least `amount`.
   * - the caller must have allowance for ``from``'s tokens of at least
   * `amount`.
   */
  function transferFrom(address from, address to, uint256 amount) public returns (bool) {
    address spender = msg.sender;
    _spendAllowance(from, spender, amount);
    _transfer(getCurrentEpochTimestamp(), from, to, amount);
    return true;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {IERC20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    address user = msg.sender;
    _approve(user, spender, allowance(user, spender) + addedValue);
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {IERC20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    address user = msg.sender;
    uint256 currentAllowance = allowance(user, spender);
    if (currentAllowance < subtractedValue) revert TLC_AllowanceBelowZero();
    unchecked {
      _approve(user, spender, currentAllowance - subtractedValue);
    }

    return true;
  }

  /**
   * @dev Moves `amount` of tokens from `from` to `to`.
   *
   * This internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `from` cannot be the zero address.
   * - `to` cannot be the zero address.
   * - `from` must have a balance of at least `amount`.
   */
  function _transfer(uint256 epochTimestamp, address from, address to, uint256 amount) internal {
    if (from == address(0)) revert TLC_TransferFromZeroAddress();
    if (to == address(0)) revert TLC_TransferToZeroAddress();

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = _balances[epochTimestamp][from];
    if (fromBalance < amount) revert TLC_TransferAmountExceedsBalance();
    unchecked {
      _balances[epochTimestamp][from] = fromBalance - amount;
      // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
      // decrementing then incrementing.
      _balances[epochTimestamp][to] += amount;
    }

    emit Transfer(from, to, amount);

    _afterTokenTransfer(from, to, amount);
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function mint(address account, uint256 amount) external onlyMinter {
    if (account == address(0)) revert TLC_MintToZeroAddress();

    _beforeTokenTransfer(address(0), account, amount);

    uint256 thisEpochTimestamp = getCurrentEpochTimestamp();

    _totalSupply += amount;
    totalSupplyByEpoch[thisEpochTimestamp] += amount;

    unchecked {
      // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
      _balances[getCurrentEpochTimestamp()][account] += amount;
    }
    emit Transfer(address(0), account, amount);

    _afterTokenTransfer(address(0), account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(uint256 epochTimestamp, address account, uint256 amount) internal virtual {
    if (account == address(0)) revert TLC_BurnFromZeroAddress();

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[epochTimestamp][account];
    if (accountBalance < amount) revert TLC_BurnAmountExceedsBalance();
    unchecked {
      _balances[epochTimestamp][account] = accountBalance - amount;
      // Overflow not possible: amount <= accountBalance <= totalSupply.
      _totalSupply -= amount;
      totalSupplyByEpoch[epochTimestamp] -= amount;
    }

    emit Transfer(account, address(0), amount);

    _afterTokenTransfer(account, address(0), amount);
  }

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `user` s tokens.
   *
   * This internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `user` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
  function _approve(address user, address spender, uint256 amount) internal {
    if (user == address(0)) revert TLC_ApproveFromZeroAddress();
    if (spender == address(0)) revert TLC_ApproveToZeroAddress();

    _allowances[user][spender] = amount;
    emit Approval(user, spender, amount);
  }

  /**
   * @dev Updates `user` s allowance for `spender` based on spent `amount`.
   *
   * Does not update the allowance amount in case of infinite allowance.
   * Revert if not enough allowance is available.
   *
   * Might emit an {Approval} event.
   */
  function _spendAllowance(address user, address spender, uint256 amount) internal {
    uint256 currentAllowance = allowance(user, spender);
    if (currentAllowance != type(uint256).max) {
      if (currentAllowance < amount) revert TLC_InsufficientAllowance();
      unchecked {
        _approve(user, spender, currentAllowance - amount);
      }
    }
  }

  /**
   * @dev Hook that is called before any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * will be transferred to `to`.
   * - when `from` is zero, `amount` tokens will be minted for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal {}

  /**
   * @dev Hook that is called after any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * has been transferred to `to`.
   * - when `from` is zero, `amount` tokens have been minted for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _afterTokenTransfer(address from, address to, uint256 amount) internal {}

  function getCurrentEpochTimestamp() public view returns (uint256 epochTimestamp) {
    return (block.timestamp / epochLength) * epochLength;
  }

  function setMinter(address _minter, bool _mintable) external onlyOwner {
    minter[_minter] = _mintable;

    emit SetMinter(_minter, _mintable);
  }

  function isMinter(address _minter) external view returns (bool) {
    return minter[_minter];
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
