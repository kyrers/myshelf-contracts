// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155, ERC1155URIStorage} from "@openzeppelin/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract BookRepository is Ownable, ERC1155URIStorage {
    //Mapping of token ID to author
    mapping(uint256 => address) public bookAuthor;

    error NotOwner();

    modifier onlyTokenOwner(uint256 id) {
        if (bookAuthor[id] != msg.sender) {
            revert NotOwner();
        }
        _;
    }

    constructor() ERC1155("") Ownable(msg.sender) {}

    function publish(string memory uri, uint256 id, uint256 amount) external {
        bookAuthor[id] = msg.sender;

        _mint(msg.sender, id, amount, "");
        _setURI(id, uri);
    }

    function changeURI(
        uint256 id,
        string memory uri
    ) external onlyTokenOwner(id) {
        _setURI(id, uri);
    }
}
