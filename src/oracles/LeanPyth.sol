// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { PythStructs, IPythEvents } from "lib/pyth-sdk-solidity/IPyth.sol";
import { PythErrors } from "lib/pyth-sdk-solidity/PythErrors.sol";
import { ILeanPyth } from "./interfaces/ILeanPyth.sol";
import { IPyth, IPythPriceInfo, IPythDataSource } from "./interfaces/IPyth.sol";
import { IWormHole } from "./interfaces/IWormHole.sol";
import "./UnsafeBytesLib.sol";

contract LeanPyth is OwnableUpgradeable, ILeanPyth {
  // errors
  error LeanPyth_ExpectZeroFee();
  error LeanPyth_OnlyUpdater();
  error LeanPyth_PriceFeedNotFound();
  error LeanPyth_InvalidWormholeVaa();
  error LeanPyth_InvalidUpdateDataSource();

  IPyth public pyth;

  // mapping of our asset id to Pyth's price id
  mapping(bytes32 => IPythPriceInfo) public priceInfos;

  // whitelist mapping of price updater
  mapping(address => bool) public isUpdaters;

  // events
  event LogSetUpdater(address indexed _account, bool _isActive);
  event LogSetPyth(address _oldPyth, address _newPyth);

  /**
   * Modifiers
   */
  modifier onlyUpdater() {
    if (!isUpdaters[msg.sender]) {
      revert LeanPyth_OnlyUpdater();
    }
    _;
  }

  function initialize(IPyth _pyth) external initializer {
    OwnableUpgradeable.__Ownable_init();

    pyth = _pyth;

    // Sanity
    IPyth(pyth).wormhole();
  }

  /// @dev Updates the price feeds with the given price data.
  /// @notice The function must not be called with any msg.value. (Define as payable for IPyth compatability)
  /// @param updateData The array of encoded price feeds to update.
  function updatePriceFeeds(bytes[] calldata updateData) external payable override onlyUpdater {
    // The function is payable (to make it IPyth compat), so there is a chance msg.value is submitted.
    // On LeanPyth, we do not collect any fee.
    if (msg.value > 0) revert LeanPyth_ExpectZeroFee();

    // Loop through all of the price data
    for (uint i = 0; i < updateData.length; ) {
      _updatePriceBatchFromVm(updateData[i]);

      unchecked {
        ++i;
      }
    }
  }

  /// @dev Returns the current price for the given price feed ID. Revert if price never got fed.
  /// @param id The unique identifier of the price feed.
  /// @return price The current price.
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
    IPythPriceInfo storage priceInfo = priceInfos[id];
    if (priceInfo.publishTime == 0) revert LeanPyth_PriceFeedNotFound();

    price.publishTime = priceInfo.publishTime;
    price.expo = priceInfo.expo;
    price.price = priceInfo.price;
    price.conf = priceInfo.conf;
    return price;
  }

  /// @dev Returns the update fee for the given price feed update data.
  /// @return feeAmount The update fee, which is always 0.
  function getUpdateFee(bytes[] calldata /*updateData*/) external pure returns (uint feeAmount) {
    // The update fee is always 0, so simply return 0
    return 0;
  }

  /// @dev Sets the `isActive` status of the given account as a price updater.
  /// @param _account The account address to update.
  /// @param _isActive The new status of the account as a price updater.
  function setUpdater(address _account, bool _isActive) external onlyOwner {
    // Set the `isActive` status of the given account
    isUpdaters[_account] = _isActive;

    // Emit a `LogSetUpdater` event indicating the updated status of the account
    emit LogSetUpdater(_account, _isActive);
  }

  /// @notice Set Pyth address.
  /// @param _newPyth The Pyth address to set.
  function setPyth(address _newPyth) external onlyOwner {
    emit LogSetPyth(address(pyth), _newPyth);

    // Sanity
    IPyth(_newPyth).wormhole();

    pyth = IPyth(_newPyth);
  }

  /// @dev Verifies the validity of a VAA encoded in hexadecimal format.
  /// @param _vaaInHex The hexadecimal encoded VAA to be verified.
  /// @notice revert LeanPyth_InvalidWormholeVaa if the VAA is not valid.
  /// @notice revert LeanPyth_InvalidUpdateDataSource if the VAA's emitter chain ID and address combination is not a valid data source.
  function verifyVaa(bytes memory _vaaInHex) external view {
    IWormHole wormHole = IWormHole(pyth.wormhole());
    (IWormHole.VM memory vm, bool valid, ) = wormHole.parseAndVerifyVM(_vaaInHex);

    if (!valid) revert LeanPyth_InvalidWormholeVaa();

    if (!pyth.isValidDataSource(vm.emitterChainId, vm.emitterAddress)) revert LeanPyth_InvalidUpdateDataSource();
  }

  function _updatePriceBatchFromVm(bytes calldata encodedVm) private {
    // Main difference from original Pyth is here, `.parseVM()` vs `.parseAndVerifyVM()`.
    // On LeanPyth, we skip vaa verification to save gas.
    IWormHole.VM memory vm = IWormHole(pyth.wormhole()).parseVM(encodedVm);
    _parseAndProcessBatchPriceAttestation(vm, encodedVm);
  }

  function _parseAndProcessBatchPriceAttestation(IWormHole.VM memory vm, bytes calldata encodedVm) internal {
    // Most of the math operations below are simple additions.
    // In the places that there is more complex operation there is
    // a comment explaining why it is safe. Also, byteslib
    // operations have proper require.
    unchecked {
      bytes memory encoded = vm.payload;

      (uint index, uint nAttestations, uint attestationSize) = _parseBatchAttestationHeader(encoded);

      // Deserialize each attestation
      for (uint j = 0; j < nAttestations; j++) {
        (IPythPriceInfo memory info, bytes32 priceId) = _parseSingleAttestationFromBatch(
          encoded,
          index,
          attestationSize
        );

        // Respect specified attestation size for forward-compat
        index += attestationSize;

        // Store the attestation
        uint64 latestPublishTime = priceInfos[priceId].publishTime;

        if (info.publishTime > latestPublishTime) {
          priceInfos[priceId] = info;

          emit PriceFeedUpdate(
            priceId,
            info.publishTime,
            info.price,
            info.conf,
            // User can use this data to verify data integrity via .verifyVaa()
            encodedVm
          );
        }
      }

      emit BatchPriceFeedUpdate(vm.emitterChainId, vm.sequence);
    }
  }

  function _parseBatchAttestationHeader(
    bytes memory encoded
  ) internal pure returns (uint index, uint nAttestations, uint attestationSize) {
    unchecked {
      index = 0;

      // Check header
      {
        uint32 magic = UnsafeBytesLib.toUint32(encoded, index);
        index += 4;
        if (magic != 0x50325748) revert PythErrors.InvalidUpdateData();

        uint16 versionMajor = UnsafeBytesLib.toUint16(encoded, index);
        index += 2;
        if (versionMajor != 3) revert PythErrors.InvalidUpdateData();

        // This value is only used as the check below which currently
        // never reverts
        // uint16 versionMinor = UnsafeBytesLib.toUint16(encoded, index);
        index += 2;

        // This check is always false as versionMinor is 0, so it is commented.
        // in the future that the minor version increases this will have effect.
        // if(versionMinor < 0) revert InvalidUpdateData();

        uint16 hdrSize = UnsafeBytesLib.toUint16(encoded, index);
        index += 2;

        // NOTE(2022-04-19): Currently, only payloadId comes after
        // hdrSize. Future extra header fields must be read using a
        // separate offset to respect hdrSize, i.e.:
        //
        // uint hdrIndex = 0;
        // bpa.header.payloadId = UnsafeBytesLib.toUint8(encoded, index + hdrIndex);
        // hdrIndex += 1;
        //
        // bpa.header.someNewField = UnsafeBytesLib.toUint32(encoded, index + hdrIndex);
        // hdrIndex += 4;
        //
        // // Skip remaining unknown header bytes
        // index += bpa.header.hdrSize;

        uint8 payloadId = UnsafeBytesLib.toUint8(encoded, index);

        // Skip remaining unknown header bytes
        index += hdrSize;

        // Payload ID of 2 required for batch headerBa
        if (payloadId != 2) revert PythErrors.InvalidUpdateData();
      }

      // Parse the number of attestations
      nAttestations = UnsafeBytesLib.toUint16(encoded, index);
      index += 2;

      // Parse the attestation size
      attestationSize = UnsafeBytesLib.toUint16(encoded, index);
      index += 2;

      // Given the message is valid the arithmetic below should not overflow, and
      // even if it overflows then the require would fail.
      if (encoded.length != (index + (attestationSize * nAttestations))) revert PythErrors.InvalidUpdateData();
    }
  }

  function _parseSingleAttestationFromBatch(
    bytes memory encoded,
    uint index,
    uint attestationSize
  ) internal pure returns (IPythPriceInfo memory info, bytes32 priceId) {
    unchecked {
      // NOTE: We don't advance the global index immediately.
      // attestationIndex is an attestation-local offset used
      // for readability and easier debugging.
      uint attestationIndex = 0;

      // Unused bytes32 product id
      attestationIndex += 32;

      priceId = UnsafeBytesLib.toBytes32(encoded, index + attestationIndex);
      attestationIndex += 32;

      info.price = int64(UnsafeBytesLib.toUint64(encoded, index + attestationIndex));
      attestationIndex += 8;

      info.conf = UnsafeBytesLib.toUint64(encoded, index + attestationIndex);
      attestationIndex += 8;

      info.expo = int32(UnsafeBytesLib.toUint32(encoded, index + attestationIndex));
      attestationIndex += 4;

      info.emaPrice = int64(UnsafeBytesLib.toUint64(encoded, index + attestationIndex));
      attestationIndex += 8;

      info.emaConf = UnsafeBytesLib.toUint64(encoded, index + attestationIndex);
      attestationIndex += 8;

      {
        // Status is an enum (encoded as uint8) with the following values:
        // 0 = UNKNOWN: The price feed is not currently updating for an unknown reason.
        // 1 = TRADING: The price feed is updating as expected.
        // 2 = HALTED: The price feed is not currently updating because trading in the product has been halted.
        // 3 = AUCTION: The price feed is not currently updating because an auction is setting the price.
        uint8 status = UnsafeBytesLib.toUint8(encoded, index + attestationIndex);
        attestationIndex += 1;

        // Unused uint32 numPublishers
        attestationIndex += 4;

        // Unused uint32 numPublishers
        attestationIndex += 4;

        // Unused uint64 attestationTime
        attestationIndex += 8;

        info.publishTime = UnsafeBytesLib.toUint64(encoded, index + attestationIndex);
        attestationIndex += 8;

        if (status == 1) {
          // status == TRADING
          attestationIndex += 24;
        } else {
          // If status is not trading then the latest available price is
          // the previous price info that are passed here.

          // Previous publish time
          info.publishTime = UnsafeBytesLib.toUint64(encoded, index + attestationIndex);
          attestationIndex += 8;

          // Previous price
          info.price = int64(UnsafeBytesLib.toUint64(encoded, index + attestationIndex));
          attestationIndex += 8;

          // Previous confidence
          info.conf = UnsafeBytesLib.toUint64(encoded, index + attestationIndex);
          attestationIndex += 8;
        }
      }

      if (attestationIndex > attestationSize) revert PythErrors.InvalidUpdateData();
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
