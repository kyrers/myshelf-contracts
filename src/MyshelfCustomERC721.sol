// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

contract MyshelfCustomERC721 is Ownable, ERC721Enumerable {
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}
}
