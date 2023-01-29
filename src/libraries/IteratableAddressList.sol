// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

library IteratableAddressList {
  error IteratableAddressList_Existed();
  error IteratableAddressList_NotExisted();
  error IteratableAddressList_NotInitialized();
  error IteratableAddressList_WrongPrev();

  address internal constant START = address(1);
  address internal constant END = address(1);
  address internal constant EMPTY = address(0);

  struct List {
    uint256 size;
    mapping(address => address) next;
  }

  function init(List storage list) internal returns (List storage) {
    list.next[START] = END;
    return list;
  }

  function has(List storage list, address addr) internal view returns (bool) {
    return list.next[addr] != EMPTY;
  }

  function add(List storage list, address addr) internal returns (List storage) {
    // Check
    if (has(list, addr)) revert IteratableAddressList_Existed();

    // Effect
    list.next[addr] = list.next[START];
    list.next[START] = addr;
    list.size++;

    return list;
  }

  function remove(List storage list, address addr, address prevAddr)
    internal
    returns (List storage)
  {
    // Check
    if (!has(list, addr)) revert IteratableAddressList_NotExisted();
    if (list.next[prevAddr] != addr) revert IteratableAddressList_WrongPrev();

    // Effect
    list.next[prevAddr] = list.next[addr];
    list.next[addr] = EMPTY;
    list.size--;

    return list;
  }

  function getAll(List storage list) internal view returns (address[] memory) {
    address[] memory addrs = new address[](list.size);
    address curr = list.next[START];
    for (uint256 i = 0; curr != END; i++) {
      addrs[i] = curr;
      curr = list.next[curr];
    }
    return addrs;
  }

  function getPreviousOf(List storage list, address addr)
    internal
    view
    returns (address)
  {
    address curr = list.next[START];
    if (curr == EMPTY) revert IteratableAddressList_NotInitialized();
    for (uint256 i = 0; curr != END; i++) {
      if (list.next[curr] == addr) return curr;
      curr = list.next[curr];
    }
    return END;
  }

  function getNextOf(List storage list, address curr)
    internal
    view
    returns (address)
  {
    return list.next[curr];
  }

  function length(List storage list) internal view returns (uint256) {
    return list.size;
  }
}
