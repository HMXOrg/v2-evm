// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICrossMarginHandler {
  /**
   * Errors
   */
  error ICrossMarginHandler_InvalidAddress();
  error ICrossMarginHandler_MismatchMsgValue();

  function depositCollateral(uint8 _subAccountId, address _token, uint256 _amount, bool _shouldWrap) external payable;

  function withdrawCollateral(
    uint8 _subAccountId,
    address _token,
    uint256 _amount,
    bytes[] memory _priceData,
    bool _shouldUnwrap
  ) external payable;

  function crossMarginService() external returns (address);

  function pyth() external returns (address);

  function setCrossMarginService(address _address) external;

  function setPyth(address _address) external;
}
