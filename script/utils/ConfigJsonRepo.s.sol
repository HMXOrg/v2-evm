// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// @title ConfigJsonRepo is abstract contract help to manage config json file for Application
/// @notice this contract contains read/write functions JSON
abstract contract ConfigJsonRepo is Script {
  using stdJson for string;

  string internal directory = string.concat(vm.projectRoot(), "/configs/");
  string internal fileName = vm.envString("DEPLOYMENT_CONFIG_FILENAME");
  string internal configFilePath = string.concat(directory, fileName);

  function getJsonAddress(string memory _key) internal view returns (address _value) {
    string memory json = vm.readFile(configFilePath);

    return abi.decode(json.parseRaw(_key), (address));
  }

  function updateJson(string memory _key, string memory _value) internal {
    vm.writeJson(_value, configFilePath, _key);
  }

  function updateJson(string memory _key, address _address) internal {
    vm.writeJson(vm.toString(_address), configFilePath, _key);
  }
}
