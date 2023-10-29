// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IGmxV2Types {
  struct DepositAddresses {
    address account;
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address initialLongToken;
    address initialShortToken;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
  }

  struct DepositNumbers {
    uint256 initialLongTokenAmount;
    uint256 initialShortTokenAmount;
    uint256 minMarketTokens;
    uint256 updatedAtBlock;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }

  struct DepositFlags {
    bool shouldUnwrapNativeToken;
  }

  struct DepositProps {
    DepositAddresses addresses;
    DepositNumbers numbers;
    DepositFlags flags;
  }

  struct EventAddressItems {
    EventAddressKeyValue[] items;
    EventAddressArrayKeyValue[] arrayItems;
  }

  struct EventUintItems {
    EventUintKeyValue[] items;
    EventUintArrayKeyValue[] arrayItems;
  }

  struct EventIntItems {
    EventIntKeyValue[] items;
    EventIntArrayKeyValue[] arrayItems;
  }

  struct EventBoolItems {
    EventBoolKeyValue[] items;
    EventBoolArrayKeyValue[] arrayItems;
  }

  struct EventBytes32Items {
    EventBytes32KeyValue[] items;
    EventBytes32ArrayKeyValue[] arrayItems;
  }

  struct EventBytesItems {
    EventBytesKeyValue[] items;
    EventBytesArrayKeyValue[] arrayItems;
  }

  struct EventStringItems {
    EventStringKeyValue[] items;
    EventStringArrayKeyValue[] arrayItems;
  }

  struct EventAddressKeyValue {
    string key;
    address value;
  }

  struct EventAddressArrayKeyValue {
    string key;
    address[] value;
  }

  struct EventUintKeyValue {
    string key;
    uint256 value;
  }

  struct EventUintArrayKeyValue {
    string key;
    uint256[] value;
  }

  struct EventIntKeyValue {
    string key;
    int256 value;
  }

  struct EventIntArrayKeyValue {
    string key;
    int256[] value;
  }

  struct EventBoolKeyValue {
    string key;
    bool value;
  }

  struct EventBoolArrayKeyValue {
    string key;
    bool[] value;
  }

  struct EventBytes32KeyValue {
    string key;
    bytes32 value;
  }

  struct EventBytes32ArrayKeyValue {
    string key;
    bytes32[] value;
  }

  struct EventBytesKeyValue {
    string key;
    bytes value;
  }

  struct EventBytesArrayKeyValue {
    string key;
    bytes[] value;
  }

  struct EventStringKeyValue {
    string key;
    string value;
  }

  struct EventStringArrayKeyValue {
    string key;
    string[] value;
  }

  struct EventLogData {
    EventAddressItems addressItems;
    EventUintItems uintItems;
    EventIntItems intItems;
    EventBoolItems boolItems;
    EventBytes32Items bytes32Items;
    EventBytesItems bytesItems;
    EventStringItems stringItems;
  }

  struct MarketProps {
    address marketToken;
    address indexToken;
    address longToken;
    address shortToken;
  }

  struct MarketPoolValueInfoProps {
    int256 poolValue;
    int256 longPnl;
    int256 shortPnl;
    int256 netPnl;
    uint256 longTokenAmount;
    uint256 shortTokenAmount;
    uint256 longTokenUsd;
    uint256 shortTokenUsd;
    uint256 totalBorrowingFees;
    uint256 borrowingFeePoolFactor;
    uint256 impactPoolAmount;
  }

  struct PriceProps {
    uint256 min;
    uint256 max;
  }

  struct WithdrawalAddresses {
    address account;
    address receiver;
    address callbackContract;
    address uiFeeReceiver;
    address market;
    address[] longTokenSwapPath;
    address[] shortTokenSwapPath;
  }

  struct WithdrawalNumbers {
    uint256 marketTokenAmount;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    uint256 updatedAtBlock;
    uint256 executionFee;
    uint256 callbackGasLimit;
  }

  struct WithdrawalFlags {
    bool shouldUnwrapNativeToken;
  }

  struct WithdrawalProps {
    WithdrawalAddresses addresses;
    WithdrawalNumbers numbers;
    WithdrawalFlags flags;
  }
}
