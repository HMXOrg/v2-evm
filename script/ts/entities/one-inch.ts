import dotenv from "dotenv";

dotenv.config();

if (process.env.ONE_INCH_URL === undefined) {
  throw new Error("Missing ONE_INCH_URL env var");
}
if (process.env.ONE_INCH_API_KEY === undefined) {
  throw new Error("Missing ONE_INCH_API_KEY env var");
}

export default {
  baseUrl: process.env.ONE_INCH_URL,
  apiKey: process.env.ONE_INCH_API_KEY,
};
