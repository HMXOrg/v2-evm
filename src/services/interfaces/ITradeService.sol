// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITradeService {
  // errors
  error ITradeService_PositionAlreadyClosed();
  error ITradeService_DecreaseTooHighPositionSize();
  error ITradeService_SubAccountEquityIsUnderMMR();
  error ITradeService_TooTinyPosition();
}
