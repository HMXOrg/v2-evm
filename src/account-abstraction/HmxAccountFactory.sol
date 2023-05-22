// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IEntryPoint } from "@hmx/account-abstraction/interfaces/IEntryPoint.sol";
import { IHmxAccountFactory } from "@hmx/account-abstraction/interfaces/IHmxAccountFactory.sol";
import { HmxAccount } from "@hmx/account-abstraction/HmxAccount.sol";

/**
 * A HMX factory contract for HMX Account.
 * This factory is based from SimpleAccount factory implementation.
 * With following changes:
 * - HmxAccount is used instead of SimpleAccount
 * - Keeps track of account owner
 * - Allows HmxAccountFactory's owner to upgrade HmxAccount implementation
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract HmxAccountFactory is Ownable, IHmxAccountFactory {
  HmxAccount public immutable accountImplementation;
  mapping(address => bool) public isAllowedDest;
  mapping(address => address) public ownerOf;

  event SetIsAllowedDest(address indexed dest, bool prevIsAllowed, bool isAllowed);

  constructor(IEntryPoint _entryPoint) {
    accountImplementation = new HmxAccount(_entryPoint);
  }

  /**
   * create an account, and return its address.
   * returns the address even if the account is already deployed.
   * Note that during UserOperation execution, this method is called only if the account is not deployed.
   * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
   */
  function createAccount(address _owner, uint256 salt) external returns (HmxAccount ret) {
    address addr = getAddress(_owner, salt);
    uint codeSize = addr.code.length;
    if (codeSize > 0) {
      return HmxAccount(payable(addr));
    }
    ret = HmxAccount(
      payable(
        new ERC1967Proxy{ salt: bytes32(salt) }(
          address(accountImplementation),
          abi.encodeCall(HmxAccount.initialize, (_owner))
        )
      )
    );
    ownerOf[address(ret)] = _owner;
  }

  /**
   * set whether an account is allowed to call the destination.
   */
  function setIsAllowedDest(address _dest, bool _isAllowed) external onlyOwner {
    emit SetIsAllowedDest(_dest, isAllowedDest[_dest], _isAllowed);
    isAllowedDest[_dest] = _isAllowed;
  }

  /**
   * allow factory to upgrade the account implementation
   */
  function upgrade(UUPSUpgradeable[] calldata _accounts, address _newAccountImplementation) external onlyOwner {
    for (uint256 i = 0; i < _accounts.length; i++) {
      _accounts[i].upgradeTo(_newAccountImplementation);
    }
  }

  /**
   * calculate the counterfactual address of this account as it would be returned by createAccount()
   */
  function getAddress(address _owner, uint256 salt) public view returns (address) {
    return
      Create2.computeAddress(
        bytes32(salt),
        keccak256(
          abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(accountImplementation), abi.encodeCall(HmxAccount.initialize, (_owner)))
          )
        )
      );
  }
}
