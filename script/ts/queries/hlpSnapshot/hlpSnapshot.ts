import { BigNumber, ethers } from "ethers";
import fs from "fs";
import csv from "csv-parser";
import MultiCall from "@indexed-finance/multicall";

interface CSVResult {
  user: string;
}

interface HLPBalance {
  user: string;
  balance: string;
}

interface Transaction {
  interface: any;
  target: string;
  function: any;
  args: any;
}

const FILE = "script/ts/queries/hlpSnapshot/data/StakedHlpUser.csv";
const ABI = require("./data/HLPStakingABI.json");
const ADDRESS = "0xbE8f8AF5953869222eA8D39F1Be9d03766010B1C";
const provider = new ethers.providers.JsonRpcProvider(
  "https://aged-white-wind.arbitrum-mainnet.quiknode.pro/74ec5b20e4a4db94467209283c9b2ebcf9e1f95d"
);
const multicall = new MultiCall(provider);

async function getUserTokenAmount(wallets: CSVResult[]): Promise<any> {
  const calls: Transaction[] = [];
  let i = 0;
  let j = 0;
  const res: HLPBalance[] = [];
  for (const obj of wallets) {
    if (i < 50) {
      calls.push({
        interface: ABI,
        target: ADDRESS,
        function: "userTokenAmount",
        args: [obj.user],
      } as Transaction);
      i++;
    } else {
      i = 0;
      const [, amounts] = await multicall.multiCall(calls as any);
      for (const amount of amounts) {
        res.push({
          user: wallets[j].user,
          balance: amount.toString(),
        } as HLPBalance);
        j++;
      }
      calls.splice(0);
      calls.push({
        interface: ABI,
        target: ADDRESS,
        function: "userTokenAmount",
        args: [obj.user],
      } as Transaction);
    }
  }
  return res;
}

async function readCSVFile(FILE_PATH: string): Promise<object[]> {
  const results: object[] = [];
  return new Promise((resolve, reject) => {
    fs.createReadStream(FILE_PATH)
      .pipe(csv())
      .on("data", (data: CSVResult) => results.push(data))
      .on("end", () => resolve(results))
      .on("error", (error) => reject(error));
  });
}

readCSVFile(FILE)
  .then((data) => {
    const configData = data as CSVResult[];
    getUserTokenAmount(configData).then((res) => {
      fs.writeFile("script/ts/queries/hlpSnapshot/out/HlpSnapshot.json", JSON.stringify(res), function (err) {
        if (err) {
          console.log(err);
        }
      });
    });
  })
  .catch((err) => {
    console.error(err);
  });
