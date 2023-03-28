// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

import { LeanPyth } from "@hmx/oracle/LeanPyth.sol";
import { IPyth } from "@hmx/oracle/interfaces/IPyth.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";

import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";

// Command:
// forge test --fork-url https://aged-white-wind.arbitrum-mainnet.quiknode.pro/74ec5b20e4a4db94467209283c9b2ebcf9e1f95d/ --block-number 74124019 --match-contract LeanPyth_Verification

contract LeanPyth_Verification is TestBase, StdAssertions, StdCheatsSafe {
  using stdJson for string;
  LeanPyth leanPyth;

  uint256 arbitrumForkId;

  event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf);

  event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf, bytes encodedVm);

  function setUp() public {
    arbitrumForkId = vm.createSelectFork(vm.rpcUrl("arbitrum_fork"), 74124019);

    // Pyth on Arbitrum
    address _pyth = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;

    leanPyth = new LeanPyth(IPyth(_pyth));
    leanPyth.setUpdater(address(this), true);
  }

  function testCorrectness_FeedSuccess_VerifySuccess_AndCorrectlyGetPrice() external {
    /**
     * Creating data.json
     *
     * 1. Fetch VAA data from following url
     * https://xc-mainnet.pyth.network/api/latest_price_feeds?ids[0]=ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace&ids[1]=e6ccd3f878cf338e6732bf59f60943e8ca2c28402fc4d9c258503b2edbe74a31&ids[2]=ef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52&ids[3]=b5d0e0fa58a1f8b81498ae670ce93c872d14434b72c364885d4fa1b257cbb07a&verbose=true&binary=true
     * See data.json.
     * 2. Convert those base64 VAA to hex using this website.
     * https://base64.guru/converter/decode/hex
     * 3. Store the hex in `vaa_hex` in data.json.
     * 4. Convert `price.price`, `price.conf` from string to integer. (remove ")
     *
     * The content in the data.json are the following assets.
     *
     * 0: Crypto.ETH/USD
     * 1: Crypto.LUNA/USD
     * 2: FX.USD/JPY
     * 3: Equity.US.AMZN/USD
     */

    string memory json = vm.readFile("./test/fork/data.json");

    bytes[] memory _vaas = new bytes[](4);
    {
      bytes memory _vaa0 = abi.decode(json.parseRaw("[0].vaa_hex"), (bytes)); // Crypto.ETH/USD
      bytes memory _vaa1 = abi.decode(json.parseRaw("[1].vaa_hex"), (bytes)); // Crypto.LUNA/USD
      bytes memory _vaa2 = abi.decode(json.parseRaw("[2].vaa_hex"), (bytes)); // FX.USD/JPY
      bytes memory _vaa3 = abi.decode(json.parseRaw("[3].vaa_hex"), (bytes)); // Equity.US.AMZN/USD

      _vaas[0] = _vaa0;
      _vaas[1] = _vaa1;
      _vaas[2] = _vaa2;
      _vaas[3] = _vaa3;
    }

    // Asset ids
    bytes32 _ethUsdAssetId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 _lunaUsdAssetId = 0xe6ccd3f878cf338e6732bf59f60943e8ca2c28402fc4d9c258503b2edbe74a31;
    bytes32 _usdJpyAssetId = 0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52;
    bytes32 _amznUsdAssetId = 0xb5d0e0fa58a1f8b81498ae670ce93c872d14434b72c364885d4fa1b257cbb07a;

    // 1. Try get price. It should revert as we never feed before.
    {
      vm.expectRevert(abi.encodeWithSignature("LeanPyth_PriceFeedNotFound()"));
      leanPyth.getPriceUnsafe(_ethUsdAssetId);
    }

    // 2. Feed price. It should be successful.
    {
      vm.expectEmit(false, false, false, true, address(leanPyth));
      emit PriceFeedUpdate(
        _ethUsdAssetId,
        abi.decode(json.parseRaw("[0].price.publish_time"), (uint64)),
        abi.decode(json.parseRaw("[0].price.price"), (int64)),
        abi.decode(json.parseRaw("[0].price.conf"), (uint64)),
        _vaas[0]
      );

      vm.expectEmit(false, false, false, true, address(leanPyth));
      emit PriceFeedUpdate(
        _lunaUsdAssetId,
        abi.decode(json.parseRaw("[1].price.publish_time"), (uint64)),
        abi.decode(json.parseRaw("[1].price.price"), (int64)),
        abi.decode(json.parseRaw("[1].price.conf"), (uint64)),
        _vaas[1]
      );

      vm.expectEmit(false, false, false, true, address(leanPyth));
      emit PriceFeedUpdate(
        _usdJpyAssetId,
        abi.decode(json.parseRaw("[2].price.publish_time"), (uint64)),
        abi.decode(json.parseRaw("[2].price.price"), (int64)),
        abi.decode(json.parseRaw("[2].price.conf"), (uint64)),
        _vaas[2]
      );

      vm.expectEmit(false, false, false, true, address(leanPyth));
      emit PriceFeedUpdate(
        _amznUsdAssetId,
        abi.decode(json.parseRaw("[3].price.publish_time"), (uint64)),
        abi.decode(json.parseRaw("[3].price.price"), (int64)),
        abi.decode(json.parseRaw("[3].price.conf"), (uint64)),
        _vaas[3]
      );

      leanPyth.updatePriceFeeds{ value: leanPyth.getUpdateFee(_vaas) }(_vaas);
    }

    // 3. Try verify. It should be successful. These VAA are also emitted from `.updatePriceFeeds()`.
    {
      leanPyth.verifyVaa(_vaas[0]);
      leanPyth.verifyVaa(_vaas[1]);
      leanPyth.verifyVaa(_vaas[2]);
      leanPyth.verifyVaa(_vaas[3]);
    }

    // 4. Try get price. It should be successful now. Price value should be as fed.
    {
      PythStructs.Price memory _price = leanPyth.getPriceUnsafe(_ethUsdAssetId);
      assertEq(_price.price, abi.decode(json.parseRaw("[0].price.price"), (int64)), "ETH price");
      assertEq(_price.conf, abi.decode(json.parseRaw("[0].price.conf"), (uint64)), "ETH conf");
      assertEq(_price.expo, abi.decode(json.parseRaw("[0].price.expo"), (int64)), "ETH expo");
      assertEq(_price.publishTime, abi.decode(json.parseRaw("[0].price.publish_time"), (uint64)), "ETH publish time");
    }
    {
      PythStructs.Price memory _price = leanPyth.getPriceUnsafe(_lunaUsdAssetId);
      assertEq(_price.price, abi.decode(json.parseRaw("[1].price.price"), (int64)), "LUNA price");
      assertEq(_price.conf, abi.decode(json.parseRaw("[1].price.conf"), (uint64)), "LUNA conf");
      assertEq(_price.expo, abi.decode(json.parseRaw("[1].price.expo"), (int64)), "LUNA expo");
      assertEq(_price.publishTime, abi.decode(json.parseRaw("[1].price.publish_time"), (uint64)), "LUNA publish time");
    }
    {
      PythStructs.Price memory _price = leanPyth.getPriceUnsafe(_usdJpyAssetId);
      assertEq(_price.price, abi.decode(json.parseRaw("[2].price.price"), (int64)), "JPY price");
      assertEq(_price.conf, abi.decode(json.parseRaw("[2].price.conf"), (uint64)), "JPY conf");
      assertEq(_price.expo, abi.decode(json.parseRaw("[2].price.expo"), (int64)), "JPY expo");
      assertEq(_price.publishTime, abi.decode(json.parseRaw("[2].price.publish_time"), (uint64)), "JPY publish time");
    }
    {
      PythStructs.Price memory _price = leanPyth.getPriceUnsafe(_amznUsdAssetId);
      assertEq(_price.price, abi.decode(json.parseRaw("[3].price.price"), (int64)), "AMZN price");
      assertEq(_price.conf, abi.decode(json.parseRaw("[3].price.conf"), (uint64)), "AMZN conf");
      assertEq(_price.expo, abi.decode(json.parseRaw("[3].price.expo"), (int64)), "AMZN expo");
      assertEq(_price.publishTime, abi.decode(json.parseRaw("[3].price.publish_time"), (uint64)), "AMZN publish time");
    }
  }
}
