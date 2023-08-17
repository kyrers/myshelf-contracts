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

    error InvalidPrice();
    error NotAuthor();
    error NotEnoughFunds(uint256 price);
    error UnpublishedBook();

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    BookRepository bookRepository;

    function setUp() public {
        bookRepository = new BookRepository();
    }

    /// @notice tests that alice can buy bob and charlie books
    function test_buy() public {
        vm.prank(bob);

        //Should publish Bob's book with the price of 1 wei
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        vm.prank(charlie);

        //Should publish Charile's book with the price of 1 wei
        bookRepository.publish(2, 10, 2 wei, "fake_uri_charlie");

        vm.startPrank(alice);
        vm.deal(alice, 1 ether);

        //Should succeed
        bookRepository.buyBook{value: 1 wei}(1);
        bookRepository.buyBook{value: 2 wei}(2);

        uint256 balanceBobBook = bookRepository.balanceOf(alice, 1);
        assertEq(balanceBobBook, 1);

        uint256 balanceCharlieBook = bookRepository.balanceOf(alice, 2);
        assertEq(balanceCharlieBook, 1);

        //Contract should have 3 wei balance
        uint256 bookRepositoryBalance = address(bookRepository).balance;
        assertEq(bookRepositoryBalance, 3 wei);
    }

    /// @notice tests that purchases fail if not enough funds are sent
    function test_buy_revertNotEnoughFunds() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        bookRepository.publish(1, 10, 2 wei, "fake_uri");

        //Should fail because not enough funds were sent
        vm.expectRevert(abi.encodeWithSelector(NotEnoughFunds.selector, 2));
        bookRepository.buyBook{value: 1 wei}(1);

        vm.stopPrank();
    }

    /// @notice tests that users can't buy unpublished books
    function test_buy_revertUnpublishedBook() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        //Should fail because book hasn't been published
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.buyBook{value: 1 wei}(1);

        vm.stopPrank();
    }

    /// @notice fuzz test the buy function with different `bookId` and `amount` values
    function testFuzz_buy(uint256 bookId, uint256 amount) public {
        vm.startPrank(bob);
        vm.deal(bob, 10 ether);

        bookRepository.publish(1, 10, 2 wei, "fake_uri");

        vm.assume(amount < 10 ether);

        if (bookId != 1) {
            vm.expectRevert(UnpublishedBook.selector);
            bookRepository.buyBook{value: amount}(bookId);
        } else if (amount < 2 wei) {
            vm.expectRevert(abi.encodeWithSelector(NotEnoughFunds.selector, 2));
            bookRepository.buyBook{value: amount}(bookId);
        }

        vm.stopPrank();
    }

    /// @notice test that authors can update their book `price`
    function test_changePrice() public {
        vm.startPrank(bob);

        //Should publish Bob's book with correct price
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Bob should be able to update his book price
        bookRepository.changePrice(1, 2 wei);

        uint256 newPrice = bookRepository.bookPrice(1);
        assertEq(newPrice, 2 wei);

        vm.stopPrank();
    }

    /// @notice test that users can't update the `price` of books they're are not the author of
    function test_changePrice_revertNotAuthor() public {
        vm.prank(bob);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Alice shouldn't be able to change the price of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changePrice(1, 2 wei);
    }

    /// @notice test that unpublished books can't have their `price` updated
    function test_changePrice_revertUnpublishedBook() public {
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.changePrice(1, 2 wei);
    }

    /// @notice test that invalid prices are not accepted
    function test_changePrice_revertInvalidPrice() public {
        vm.startPrank(bob);

        bookRepository.publish(1, 10, 1 wei, "fake_uri");
        vm.expectRevert(InvalidPrice.selector);
        bookRepository.changePrice(1, 0 wei);

        vm.stopPrank();
    }

    /// @notice fuzz test the changePrice function with different `price` values
    function testFuzz_changePrice(uint256 price) public {
        vm.startPrank(bob);

        //Publish the book with 1 wei price
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Expect revert if price is invalid
        if (price <= 0) {
            vm.expectRevert(InvalidPrice.selector);
        }

        bookRepository.changePrice(1, price);

        vm.stopPrank();
    }

    /// @notice test that authors can update their book `uri`
    function test_changeUri() public {
        vm.startPrank(bob);

        //Should publish Bob's book with correct URI
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Bob should be able to update his book URI
        bookRepository.changeURI(1, "new_uri_bob");

        string memory newURI = bookRepository.uri(1);
        assertEq("new_uri_bob", newURI);

        vm.stopPrank();
    }

    /// @notice test that users can't update the `uri` of books they're are not the author of
    function test_changeUri_revertNotAuthor() public {
        vm.prank(bob);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Alice shouldn't be able to change the URI of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changeURI(1, "not_author");
    }

    /// @notice test that unpublished books can't have their `uri` updated
    function test_changeUri_revertUnpublishedBook() public {
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.changeURI(2, "unpublished book");
    }

    /// @notice test that multiple users can publish books and that they can mint more if they're the author
    function test_publish() public {
        vm.startPrank(bob);

        //Should mint 10 books by Bob
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        address authorBob = bookRepository.bookAuthor(1);
        assertEq(authorBob, bob);

        uint256 balanceBobBook = bookRepository.balanceOf(
            address(bookRepository),
            1
        );
        assertEq(balanceBobBook, 10);

        uint256 priceBob = bookRepository.bookPrice(1);
        assertEq(priceBob, 1 wei);

        string memory uriBob = bookRepository.uri(1);
        assertEq("fake_uri", uriBob);

        vm.stopPrank();

        //Should mint 10 books by Alice
        vm.startPrank(alice);
        vm.expectEmit();
        emit TransferSingle(alice, address(0), address(bookRepository), 2, 10);
        bookRepository.publish(2, 10, 1 wei, "fake_uri_alice");

        address authorAlice = bookRepository.bookAuthor(2);
        assertEq(authorAlice, alice);

        uint256 balanceAliceBook = bookRepository.balanceOf(
            address(bookRepository),
            2
        );
        assertEq(balanceAliceBook, 10);

        uint256 priceAlice = bookRepository.bookPrice(2);
        assertEq(priceAlice, 1 wei);

        string memory uriAlice = bookRepository.uri(2);
        assertEq("fake_uri_alice", uriAlice);

        vm.stopPrank();

        //Bob should be able to mint more of his own book
        vm.prank(bob);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        uint256 updatedBalanceBobBook = bookRepository.balanceOf(
            address(bookRepository),
            1
        );
        assertEq(updatedBalanceBobBook, 20);
    }

    /// @notice test that users can't mint books which they are not the author of
    function test_publish_revertNotAuthor() public {
        vm.prank(bob);

        bookRepository.publish(1, 10, 1 wei, "fake_uri");

        //Alice shouldn't be able to mint more of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.publish(1, 10, 1 wei, "fake_uri");
    }

    /// @notice fuzz test the publish function with different `bookId`, `amount`, and `price` values
    function testFuzz_publish(
        uint256 bookId,
        uint256 amount,
        uint256 price
    ) public {
        vm.prank(bob);

        if (0 wei >= price) {
            vm.expectRevert(InvalidPrice.selector);
            bookRepository.publish(bookId, amount, price, "fake_uri");
        } else {
            vm.expectEmit();
            emit TransferSingle(
                bob,
                address(0),
                address(bookRepository),
                bookId,
                amount
            );
            bookRepository.publish(bookId, amount, price, "fake_uri");

            uint256 priceBob = bookRepository.bookPrice(bookId);
            assertEq(priceBob, price);

            string memory uriBob = bookRepository.uri(bookId);
            assertEq("fake_uri", uriBob);
        }
    }
}
