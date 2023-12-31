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
    uint256 private _bookCount;
    mapping(uint256 => address) public bookAuthor;
    mapping(uint256 => uint256) public bookPrice;

    event BooksBought(
        address buyer,
        uint256 bookId,
        uint256 amount,
        uint256 price
    );
    event BookPublished(address author, uint256 bookId, uint256 price);
    event PriceUpdated(uint256 bookId, uint256 newPrice);
    event SupplyIncreased(uint256 bookId, uint256 amount, uint256 totalSupply);
    event URIUpdated(uint256 bookId, string newURI);

    error InvalidAmount();
    error InvalidPayment(uint256 price);
    error InvalidPrice();
    error NotAuthor();
    error NotEnoughSupply(uint256 availableAmount);
    error UnpublishedBook();

    modifier isAuthor(uint256 bookId) {
        if (msg.sender != bookAuthor[bookId]) {
            revert NotAuthor();
        }
        _;
    }

    modifier isAvailable(uint256 bookId, uint256 amount) {
        uint256 availableAmount = balanceOf(address(this), bookId);
        if (amount > availableAmount) {
            revert NotEnoughSupply(availableAmount);
        }
        _;
    }

    modifier isPublished(uint256 bookId) {
        if (address(0) == bookAuthor[bookId]) {
            revert UnpublishedBook();
        }
        _;
    }

    modifier isValidAmount(uint256 bookId, uint256 amount) {
        if (amount > type(uint256).max - balanceOf(address(this), bookId)) {
            revert InvalidAmount();
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
     * @notice Publishes `amount` new books, costing `price` and with `uri`
     * @param amount number of books to publish
     * @param price the cost of each book in wei
     * @param uri the type `uri`
     * @return bookId is the published book type `id`
     */
    function publish(
        uint256 amount,
        uint256 price,
        string memory uri
    ) external isValidPrice(price) nonReentrant returns (uint256 bookId) {
        bookId = ++_bookCount;

        bookAuthor[bookId] = msg.sender;
        bookPrice[bookId] = price;

        _mint(address(this), bookId, amount, "");
        _setURI(bookId, uri);

        emit BookPublished(msg.sender, bookId, price);
    }

    /**
     * @notice Tansfers `amount` of books of type `id` to `msg.sender` if `msg.value` equals the book price * `amount`
     * @param bookId type `id` of the wanted book
     * @param amount amount of books wanted
     */
    function buyBook(
        uint256 bookId,
        uint256 amount
    )
        external
        payable
        isPublished(bookId)
        isAvailable(bookId, amount)
        nonReentrant
    {
        if (msg.value != bookPrice[bookId] * amount) {
            revert InvalidPayment(bookPrice[bookId] * amount);
        }

        _safeTransferFrom(address(this), msg.sender, bookId, amount, "");

        emit BooksBought(msg.sender, bookId, amount, bookPrice[bookId]);
    }

    /**
     * @notice Increase supply of books of type `bookId` by `amount`, costing `price` and with `uri`
     * @param bookId type `id` of the book
     * @param amount number of books to publish
     * @param price the cost of each book in wei
     * @param uri the type `uri`
     * @dev Only executes if the all of the following is true: type is published, msg.sender is the author, the increase amount does not surpass type(uint256).max when added to the already existing amount of books, the price is valid
     */
    function increaseSupply(
        uint256 bookId,
        uint256 amount,
        uint256 price,
        string memory uri
    )
        external
        isPublished(bookId)
        isAuthor(bookId)
        isValidAmount(bookId, amount)
        isValidPrice(price)
        nonReentrant
    {
        bookAuthor[bookId] = msg.sender;
        bookPrice[bookId] = price;

        _mint(address(this), bookId, amount, "");
        _setURI(bookId, uri);

        emit SupplyIncreased(bookId, amount, balanceOf(address(this), bookId));
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

        emit PriceUpdated(bookId, price);
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

        emit URIUpdated(bookId, uri);
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
