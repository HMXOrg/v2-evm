// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title Non-fungible token for margin accounts
interface NonfungibleMarginAccountManagerInterface is IERC721Metadata, IERC721Enumerable {}
