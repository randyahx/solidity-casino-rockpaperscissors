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
        // Create players
        Game.Player memory player1 = new Game.Player();
        player1.move = Move.Scissors;
        player1.addr = TEST_PLAYER1;
        uint256 bet_player1 = 100 ether;
        string memory secret_player1 = "secret1";

        Game.Player memory player2 = new Game.Player();
        player2.move = Move.Paper;
        player2.addr = TEST_PLAYER2;
        uint256 bet_player2 = 100 ether;
        string memory secret_player2 = "secret2";

        // Get starting balance
        uint256 startingBalancePlayer1 = player1.addr.balance;
        uint256 startingBalancePlayer2 = player2.addr.balance;
        uint256 startingContractBalance = address(game).balance;

        (uint256 balancePlayer1, uint256 balancePlayer2, uint256 balanceContract) =
            playGame(player1, player2, bet_player1, bet_player2, secret_player1, secret_player2);

        // Check balance (Player 1 balance, Player 2 balance, Contract balance)
        uint256 game_fee = (bet_player1 + bet_player2) / game.GAME_FEE_PERCENT_DIVISOR();
        assertEq(balancePlayer1, startingBalancePlayer1 + bet_player2 - game_fee);
        assertEq(balancePlayer2, startingBalancePlayer2 - bet_player2);
        assertEq(balanceContract, startingContractBalance + game_fee);
    }

    function test_DrawGame() external {
        // Create players
        Game.Player memory player1 = new Game.Player();
        player1.move = Move.Scissors;
        player1.addr = TEST_PLAYER1;
        uint256 bet_player1 = 100 ether;
        string memory secret_player1 = "secret1";

        Game.Player memory player2 = new Game.Player();
        player2.move = Move.Scissors;
        player2.addr = TEST_PLAYER2;
        uint256 bet_player2 = 100 ether;
        string memory secret_player2 = "secret2";

        // Get starting balance
        uint256 startingBalancePlayer1 = player1.addr.balance;
        uint256 startingBalancePlayer2 = player2.addr.balance;
        uint256 startingContractBalance = address(game).balance;

        (uint256 balancePlayer1, uint256 balancePlayer2, uint256 balanceContract) =
            playGame(player1, player2, bet_player1, bet_player2, secret_player1, secret_player2);

        // Check balance (Player 1 balance, Player 2 balance, Contract balance)
        assertEq(balancePlayer1, startingBalancePlayer1);
        assertEq(balancePlayer2, startingBalancePlayer2);
        assertEq(balanceContract, startingContractBalance);
    }

    function playGame(
        Game.Player memory player1,
        Game.Player memory player2,
        uint256 betAmountPlayer1,
        uint256 betAmountPlayer2,
        string memory secretPlayer1,
        string memory secretPlayer2
    ) internal returns (uint256 balancePlayer1, uint256 balancePlayer2, uint256 balanceContract) {
        // Create room
        vm.prank(player1.addr);
        bytes32 hashedMovePlayer1 = keccak256(abi.encodePacked(player1.move, secretPlayer1));
        game.createRoom{value: betAmountPlayer1}(hashedMovePlayer1);

        // Join room
        vm.prank(player2.addr);
        bytes32 hashedMovePlayer2 = keccak256(abi.encodePacked(player2.move, secretPlayer2));
        game.joinRoom{value: betAmountPlayer2}(1, hashedMovePlayer2);

        // Reveal move
        vm.prank(player1.addr);
        game.revealMove(1, player1.move, player1.secret);

        vm.prank(player2.addr);
        game.revealMove(1, player2.move, player2.secret);

        return (player1.balance, player2.balance, address(game).balance);
    }
}
