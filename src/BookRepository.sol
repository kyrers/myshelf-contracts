// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {ERC1155, ERC1155URIStorage} from "@openzeppelin/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Holder} from "@openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";

/**
 * @title Book Repository
 * @author kyrers
 * @notice ERC1155 that publishes, holds, and sells books.
 */
contract BookRepository is
    Ownable,
    ERC1155URIStorage,
    ERC1155Holder,
    ReentrancyGuard
{
    mapping(uint256 => address) public bookAuthor;
    mapping(uint256 => uint256) public bookPrice;

    error InvalidPrice();
    error NotAuthor();
    error NotEnoughFunds(uint256 price);
    error UnpublishedBook();

    modifier isAuthor(uint256 bookId) {
        if (msg.sender != bookAuthor[bookId]) {
            revert NotAuthor();
        }
        _;
    }

    modifier isPublished(uint256 bookId) {
        if (address(0) == bookAuthor[bookId]) {
            revert UnpublishedBook();
        }
        _;
    }

    modifier isValidPrice(uint256 price) {
        if (0 >= price) {
            revert InvalidPrice();
        }
        _;
    }

    constructor() ERC1155("") Ownable(msg.sender) {}

    /**
     * @notice Tansfers one book of type `id` to `msg.sender` if enough funds are sent
     * @param bookId type `id` of the wanted book
     */
    function buyBook(
        uint256 bookId
    ) external payable isPublished(bookId) nonReentrant {
        if (msg.value < bookPrice[bookId]) {
            revert NotEnoughFunds(bookPrice[bookId]);
        }

        _safeTransferFrom(address(this), msg.sender, bookId, 1, "");
    }

    /**
     * @notice Allows the `author` of a published book with type `bookId` to update its `price`
     * @param bookId type `id` of the wanted book
     * @param price the new price
     */
    function changePrice(
        uint256 bookId,
        uint256 price
    ) external isPublished(bookId) isAuthor(bookId) isValidPrice(price) {
        bookPrice[bookId] = price;
    }

    /**
     * @notice Allows the `author` of a published book with type `bookId` to update its `uri`
     * @param bookId type `id` of the book
     * @param uri the new `uri`
     */
    function changeURI(
        uint256 bookId,
        string memory uri
    ) external isPublished(bookId) isAuthor(bookId) {
        _setURI(bookId, uri);
    }

    /**
     * @notice Publishes `amount` new books of type `bookId`, costing `price` and with `uri`
     * @param bookId type `id` of the book
     * @param amount number of books to publish
     * @param price the cost of each book in wei
     * @param uri the type `uri`
     * @dev Only executes if the type is not published, or if it is, this is the author minting more instances
     */
    function publish(
        uint256 bookId,
        uint256 amount,
        uint256 price,
        string memory uri
    ) external isValidPrice(price) nonReentrant {
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

    /**
     * @notice Since both ERC1155 and ERC1155Holder implement this, check if `interfaceId` matches `ERC1155` first or `ERC1155Holder` second.
     * @param interfaceId The interface to check
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
