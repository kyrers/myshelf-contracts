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
        vm.expectEmit();

        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        address author = bookRepository.bookAuthor(1);
        assertEq(author, bob);

        uint256 balance = bookRepository.balanceOf(address(bookRepository), 1);
        assertEq(balance, 10);

        string memory uri = bookRepository.uri(1);
        assertEq("fake_uri", uri);

        vm.stopPrank();
        vm.startPrank(alice);

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
    }

    function testChangeUri() public {
        vm.prank(bob);
        vm.expectEmit();

        emit TransferSingle(bob, address(0), address(bookRepository), 1, 10);
        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        vm.startPrank(alice);
        vm.expectEmit();

        emit TransferSingle(alice, address(0), address(bookRepository), 2, 10);
        bookRepository.publish("fake_uri_alice", 2, 10, 1 wei);
        bookRepository.changeURI(2, "new_uri_alice");

        string memory aliceURI = bookRepository.uri(2);
        assertEq("new_uri_alice", aliceURI);

        vm.expectRevert(NotAuthor.selector);

        //Should fail: Alice is trying to change the URI of Bob's book
        bookRepository.changeURI(1, "not_author");

        vm.stopPrank();
        vm.prank(bob);

        bookRepository.changeURI(1, "new_uri_bob");

        string memory bobURI = bookRepository.uri(1);
        assertEq("new_uri_bob", bobURI);

        vm.expectRevert(NotAuthor.selector);

        //Should fail: Bob is trying to change the URI of Alice's book
        bookRepository.changeURI(2, "not_author");
    }

    function testBuy() public {
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);

        bookRepository.publish("fake_uri", 1, 10, 1 wei);

        vm.expectRevert(abi.encodeWithSelector(NotEnoughFunds.selector, 1));

        //Should fail because not enough funds were sent
        bookRepository.buyBook(1);

        //Should succeed
        bookRepository.buyBook{value: 1 wei}(1);

        uint256 balance = bookRepository.balanceOf(bob, 1);
        assertEq(balance, 1);

        //Contract should have 1 wei balance
        uint256 bookRepositoryBalance = address(bookRepository).balance;
        assertEq(bookRepositoryBalance, 1 wei);
    }
}
