// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {MyshelfCustomERC721} from "./MyshelfCustomERC721.sol";

contract BookRepository is Ownable {
    //Addresses of all books smart contracts
    address[] public bookContracts;

    constructor() Ownable(msg.sender) {}

    function deployERC721(
        string memory name,
        string memory symbol
    ) external returns (address newBook) {
        MyshelfCustomERC721 customContract = new MyshelfCustomERC721(
            name,
            symbol
        );
        customContract.transferOwnership(msg.sender);
        return address(customContract);
    }

    function deployERC1155() external returns (address newBook) {}
}
