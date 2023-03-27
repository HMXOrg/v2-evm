// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITraderLoyaltyCredit } from "@hmx/tokens/interfaces/ITraderLoyaltyCredit.sol";
import { Owned } from "@hmx/base/Owned.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TraderLoyaltyCredit is Owned, ITraderLoyaltyCredit {
  using SafeERC20 for IERC20;
  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Emitted when the allowance of a `spender` for an `user` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed user, address indexed spender, uint256 value);
  event FeedReward(address indexed feeder, uint256 indexed epochTimestamp, uint256 rewardAmount);
  event Claim(address indexed user, uint256 indexed epochTimestamp, uint256 userShare, uint256 rewardAmount);
  event SetMinter(address indexed minter, bool mintable);

  mapping(uint256 => mapping(address => uint256)) private _balances;

  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 private _totalSupply;
  mapping(uint256 => uint256) public totalSupplyByEpoch;

  string private constant _name = "Trader Loyalty Credit";
  string private constant _symbol = "TLC";
  uint256 public constant epochLength = 1 weeks;

  mapping(address => bool) minter;

  modifier onlyMinter() {
    require(minter[msg.sender], "TLC: Not Minter");
    _;
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
    address user = msg.sender;
    _transfer(getCurrentEpochTimestamp(), user, to, amount);
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
    require(currentAllowance >= subtractedValue, "TLC: decreased allowance below zero");
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
    require(from != address(0), "TLC: transfer from the zero address");
    require(to != address(0), "TLC: transfer to the zero address");

    _beforeTokenTransfer(from, to, amount);

    uint256 fromBalance = _balances[epochTimestamp][from];
    require(fromBalance >= amount, "TLC: transfer amount exceeds balance");
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
    require(account != address(0), "TLC: mint to the zero address");

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
    require(account != address(0), "TLC: burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[epochTimestamp][account];
    require(accountBalance >= amount, "TLC: burn amount exceeds balance");
    unchecked {
      _balances[epochTimestamp][account] = accountBalance - amount;
      // Overflow not possible: amount <= accountBalance <= totalSupply.
      _totalSupply -= amount;
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
    require(user != address(0), "TLC: approve from the zero address");
    require(spender != address(0), "TLC: approve to the zero address");

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
      require(currentAllowance >= amount, "TLC: insufficient allowance");
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
}
