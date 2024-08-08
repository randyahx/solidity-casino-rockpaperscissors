// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Game} from "../src/Game.sol";
import {Config} from "./Config.sol";

contract DeployGame is Script {
    function deployGame() public returns (Game, Config) {
        Config networkConfig = new Config();
        address priceFeed = networkConfig.getConfigByChainId(31337).priceFeed;

        vm.startBroadcast();
        Game game = new Game(priceFeed);
        vm.stopBroadcast();
        return (game, networkConfig);
    }

    function run() external returns (Game, Config) {
        return deployGame();
    }
}
