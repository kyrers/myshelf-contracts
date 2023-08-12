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

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    BookRepository bookRepository;

    function setUp() public {
        bookRepository = new BookRepository();
    }

    function testPublish() public {
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

        //Alice shouldn't be able to mint more of Bob's book
        vm.expectRevert(NotAuthor.selector);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

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

    function testChangeUri() public {
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
        vm.startPrank(alice);

        //Should publish Alice's book with correct URI
        vm.expectEmit();
        emit TransferSingle(alice, address(0), address(bookRepository), 2, 10);
        bookRepository.publish("fake_uri_alice", 2, 10, 1 wei);

        //Alice should be able to change her book URI
        bookRepository.changeURI(2, "new_uri_alice");

        string memory aliceURI = bookRepository.uri(2);
        assertEq("new_uri_alice", aliceURI);

        //Alice shouldn't be able to change the URI of Bob's book
        vm.expectRevert(NotAuthor.selector);
        bookRepository.changeURI(1, "not_author");

        vm.stopPrank();
    }

    function testBuy() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        //Should publish Bob's book with the price of 1 wei
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        //Should fail because not enough funds were sent
        vm.expectRevert(abi.encodeWithSelector(NotEnoughFunds.selector, 1));
        bookRepository.buyBook(1);

        //Should succeed
        bookRepository.buyBook{value: 1 wei}(1);

        uint256 balance = bookRepository.balanceOf(bob, 1);
        assertEq(balance, 1);

        //Contract should have 1 wei balance
        uint256 bookRepositoryBalance = address(bookRepository).balance;
        assertEq(bookRepositoryBalance, 1 wei);

        vm.stopPrank();
    }
}
