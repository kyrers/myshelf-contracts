// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155, ERC1155URIStorage} from "@openzeppelin/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Holder} from "@openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";

contract BookRepository is Ownable, ERC1155URIStorage, ERC1155Holder {
    //Mapping of book ID to author
    mapping(uint256 => address) public bookAuthor;

    //Mapping of book ID to price (in wei)
    mapping(uint256 => uint256) public bookPrice;

    error NotAuthor();
    error NotEnoughFunds(uint256 price);

    constructor() ERC1155("") Ownable(msg.sender) {}

    function buyBook(uint256 id) external payable {
        if (msg.value < bookPrice[id]) {
            revert NotEnoughFunds(bookPrice[id]);
        }

        _safeTransferFrom(address(this), msg.sender, id, 1, "");
    }

    function changeURI(uint256 id, string memory uri) external {
        if (bookAuthor[id] != msg.sender) {
            revert NotAuthor();
        }

        _setURI(id, uri);
    }

    function publish(
        string memory uri,
        uint256 id,
        uint256 amount,
        uint256 price
    ) external {
        if (bookAuthor[id] != msg.sender && bookAuthor[id] != address(0)) {
            revert NotAuthor();
        }

        bookAuthor[id] = msg.sender;
        bookPrice[id] = price;

        _mint(address(this), id, amount, "");
        _setURI(id, uri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
