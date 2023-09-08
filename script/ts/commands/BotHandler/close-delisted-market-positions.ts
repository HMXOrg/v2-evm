import { BotHandler__factory } from "../../../../typechain";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import * as readlineSync from "readline-sync";
import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import { getUpdatePriceData } from "../../utils/price";
import signers from "../../entities/signers";
import chains from "../../entities/chains";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const deployer = signers.deployer(chainId);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);

  const chunkSize = 5;

  const accountList = [
    {
      account: "0xAad20A87820b77e6b0272193A35f6E631F04c419",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xC858446E52417B58C2E973CcF13211A571Cc9fEC",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xAad20A87820b77e6b0272193A35f6E631F04c419",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x54d26b2Fc4820773542c2cbE42Dd67Ca9C4b419d",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x84D76E64be483A615E2447cCF3B52e938CB40688",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xe24dA5f6ba54b625BbAFFBd847e475507D4fbBba",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x78aD91E6F47e7697D4b8ADDd73Fba6A7f23A7f5B",
      subAccountId: 0,
      marketIndex: 18,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xe24dA5f6ba54b625BbAFFBd847e475507D4fbBba",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x83347229C4e9bFE42dBEB6Ee472B787cDe154831",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xB4FcDAf6500181866743E8a848373A8B95b46370",
      subAccountId: 1,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x5A7537D3c35487DA6249AE3afd34B214B759dC93",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xFF43F3539A578Bb0bB2fdC7DcaE43F539a755c57",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x38642007BbFBdB4f151BaabFc9cF333085413687",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xFF43F3539A578Bb0bB2fdC7DcaE43F539a755c57",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x7239e9b906A7637B1d34Ff6aA6867A30962741DF",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x374Ca2A780871E5f4227587a44eBBAe857cfda8F",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x2E01188DD5af9e4D490d87cC40aDa03a04624B54",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x71D0189A0BfD5ECe58713f0fC7336179a6aF84F9",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 1,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x9Edb4aEbA2753499d88dC40086a5230182889B52",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xf7f1aE6e7634237C02a2d32b7dE3F653177578a2",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x70598A69C0BCb3890383650a2fE02274B6ccCdA3",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x9c129490015b31908ca4F41e9A16Edc1998eff2c",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x37633c9F778c44e852914c7056cBBBF75323Dfd6",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x3C95981A365206c7D08BcfDc20b26EF45A9bf4b3",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 2,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xCfE7C5Dd5D7306eAc223350a9Da8b4977Facd0B5",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x5fa76b66B112322Ea06b3dDCC96fbb800254b232",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x35822D37ce82bE9785107df56a428a2883F8dd11",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x572E29e12243E9533BCadBBe85055dc25FfA2200",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x572E29e12243E9533BCadBBe85055dc25FfA2200",
      subAccountId: 0,
      marketIndex: 18,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x90d5965CE6e91D9635ab72a473B344391Ea45B24",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xd56618D0cc43b6e820459C8e3D35B259535130B1",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x90d5965CE6e91D9635ab72a473B344391Ea45B24",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xDB611d682cb1ad72fcBACd944a8a6e2606a6d158",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x08EeCEd4A1B957ede5A1c3A0FDDd5453D01a4149",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xf27071c352D1845C101d8181Aa4ea70f8d0d6b68",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x40c152689Ce85111F21121A7140451cA740d4206",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x9FC7ac881A72dd2A0e0D33C5389DaDBC45634140",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
      subAccountId: 2,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xb4cE0c954bB129D8039230F701bb6503dca1Ee8c",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x3C95981A365206c7D08BcfDc20b26EF45A9bf4b3",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x0bA47777592A51AB31702E5De27689a5466e7023",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x9A1e248e49DdFB17C96E737dB440fe3319932664",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x2E01188DD5af9e4D490d87cC40aDa03a04624B54",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x28Ca78be125F95517D1d933c463AFAdE65bdaA52",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x2E01188DD5af9e4D490d87cC40aDa03a04624B54",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x3efcb31757037fA34F5b51b9ae145F1f7b7E3435",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xF28570694A6c9Cd0494955966Ae75Af61abf5a07",
      subAccountId: 0,
      marketIndex: 7,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xfD8c8e6F0a4E2C4ebeD24F3a32D37c0385525c26",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xe4655131A4bAeF0A97bA098Bd9d0723ffdBA270a",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x487DdCE3c82dB9FC37972E3D682F7A1d2dD3070a",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xe4655131A4bAeF0A97bA098Bd9d0723ffdBA270a",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xB03E581C4E55099182360359874Ad09dE4320365",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xbcfB6b29Ef35F2380833C8054E8B58cD591C7AE8",
      subAccountId: 1,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x78bE1E67abD9b262A146403F232dB0dBC73432E3",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x2dae14Df2B09980d18e937166b427819B9e2AC0c",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xbAA38FCb2e28911bF6FC326C3563961Cc73BdebA",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x80D1f0738Ad2D6e28ccc237068261aff027458EC",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x954B6dE2E9C58B0ca7B21e9A048fD0A6CEa6f92C",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x46AB107b3632fc7140E7B2294E5D803774eb9C88",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x69a42364D0dC69c94b2DEb71bdE4db48127399f4",
      subAccountId: 0,
      marketIndex: 18,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x954B6dE2E9C58B0ca7B21e9A048fD0A6CEa6f92C",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x579435914E1d9fC5eAC3Ab6C15Cf6Eb7CBc09669",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x8c11E3Af9c1D8718C40c51D4Ff0958AFcF77fD71",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xA47E21BeFA69F9f0D093749581872faD441984F3",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x579435914E1d9fC5eAC3Ab6C15Cf6Eb7CBc09669",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x84D76E64be483A615E2447cCF3B52e938CB40688",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0x954B6dE2E9C58B0ca7B21e9A048fD0A6CEa6f92C",
      subAccountId: 0,
      marketIndex: 5,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xC858446E52417B58C2E973CcF13211A571Cc9fEC",
      subAccountId: 0,
      marketIndex: 6,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xAad20A87820b77e6b0272193A35f6E631F04c419",
      subAccountId: 0,
      marketIndex: 22,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xC858446E52417B58C2E973CcF13211A571Cc9fEC",
      subAccountId: 0,
      marketIndex: 2,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xAad20A87820b77e6b0272193A35f6E631F04c419",
      subAccountId: 0,
      marketIndex: 24,
      tpToken: config.tokens.usdc,
    },
    {
      account: "0xAad20A87820b77e6b0272193A35f6E631F04c419",
      subAccountId: 0,
      marketIndex: 19,
      tpToken: config.tokens.usdc,
    },
  ];

  console.log("[cmds/BotHandler] Closing positions...");
  const iterations = Math.ceil(accountList.length / chunkSize);
  for (let i = 0; i <= iterations; i++) {
    const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
      await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
    const spliced = accountList.splice(0, chunkSize);
    if (spliced.length > 0) {
      const tx = await (
        await botHandler.closeDelistedMarketPositions(
          spliced.map((each) => each.account),
          spliced.map((each) => each.subAccountId),
          spliced.map((each) => each.marketIndex),
          spliced.map((each) => each.tpToken),
          priceUpdateData,
          publishTimeDiffUpdateData,
          minPublishedTime,
          hashedVaas
        )
      ).wait();

      console.log(`[cmds/BotHandler] Done: ${tx.transactionHash}`);
    }
  }
  console.log("[cmds/BotHandler] Close delisted positions success!");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
