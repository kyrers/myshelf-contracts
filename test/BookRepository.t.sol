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

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    BookRepository bookRepository;

    function setUp() public {
        bookRepository = new BookRepository();
    }

    function testPublish() public {
        vm.prank(bob);

        vm.expectEmit();
        emit TransferSingle(bob, address(0), bob, 1, 10);

        bookRepository.publish("fake_uri", 1, 10);

        address author = bookRepository.bookAuthor(1);
        assertEq(author, bob);

        uint256 balance = bookRepository.balanceOf(bob, 1);
        assertEq(balance, 10);

        string memory uri = bookRepository.uri(1);
        assertEq("fake_uri", uri);
    }
}
