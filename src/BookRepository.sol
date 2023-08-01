// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "@openzeppelin/access/Ownable.sol";

contract BookRepository is Ownable {
    //Addresses of all books smart contracts
    address[] public bookContracts;

    function deployERC721() external returns (address newBook) {}

    function deployERC1155() external returns (address newBook) {}
}
