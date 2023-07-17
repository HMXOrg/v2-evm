import csv from "csvtojson";

export async function readCsv(filePath: string): Promise<Array<any>> {
  return await csv().fromFile(filePath);
}
