## Overview

### When write
price updater contract -> `EcoPyth.updatePriceFeeds`

### When read
price consumer contract -> `OracleMiddleware.getLatestPrice` -> `PythAdapter.getLatestPrice` -> `EcoPyth.getPriceUnsafe`

#### Deprecated contract
- LeanPyth.sol
- Pyth.sol