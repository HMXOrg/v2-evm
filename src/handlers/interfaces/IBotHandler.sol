// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IBotHandler {
  /**
   * Errors
   */
  error IBotHandler_UnauthorizedSender();
  error IBotHandler_InsufficientLiquidity();
  error IBotHandler_InvalidArray();
  error IBotHandler_InvalidPrice();
  error IBotHandler_ReservedValueStillEnough();

  /**
   * States
   */
  function tradeService() external returns (address);

  function positionManagers(address _account) external returns (bool);

  /**
   * Functions
   */
  function checkForceTakeMaxProfit(
    bytes32 _positionIds,
    bytes32[] memory _injectedAssetIds,
    uint256[] memory _injectedPrices
  ) external view returns (bool);

  function forceTakeMaxProfit(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function deleverage(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function deleverages(
    address[] memory _accounts,
    uint8[] memory _subAccountIds,
    uint256[] memory _marketIndexes,
    address[] memory _tpTokens,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function closeDelistedMarketPosition(
    address _account,
    uint8 _subAccountId,
    uint256 _marketIndex,
    address _tpToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function closeDelistedMarketPositions(
    address[] calldata _accounts,
    uint8[] calldata _subAccountIds,
    uint256[] calldata _marketIndexes,
    address[] calldata _tpTokens,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function checkLiquidation(
    address _subAccount,
    bytes32[] memory _injectedAssetIds,
    uint256[] memory _injectedPrices
  ) external view returns (bool);

  function liquidate(
    address _subAccount,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function withdrawFundingFeeSurplus(
    address _stableToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function convertFundingFeeReserve(
    address _stableToken,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external payable;

  function setMultipleMarketStatus(
    bytes32[] memory _assetIds,
    uint8[] memory _statuses,
    bytes32[] memory _priceData,
    bytes32[] memory _publishTimeData,
    uint256 _minPublishTime,
    bytes32 _encodedVaas
  ) external;

  function updateLiquidityEnabled(bool _enabled) external;

  function updateDynamicEnabled(bool _enabled) external;

  function injectTokenToHlpLiquidity(address _token, uint256 _amount) external;

  function injectTokenToFundingFeeReserve(address _token, uint256 _amount) external;

  function setPositionManagers(address[] calldata _addresses, bool _isAllowed) external;

  function setTradeService(address _newAddress) external;

  function removeTokenFromHlpLiquidity(address _token, uint256 _amount) external;
}
