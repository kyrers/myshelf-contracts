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

    error NotAuthor();
    error NotEnoughFunds(uint256 price);
    error UnpublishedBook();

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    BookRepository bookRepository;

    function setUp() public {
        bookRepository = new BookRepository();
    }

    function test_buy() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        //Should publish Bob's book with the price of 1 wei
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        //Should succeed
        bookRepository.buyBook{value: 1 wei}(1);

        uint256 balance = bookRepository.balanceOf(bob, 1);
        assertEq(balance, 1);

        //Contract should have 1 wei balance
        uint256 bookRepositoryBalance = address(bookRepository).balance;
        assertEq(bookRepositoryBalance, 1 wei);

        vm.stopPrank();
    }

    function test_buy_revertNotEnoughFunds() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        bookRepository.publish("fake_uri", 1, 10, 2 wei);

        //Should fail because not enough funds were sent
        vm.expectRevert(abi.encodeWithSelector(NotEnoughFunds.selector, 2));
        bookRepository.buyBook{value: 1 wei}(1);

        vm.stopPrank();
    }

    function test_buy_revertUnpublishedBook() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        //Should fail because book hasn't been published
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.buyBook{value: 1 wei}(1);

        vm.stopPrank();
    }

    function testFuzz_buy(uint256 bookId, uint256 amount) public {
        vm.startPrank(bob);
        vm.deal(bob, 10 ether);

        bookRepository.publish("fake_uri", 1, 10, 2 wei);

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

    function test_publish() public {
        vm.startPrank(bob);

        //Should mint 10 books by Bob
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        address authorBob = bookRepository.bookAuthor(1);
        assertEq(authorBob, bob);

        uint256 balanceBobBook = bookRepository.balanceOf(
            address(bookRepository),
            1
        );
        assertEq(balanceBobBook, 10);

        string memory uriBob = bookRepository.uri(1);
        assertEq("fake_uri", uriBob);

        vm.stopPrank();

        //Should mint 10 books by Alice
        vm.startPrank(alice);
        vm.expectEmit();
        emit TransferSingle(alice, address(0), address(bookRepository), 2, 10);
        bookRepository.publish("fake_uri_alice", 2, 10, 1 wei);

        address authorAlice = bookRepository.bookAuthor(2);
        assertEq(authorAlice, alice);

        uint256 balanceAliceBook = bookRepository.balanceOf(
            address(bookRepository),
            2
        );
        assertEq(balanceAliceBook, 10);

        string memory uriAlice = bookRepository.uri(2);
        assertEq("fake_uri_alice", uriAlice);

        vm.stopPrank();

        //Bob should be able to mint more of his own book
        vm.prank(bob);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        uint256 updatedBalanceBobBook = bookRepository.balanceOf(
            address(bookRepository),
            1
        );
        assertEq(updatedBalanceBobBook, 20);
    }

    function test_publish_revertNotAuthor() public {
        vm.prank(bob);

        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        //Alice shouldn't be able to mint more of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);
    }

    function testFuzz_publish(
        uint256 bookId,
        uint256 amount,
        uint256 price
    ) public {
        vm.assume(bookId > 0);
        vm.assume(amount >= 0);
        vm.assume(price > 0 ether);

        bookRepository.publish("fake_uri", bookId, amount, price);
    }

    function test_uri_change() public {
        vm.startPrank(bob);

        //Should publish Bob's book with correct URI
        vm.expectEmit();
        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        //Bob should be able to update his book URI
        bookRepository.changeURI(1, "new_uri_bob");

        string memory bobURI = bookRepository.uri(1);
        assertEq("new_uri_bob", bobURI);

        vm.stopPrank();
    }

    function test_uri_revertNotAuthor() public {
        vm.prank(bob);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        //Alice shouldn't be able to change the URI of Bob's book
        vm.prank(alice);
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changeURI(1, "not_author");
    }

    function test_uri_revertUnpublishedBook() public {
        vm.expectRevert(UnpublishedBook.selector);
        bookRepository.changeURI(2, "unpublished book");
    }
}
