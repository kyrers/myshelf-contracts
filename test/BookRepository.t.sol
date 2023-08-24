// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {BookRepository} from "src/BookRepository.sol";

contract BookRepositoryTest is Test {
    //From IERC1155
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

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

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    BookRepository bookRepository;

    function setUp() public {
        bookRepository = new BookRepository();
    }

    /// @notice test that multiple users can publish books
    function test_publish() public {
        //Should mint 10 books by Bob
        vm.startPrank(bob);

        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);

        vm.expectEmit();
        emit BookPublished(bob, 1, 1 wei);

        uint256 bobBookId = bookRepository.publish(10, 1 wei, "fake_uri");
        assertEq(bobBookId, 1);

        address authorBob = bookRepository.bookAuthor(bobBookId);
        assertEq(authorBob, bob);

        uint256 balanceBobBook = bookRepository.balanceOf(
            address(bookRepository),
            bobBookId
        );
        assertEq(balanceBobBook, 10);

        uint256 priceBob = bookRepository.bookPrice(bobBookId);
        assertEq(priceBob, 1 wei);

        string memory uriBob = bookRepository.uri(bobBookId);
        assertEq("fake_uri", uriBob);

        vm.stopPrank();

        //Should mint 10 books by Alice
        vm.startPrank(alice);

        vm.expectEmit();
        emit TransferSingle(alice, address(0), address(bookRepository), 2, 10);

        vm.expectEmit();
        emit BookPublished(alice, 2, 1 wei);

        uint256 aliceBookId = bookRepository.publish(
            10,
            1 wei,
            "fake_uri_alice"
        );
        assertEq(aliceBookId, 2);

        address authorAlice = bookRepository.bookAuthor(aliceBookId);
        assertEq(authorAlice, alice);

        uint256 balanceAliceBook = bookRepository.balanceOf(
            address(bookRepository),
            aliceBookId
        );
        assertEq(balanceAliceBook, 10);

        uint256 priceAlice = bookRepository.bookPrice(aliceBookId);
        assertEq(priceAlice, 1 wei);

        string memory uriAlice = bookRepository.uri(aliceBookId);
        assertEq("fake_uri_alice", uriAlice);

        vm.stopPrank();
    }

    /// @notice test that users can't mint books with invalid prices
    function test_publish_revertInvalidPrice() public {
        vm.prank(bob);
        vm.expectRevert(InvalidPrice.selector);
        bookRepository.publish(10, 0 wei, "fake_uri");
    }

    /// @notice fuzz test the publish function with different `amount` and `price` values
    function testFuzz_publish(uint256 amount, uint256 price) public {
        vm.prank(bob);

        if (0 wei >= price) {
            vm.expectRevert(InvalidPrice.selector);
            bookRepository.publish(amount, price, "fake_uri");
        } else {
            vm.expectEmit();
            emit TransferSingle(
                bob,
                address(0),
                address(bookRepository),
                1,
                amount
            );

            vm.expectEmit();
            emit BookPublished(bob, 1, price);

            uint256 bookId = bookRepository.publish(amount, price, "fake_uri");

            uint256 priceBob = bookRepository.bookPrice(bookId);
            assertEq(priceBob, price);

            string memory uriBob = bookRepository.uri(bookId);
            assertEq("fake_uri", uriBob);
        }
    }

    /// @notice tests that alice can buy bob and charlie books
    function test_buy() public {
        vm.prank(bob);

        //Should publish Bob's book with the price of 1 wei
        uint256 bobBookId = bookRepository.publish(10, 1 wei, "fake_uri");

        vm.prank(charlie);

        //Should publish Charile's book with the price of 1 wei
        uint256 charlieBookId = bookRepository.publish(
            10,
            2 wei,
            "fake_uri_charlie"
        );

        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        //Should succeed
        vm.expectEmit();
        emit BooksBought(alice, bobBookId, 1, 1 wei);
        bookRepository.buyBook{value: 1 wei}(bobBookId, 1);

        vm.expectEmit();
        emit BooksBought(alice, charlieBookId, 2, 2 wei);
        bookRepository.buyBook{value: 4 wei}(charlieBookId, 2);

        uint256 balanceBobBook = bookRepository.balanceOf(alice, 1);
        assertEq(balanceBobBook, 1);

        uint256 balanceCharlieBook = bookRepository.balanceOf(alice, 2);
        assertEq(balanceCharlieBook, 2);

        //Contract should have 5 wei balance
        uint256 bookRepositoryBalance = address(bookRepository).balance;
        assertEq(bookRepositoryBalance, 5 wei);
    }

    /// @notice tests that purchases fail if not enough funds are sent
    function test_buy_revertInvalidPayment() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        uint256 bookId = bookRepository.publish(10, 2 wei, "fake_uri");

        //Should fail because not enough funds were sent for 1 book
        vm.expectRevert(abi.encodeWithSelector(InvalidPayment.selector, 2));
        bookRepository.buyBook{value: 1 wei}(bookId, 1);

        //Should fail because not enough funds were sent 2 books
        vm.expectRevert(abi.encodeWithSelector(InvalidPayment.selector, 4));
        bookRepository.buyBook{value: 2 wei}(bookId, 2);

        vm.stopPrank();
    }

    /// @notice tests that users can't buy unpublished books
    function test_buy_revertUnpublishedBook() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        //Should fail because book hasn't been published
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.buyBook{value: 1 wei}(1, 1);

        vm.stopPrank();
    }

    /// @notice tests that users can't buy unpublished books
    function test_buy_revertNotEnoughSupply() public {
        vm.prank(bob);
        bookRepository.publish(1, 1 wei, "fake_uri");

        vm.prank(alice);
        vm.deal(alice, 1 ether);

        //Should fail because there's not enough supply of the book
        vm.expectRevert(abi.encodeWithSelector(NotEnoughSupply.selector, 1));
        bookRepository.buyBook{value: 2 wei}(1, 2);
    }

    /// @notice fuzz test the buy function with different `bookId`, `amount`, and values
    function testFuzz_buy(
        uint256 bookId,
        uint256 amount,
        uint256 value
    ) public {
        vm.startPrank(bob);
        vm.deal(bob, 10 ether);
        vm.assume(value < 10 ether);

        bookRepository.publish(10, 2 wei, "fake_uri");

        if (bookId != 1) {
            vm.expectRevert(UnpublishedBook.selector);
            bookRepository.buyBook{value: value}(bookId, amount);
        } else if (amount > 10) {
            vm.expectRevert(
                abi.encodeWithSelector(NotEnoughSupply.selector, 10)
            );
            bookRepository.buyBook{value: value}(bookId, amount);
        } else if (value != amount * 2 wei) {
            vm.expectRevert(
                abi.encodeWithSelector(InvalidPayment.selector, amount * 2 wei)
            );
            bookRepository.buyBook{value: value}(bookId, amount);
        } else {
            vm.expectEmit();
            emit BooksBought(bob, 1, amount, 2 wei);
            bookRepository.buyBook{value: value}(bookId, amount);
        }

        vm.stopPrank();
    }

    /// @notice test that authors can increase the supply of their published books
    function test_increaseSupply() public {
        //Should mint 10 books by Bob
        vm.startPrank(bob);

        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);

        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Should increase supply to 20 and update price and uri accordingly
        vm.expectEmit();
        emit SupplyIncreased(bookId, 10, 20);

        bookRepository.increaseSupply(bookId, 10, 2 wei, "new_uri");

        uint256 balanceBook = bookRepository.balanceOf(
            address(bookRepository),
            bookId
        );
        assertEq(balanceBook, 20);

        uint256 price = bookRepository.bookPrice(bookId);
        assertEq(price, 2 wei);

        string memory uri = bookRepository.uri(bookId);
        assertEq("new_uri", uri);

        vm.stopPrank();
    }

    /// @notice test that users cannot increase the supply of books they're are not the author of
    function test_increaseSupply_revertNotAuthor() public {
        //Should mint 10 books by Bob
        vm.prank(bob);
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);

        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Alice shouldn't be able to increase supply
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.increaseSupply(bookId, 10, 1 wei, "fake_uri");
    }

    /// @notice test that users cannot increase the supply of unpublished books
    function test_increaseSupply_revertUnpublishedBook() public {
        vm.prank(bob);
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.increaseSupply(1, 10, 1 wei, "fake_uri");
    }

    /// @notice test that authors cannot increase the supply of books and set an invalid price
    function test_increaseSupply_revertInvalidPrice() public {
        //Should mint 10 books by Bob
        vm.startPrank(bob);
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);

        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        vm.expectRevert(InvalidPrice.selector);
        bookRepository.increaseSupply(bookId, 10, 0 wei, "fake_uri");

        vm.stopPrank();
    }

    /// @notice fuzz test the increaseSupply function with different `bookId`, `amount`, and `price` values
    function testFuzz_increaseSupply(
        uint256 bookId,
        uint256 amount,
        uint256 price
    ) public {
        vm.startPrank(bob);

        //First, publish a valid book
        uint256 bobBookId = bookRepository.publish(10, 1 wei, "fake_uri");

        if (bookId != bobBookId) {
            vm.expectRevert(UnpublishedBook.selector);
            bookRepository.increaseSupply(bookId, amount, price, "fake_uri");
        } else if (amount > UINT256_MAX - 10) {
            //Checks that if the amount is increased by a value that when added to the already existing books is bigger than type(uint256).max the contract will overflow
            vm.expectRevert(InvalidAmount.selector);
            bookRepository.increaseSupply(bookId, amount, price, "fake_uri");
        } else if (0 wei >= price) {
            vm.expectRevert(InvalidPrice.selector);
            bookRepository.increaseSupply(bookId, amount, price, "fake_uri");
        } else {
            vm.expectEmit();
            emit TransferSingle(
                bob,
                address(0),
                address(bookRepository),
                bookId,
                amount
            );

            vm.expectEmit();
            emit SupplyIncreased(
                bookId,
                amount,
                amount +
                    bookRepository.balanceOf(address(bookRepository), bookId)
            );

            bookRepository.increaseSupply(bookId, amount, price, "fake_uri");

            uint256 amountBob = bookRepository.balanceOf(
                address(bookRepository),
                bookId
            );
            assertEq(amountBob, amount + 10);

            uint256 priceBob = bookRepository.bookPrice(bookId);
            assertEq(priceBob, price);

            string memory uriBob = bookRepository.uri(bookId);
            assertEq("fake_uri", uriBob);
        }

        vm.stopPrank();
    }

    /// @notice test that authors can update their book `price`
    function test_changePrice() public {
        vm.startPrank(bob);

        //Should publish Bob's book with correct price
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Bob should be able to update his book price
        vm.expectEmit();
        emit PriceUpdated(bookId, 2 wei);
        bookRepository.changePrice(bookId, 2 wei);

        uint256 newPrice = bookRepository.bookPrice(bookId);
        assertEq(newPrice, 2 wei);

        vm.stopPrank();
    }

    /// @notice test that users can't update the `price` of books they're are not the author of
    function test_changePrice_revertNotAuthor() public {
        vm.prank(bob);
        uint256 bobBookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Alice shouldn't be able to change the price of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changePrice(bobBookId, 2 wei);
    }

    /// @notice test that unpublished books can't have their `price` updated
    function test_changePrice_revertUnpublishedBook() public {
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.changePrice(1, 2 wei);
    }

    /// @notice test that invalid prices are not accepted
    function test_changePrice_revertInvalidPrice() public {
        vm.startPrank(bob);

        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");
        vm.expectRevert(InvalidPrice.selector);
        bookRepository.changePrice(bookId, 0 wei);

        vm.stopPrank();
    }

    /// @notice fuzz test the changePrice function with different `price` values
    function testFuzz_changePrice(uint256 price) public {
        vm.startPrank(bob);

        //Publish the book with 1 wei price
        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Expect revert if price is invalid
        if (price <= 0) {
            vm.expectRevert(InvalidPrice.selector);
        } else {
            vm.expectEmit();
            emit PriceUpdated(bookId, price);
        }

        bookRepository.changePrice(bookId, price);

        vm.stopPrank();
    }

    /// @notice test that authors can update their book `uri`
    function test_changeUri() public {
        vm.startPrank(bob);

        //Should publish Bob's book with correct URI
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        uint256 bookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Bob should be able to update his book URI
        vm.expectEmit();
        emit URIUpdated(bookId, "new_uri_bob");
        bookRepository.changeURI(bookId, "new_uri_bob");

        string memory newURI = bookRepository.uri(1);
        assertEq("new_uri_bob", newURI);

        vm.stopPrank();
    }

    /// @notice test that users can't update the `uri` of books they're are not the author of
    function test_changeUri_revertNotAuthor() public {
        vm.prank(bob);
        uint256 boobBookId = bookRepository.publish(10, 1 wei, "fake_uri");

        //Alice shouldn't be able to change the URI of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changeURI(boobBookId, "not_author");
    }

    /// @notice test that unpublished books can't have their `uri` updated
    function test_changeUri_revertUnpublishedBook() public {
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.changeURI(1, "unpublished book");
    }
}
