// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Types.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {console} from "forge-std/Script.sol";

contract Game is ReentrancyGuard {
    using PriceConverter for uint256;

    AggregatorV3Interface internal priceFeed;

    struct Player {
        address addr;
        bytes32 hashedMove;
        Move move;
    }

    struct Room {
        Player[2] players;
        GameState gameState;
        uint256 betAmount;
        uint256 revealDeadline;
        uint256 roomId;
    }

    // Constants
    uint256 public constant GAME_FEE_PERCENT_DIVISOR = 10000; // 0.01% paid to owner, amount / 10000
    uint256 public constant CONVERTER = 10 ** 18;
    uint256 public constant MIN_BET_USD = 5 * CONVERTER; // 5 USD

    // State variables
    address public owner;
    mapping(uint256 => Room) public rooms;
    uint256 public roomCount; // To generate unique room ids

    // Events
    event MoveRevealed(uint256 roomId, address player, Move move);
    event GameWin(uint256 roomId, address winner, uint256 prize);
    event GameDraw(uint256 roomId, address player1, address player2);

    constructor(address _priceFeed) {
        owner = msg.sender;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Player 1 creates a room with a hashed move
    function createRoom(bytes32 _hashedMove) external payable nonReentrant {
        require(msg.value.getConversionRate(priceFeed) >= MIN_BET_USD, "Bet amount is below the minimum requirement");
        // Check if room already exists. Create room.
        // Save gas by removing the check since lookup is expensive (after removing race condition)
        roomCount++;
        bool roomExists = rooms[roomCount].players[0].addr != address(0);
        require(!roomExists, "Room already exists");
        Room storage room = rooms[roomCount];
        // Player 1 joins the room.
        room.players[0] = Player(msg.sender, _hashedMove, Move.None);
        room.betAmount = msg.value;
        room.gameState = GameState.WaitingForPlayer2;
        room.roomId = roomCount;
    }

    // Player 2 joins the room with a hashed move
    function joinRoom(uint256 _roomId, bytes32 _hashedMove) external payable nonReentrant {
        Room storage room = rooms[_roomId];
        require(room.gameState == GameState.WaitingForPlayer2, "Room is not accepting new players");
        require(msg.value == room.betAmount, "Bet amount must be equal to the first player's bet");
        // Player 2 joins the room.
        room.players[1] = Player(msg.sender, _hashedMove, Move.None);
        room.betAmount += msg.value;
        room.gameState = GameState.Reveal;
        room.revealDeadline = block.timestamp + 1 days;
    }

    // Both players have to reveal their moves to determine the winner
    function revealMove(uint256 _roomId, Move _move, string calldata _secret) external nonReentrant {
        Room storage room = rooms[_roomId];
        require(room.gameState == GameState.Reveal, "Game is not in reveal state");
        require(block.timestamp <= room.revealDeadline, "Reveal period has ended");

        for (uint256 i = 0; i < room.players.length; i++) {
            if (room.players[i].addr == msg.sender) {
                require(
                    keccak256(abi.encodePacked(_move, _secret)) == room.players[i].hashedMove, "Invalid move or secret"
                );
                room.players[i].move = _move;
                emit MoveRevealed(_roomId, msg.sender, _move);
            }
        }

        if (room.players[0].move != Move.None && room.players[1].move != Move.None) {
            determineWinner(room);
        }
    }

    function forfeit(uint256 _roomId) external nonReentrant {
        Room storage room = rooms[_roomId];
        require(room.gameState == GameState.Reveal, "Game is not in reveal state");
        require(block.timestamp > room.revealDeadline, "Reveal period has not ended");

        address winner;

        if (room.players[0].move == Move.None) {
            winner = room.players[1].addr;
        } else {
            winner = room.players[0].addr;
        }

        if (winner != address(0)) {
            payWinner(room, winner);
        } else {
            refundPlayers(room);
            emit GameDraw(_roomId, room.players[0].addr, room.players[1].addr);
        }

        resetGame(_roomId);
    }

    // Owner can only withdraw game fees, not the entire balance
    // function withdraw(uint256 _amount) external onlyOwner nonReentrant {
    // require(_amount <= address(this).balance, "Withdraw amount exceeds contract balance");
    // (bool success,) = owner.call{value: _amount}("");
    // require(success, "Withdraw failed");
    // }

    function getRoomStatus(uint256 _roomId) external view returns (string memory) {
        Room storage room = rooms[_roomId];

        if (room.players[0].addr == address(0)) {
            return "Room does not exist";
        }

        if (room.gameState == GameState.WaitingForPlayer2) {
            return "Room is waiting for player 2";
        } else if (room.gameState == GameState.Reveal) {
            return "Room is in reveal state";
        } else {
            return "Unknown room state.";
        }
    }

    function determineWinner(Room memory _room) internal {
        address winner;

        if (_room.players[0].move == _room.players[1].move) {
            // Draw, refund both players
            refundPlayers(_room);
        } else if (
            (_room.players[0].move == Move.Rock && _room.players[1].move == Move.Scissors)
                || (_room.players[0].move == Move.Paper && _room.players[1].move == Move.Rock)
                || (_room.players[0].move == Move.Scissors && _room.players[1].move == Move.Paper)
        ) {
            // Player 1 wins
            winner = _room.players[0].addr;
        } else {
            // Player 2 wins
            winner = _room.players[1].addr;
        }

        if (winner != address(0)) {
            payWinner(_room, winner);
        } else {
            emit GameDraw(_room.roomId, _room.players[0].addr, _room.players[1].addr);
        }

        resetGame(_room.roomId);
    }

    function payWinner(Room memory room, address _winner) internal {
        uint256 game_fee = room.betAmount / GAME_FEE_PERCENT_DIVISOR;
        uint256 prize = room.betAmount - game_fee;

        (bool successPayWinner,) = _winner.call{value: prize}(""); // Pay winner
        require(successPayWinner, "Winner payment failed");
        (bool successPayOwner,) = owner.call{value: game_fee}(""); // Pay owner
        require(successPayOwner, "Owner game fees payment failed");

        emit GameWin(room.roomId, _winner, prize);
    }

    function refundPlayers(Room memory _room) internal {
        uint256 refundAmount = _room.betAmount / 2;
        (bool successPlayer1,) = _room.players[0].addr.call{value: refundAmount}("");
        require(successPlayer1, "Refund failed for player 1");
        (bool successPlayer2,) = _room.players[1].addr.call{value: refundAmount}("");
        require(successPlayer2, "Refund failed for player 2");
    }

    function resetGame(uint256 _roomId) internal {
        delete rooms[_roomId];
    }

    function getPriceFeedVersion() external view returns (uint256) {
        return priceFeed.version();
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}
