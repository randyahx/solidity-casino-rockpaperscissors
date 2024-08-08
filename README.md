## Solidity Casino RockPaperScissors  

This is a RockPaperScissors game that supports multiple rooms, betting and game fees.  

1. Player 1 creates a room
2. Player 2 joins a room
3. Either player can reveal their choice first but both have to reveal to move on.
4. Winner takes all. No game fees if the game ends in a draw and both players will be refunded.
5. If the deadline for the reveal stage passes and only 1 player has revealed, either player can select forfeit to end the game. The winner will be the player who has revealed their choice.

# Run tests  
$ forge test -vvvv  

This project is still in development.  
