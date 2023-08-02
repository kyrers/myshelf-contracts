// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {BookRepository} from "src/BookRepository.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying from address", vm.addr(deployerPrivateKey));

        BookRepository bookRepository = new BookRepository();
        console2.log("Book Repository:", address(bookRepository));

        vm.stopBroadcast();
    }
}
