// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC721, ERC721Enumerable} from "@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

contract MyshelfCustomERC721 is Ownable, ERC721Enumerable {
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {}
}
