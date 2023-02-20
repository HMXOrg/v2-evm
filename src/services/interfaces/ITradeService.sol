// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITradeService {
  // errors
  error ITradeService_MarketIsDelisted();
  error ITradeService_MarketIsClosed();
  error ITradeService_PositionAlreadyClosed();
  error ITradeService_DecreaseTooHighPositionSize();
  error ITradeService_SubAccountEquityIsUnderMMR();
  error ITradeService_TooTinyPosition();

  function configStorage() external view returns (address);

  function perpStorage() external view returns (address);

  function decreasePosition(
    address _account,
    uint256 _subAccountId,
    uint256 _marketIndex,
    uint256 _positionSizeE30ToDecrease
  ) external;
}
