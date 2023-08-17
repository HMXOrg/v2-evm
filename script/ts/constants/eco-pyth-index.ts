import { ethers } from "ethers";

// DO NOT CHANGE THE ORDER OF THE INDEXES
export const ecoPythPriceFeedIdsByIndex = [
  "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace", // ETHUSD
  "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43", // BTCUSD
  "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a", // USDCUSD
  "0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b", // USDTUSD
  "0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd", // DAIUSD
  "0x49f6b65cb1de6b10eaf75e7c03ca029c306d0357e91b5311b175084a5ad55688", // AAPLUSD
  "0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52", // JPYUSD
  "0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2", // XAUUSD
  "0xb5d0e0fa58a1f8b81498ae670ce93c872d14434b72c364885d4fa1b257cbb07a", // AMZNUSD
  "0xd0ca23c1cc005e004ccf1db5bf76aeb6a49218f43dac3d4b275e92de12ded4d1", // MSFTUSD
  "0x16dad506d7db8da01c87581c87ca897a012a153557d4d578c3b9c9e1bc0632f1", // TSLAUSD
  "0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b", // EURUSD
  "0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e", // XAGUSD
  "GLP", // GLP
  "0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80", // AUDUSD
  "0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1", // GBPUSD
  "0x2a01deaec9e51a579277b34b122399984d0bbf57e2458a7e42fecd2829867a0d", // ADAUSD
  "0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52", // MATICUSD
  "0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744", // SUIUSD
  "0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5", // ARBUSD
  "0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf", // OPUSD
  "0x6e3f3fa8253588df9326580180233eb791e03b443a3ba7a1d892e73874e19a54", // LTCUSD
  "0xfee33f2a978bf32dd6b662b65ba8083c6773b494f8401194ec1870c640860245", // COINUSD
  "0xe65ff435be42630439c96396653a342829e877e2aafaeaf1a10d0ee5fd2cf3f2", // GOOGUSD
  "0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f", // BNBUSD
  "0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d", // SOLUSD
  "0x9695e2b96ea7b3859da9ed25b7a46a920a776e2fdae19a7bcfdf2b219230452d", // QQQUSD
  "0xec5d399846a9209f3fe5881d70aae9268c94339ff9817e8d18ff19fa05eea1c8", // XRPUSD
  "0xb1073854ed24cbc755dc527418f52b7d271f6cc967bbf8d8129112b18860a593", // NVDA
  "0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221", // LINK
  "0x0b1e3297e69f162877b577b0d6a47a0d63b2392bc8499e6540da4187a63e28f8", // CHF
];
export const ecoPythAssetIdByIndex = [
  "0x4554480000000000000000000000000000000000000000000000000000000000", // ETH
  "0x4254430000000000000000000000000000000000000000000000000000000000", // BTC
  "0x5553444300000000000000000000000000000000000000000000000000000000", // USDC
  "0x5553445400000000000000000000000000000000000000000000000000000000", // USDT
  "0x4441490000000000000000000000000000000000000000000000000000000000", // DAI
  "0x4141504c00000000000000000000000000000000000000000000000000000000", // AAPL
  "0x4a50590000000000000000000000000000000000000000000000000000000000", // JPY
  "0x5841550000000000000000000000000000000000000000000000000000000000", // XAU
  "0x414d5a4e00000000000000000000000000000000000000000000000000000000", // AMZN
  "0x4d53465400000000000000000000000000000000000000000000000000000000", // MSFT
  "0x54534c4100000000000000000000000000000000000000000000000000000000", // TSLA
  "0x4555520000000000000000000000000000000000000000000000000000000000", // EUR
  "0x5841470000000000000000000000000000000000000000000000000000000000", // XAG
  "0x474c500000000000000000000000000000000000000000000000000000000000", // GLP
  ethers.utils.formatBytes32String("AUD"),
  ethers.utils.formatBytes32String("GBP"),
  ethers.utils.formatBytes32String("ADA"),
  ethers.utils.formatBytes32String("MATIC"),
  ethers.utils.formatBytes32String("SUI"),
  ethers.utils.formatBytes32String("ARB"),
  ethers.utils.formatBytes32String("OP"),
  ethers.utils.formatBytes32String("LTC"),
  ethers.utils.formatBytes32String("COIN"),
  ethers.utils.formatBytes32String("GOOG"),
  ethers.utils.formatBytes32String("BNB"),
  ethers.utils.formatBytes32String("SOL"),
  ethers.utils.formatBytes32String("QQQ"),
  ethers.utils.formatBytes32String("XRP"),
  ethers.utils.formatBytes32String("NVDA"),
  ethers.utils.formatBytes32String("LINK"),
  ethers.utils.formatBytes32String("CHF"),
];
export const ecoPythHoomanReadableByIndex = [
  "ETH",
  "BTC",
  "USDC",
  "USDT",
  "DAI",
  "AAPL",
  "JPY",
  "XAU",
  "AMZN",
  "MSFT",
  "TSLA",
  "EUR",
  "XAG",
  "GLP",
  "AUD",
  "GBP",
  "ADA",
  "MATIC",
  "SUI",
  "ARB",
  "OP",
  "LTC",
  "COIN",
  "GOOG",
  "BNB",
  "SOL",
  "QQQ",
  "XRP",
  "NVDA",
  "LINK",
  "CHF",
];
