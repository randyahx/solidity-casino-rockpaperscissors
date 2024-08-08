// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

enum Move {
    None,
    Rock,
    Paper,
    Scissors
}

enum GameState {
    WaitingForPlayer2,
    Reveal,
    Completed
}
