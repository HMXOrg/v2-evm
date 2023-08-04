import { jsonToGraphQLQuery } from "json-to-graphql-query";
import { SubAccountStat } from "./type";
import axios from "axios";

export class StatSubgraphWrapper {
  baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  private async sendRequest(query: string, options: any = {}) {
    const res = await axios({
      url: this.baseUrl,
      method: "POST",
      data: {
        query,
      },
    });
    const { data } = await res.data;
    return data || {};
  }

  async getSubAccountStats(): Promise<Array<SubAccountStat>> {
    const query = `
      query { subAccountStats (first: 10000) {
        id,
        primaryAccount,
        subAccount,
        subAccountId,
        tradingFeePaid,
        borrowingFeePaid,
        liquidationFeePaid,
        fundingFeePaid,
        fundingFeeReceived,
        totalFeesPaid,
        totalFeesReceived,
        accumulatedPnl
      } }
    `;
    const data = await this.sendRequest(query);
    return data.subAccountStats as Array<SubAccountStat>;
  }
}
