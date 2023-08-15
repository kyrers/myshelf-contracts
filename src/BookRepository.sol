// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {ERC1155, ERC1155URIStorage} from "@openzeppelin/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Holder} from "@openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";

contract BookRepository is
    Ownable,
    ERC1155URIStorage,
    ERC1155Holder,
    ReentrancyGuard
{
    //Mapping of book ID to author
    mapping(uint256 => address) public bookAuthor;

    //Mapping of book ID to price (in wei)
    mapping(uint256 => uint256) public bookPrice;

    error NotAuthor();
    error NotEnoughFunds(uint256 price);
    error UnpublishedBook();

    modifier isPublished(uint256 bookId) {
        if (bookAuthor[bookId] == address(0)) {
            revert UnpublishedBook();
        }
        _;
    }

    constructor() ERC1155("") Ownable(msg.sender) {}

    function buyBook(
        uint256 bookId
    ) external payable isPublished(bookId) nonReentrant {
        if (msg.value < bookPrice[bookId]) {
            revert NotEnoughFunds(bookPrice[bookId]);
        }

        _safeTransferFrom(address(this), msg.sender, bookId, 1, "");
    }

    function changeURI(
        uint256 bookId,
        string memory uri
    ) external isPublished(bookId) {
        //msg.sender must be the author
        if (bookAuthor[bookId] != msg.sender) {
            revert NotAuthor();
        }

        _setURI(bookId, uri);
    }

    function publish(
        string memory uri,
        uint256 bookId,
        uint256 amount,
        uint256 price
    ) external nonReentrant {
        //msg.sender must be the author if the id is already in use
        if (
            bookAuthor[bookId] != msg.sender && bookAuthor[bookId] != address(0)
        ) {
            revert NotAuthor();
        }

        bookAuthor[bookId] = msg.sender;
        bookPrice[bookId] = price;

        _mint(address(this), bookId, amount, "");
        _setURI(bookId, uri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
