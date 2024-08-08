// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";
import {DeployGame} from "../script/DeployGame.s.sol";
import "../src/Types.sol";
import {console} from "forge-std/console.sol";

contract GameTest is Test {
    Game game;

    address TEST_PLAYER1 = address(1);
    address TEST_PLAYER2 = address(2);

    function setUp() external {
        // Deploy contract
        DeployGame deployGame = new DeployGame();
        (game,) = deployGame.run();
        // Fund test user
        vm.deal(TEST_PLAYER1, 200 ether);
        vm.deal(TEST_PLAYER2, 200 ether);
    }

    function test_IsOwner() external {
        assertEq(game.owner(), address(msg.sender));
    }

    function test_IsMinimumAmount() external {
        assertEq(game.MIN_BET_USD(), 5 * 10 ** 18);
    }

    function test_IsPriceFeedVersion() external {
        assertEq(game.getPriceFeedVersion(), 4);
    }

    function test_ShouldRevert_BetLessThanMinimumAmount() external {
        vm.expectRevert();
        bytes32 hashedMove = keccak256(abi.encodePacked(Move.Scissors, "secret"));
        game.createRoom{value: 1}(hashedMove);
    }

    function test_ShouldRevert_WithdrawNotByOwner() external {
        // Fund contract
        vm.deal(address(this), 10 ether);
        // Withdraw using non-owner account
        vm.prank(TEST_PLAYER1);
        vm.expectRevert();
        game.withdraw(10 ether);
    }

    function test_WithdrawByOwner() external {
        // Fund contract
        vm.prank(TEST_PLAYER1);
        vm.deal(address(game), 10 ether);
        // Check initial owner balance
        uint256 startingOwnerBalance = game.getOwner().balance;
        uint256 startingContractBalance = address(game).balance;
        // Withdraw using owner account
        vm.prank(game.getOwner());
        game.withdraw(10 ether);
        assertEq(game.getOwner().balance, startingOwnerBalance + startingContractBalance);
    }

    function test_WinGame() external {
        Move move_player1 = Move.Scissors;
        string memory secret_player1 = "secret1";
        uint256 bet_player1 = 100 ether;

        Move move_player2 = Move.Paper;
        string memory secret_player2 = "secret2";
        uint256 bet_player2 = 100 ether;

        // Get starting balance
        uint256 startingBalancePlayer1 = TEST_PLAYER1.balance;
        uint256 startingBalancePlayer2 = TEST_PLAYER2.balance;
        uint256 startingContractBalance = address(game).balance;

        // Create room
        vm.prank(TEST_PLAYER1);
        bytes32 hashedMovePlayer1 = keccak256(abi.encodePacked(move_player1, secret_player1));
        game.createRoom{value: bet_player1}(hashedMovePlayer1);

        // Join room
        vm.prank(TEST_PLAYER2);
        bytes32 hashedMovePlayer2 = keccak256(abi.encodePacked(move_player2, secret_player2));
        game.joinRoom{value: bet_player2}(1, hashedMovePlayer2);

        // Reveal move
        vm.prank(TEST_PLAYER1);
        game.revealMove(1, move_player1, secret_player1);

        vm.prank(TEST_PLAYER2);
        game.revealMove(1, move_player2, secret_player2);

        // Check balance (Player 1 balance, Player 2 balance, Contract balance)
        uint256 game_fee = (bet_player1 + bet_player2) / game.GAME_FEE_PERCENT_DIVISOR();
        assertEq(TEST_PLAYER1.balance, startingBalancePlayer1 + bet_player2 - game_fee);
        assertEq(TEST_PLAYER2.balance, startingBalancePlayer2 - bet_player2);
        assertEq(address(game).balance, startingContractBalance + game_fee);
    }

    function test_DrawGame() external {
        Move move_player1 = Move.Scissors;
        string memory secret_player1 = "secret1";
        uint256 bet_player1 = 100 ether;

        Move move_player2 = Move.Scissors;
        string memory secret_player2 = "secret2";
        uint256 bet_player2 = 100 ether;

        // Get starting balance
        uint256 startingBalancePlayer1 = TEST_PLAYER1.balance;
        uint256 startingBalancePlayer2 = TEST_PLAYER2.balance;
        uint256 startingContractBalance = address(game).balance;

        // Create room
        vm.prank(TEST_PLAYER1);
        bytes32 hashedMovePlayer1 = keccak256(abi.encodePacked(move_player1, secret_player1));
        game.createRoom{value: bet_player1}(hashedMovePlayer1);

        // Join room
        vm.prank(TEST_PLAYER2);
        bytes32 hashedMovePlayer2 = keccak256(abi.encodePacked(move_player2, secret_player2));
        game.joinRoom{value: bet_player2}(1, hashedMovePlayer2);

        // Reveal move
        vm.prank(TEST_PLAYER1);
        game.revealMove(1, move_player1, secret_player1);

        vm.prank(TEST_PLAYER2);
        game.revealMove(1, move_player2, secret_player2);

        // Check balance (Player 1 balance, Player 2 balance, Contract balance)
        assertEq(TEST_PLAYER1.balance, startingBalancePlayer1);
        console.log("player1");
        assertEq(TEST_PLAYER2.balance, startingBalancePlayer2);
        console.log("player2");
        assertEq(address(game).balance, startingContractBalance);
        console.log("contract balance");
    }
}
