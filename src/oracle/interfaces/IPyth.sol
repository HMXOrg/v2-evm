// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPyth {
  struct PriceInfo {
    // slot 1
    uint64 publishTime;
    int32 expo;
    int64 price;
    uint64 conf;
    // slot 2
    int64 emaPrice;
    uint64 emaConf;
  }

  struct DataSource {
    uint16 chainId;
    bytes32 emitterAddress;
  }

  function wormhole() external view returns (address);

  function isValidDataSource(uint16 dataSourceChainId, bytes32 dataSourceEmitterAddress) external view returns (bool);
}
