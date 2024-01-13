// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract RockPaperScissors {
    /* DATA */
    enum Hand { None, Rock, Paper, Scissors }
    enum GameStatus { WaitingForPlayer, WaitingForHandReveal, Finished }
    enum GameEndReason { NotEnded, NormalEnd, Cancelled, RevealTimedOut }

    struct Game {
        string id;
        uint256 bet;
        GameStatus status;
        uint256 createTime;
        uint256 startTime;
        uint256 endTime;
        address winner;
        address player1;
        address player2;
        bytes32 player1Commit;
        Hand player1Hand;
        Hand player2Hand;
        GameEndReason endReason;
    }

    mapping(string => Game) public games;
    string[] public gameIdsArray;
    mapping(Hand => uint256) public handCounts;
    mapping(string => bool) public gameIds;

    uint256 constant REVEAL_TIMEOUT = 10 minutes;
    uint256 constant MIN_BET = 1e15;
    uint256 public gameIdCounter = 0;

    /* EVENTS */
    event GameCreated(string gameId, address indexed player1, uint256 bet, bytes32 player1Commit);
    event GameJoined(string gameId, address indexed player2, Hand player2Hand, uint256 startTime);
    event GameFinished(string gameId, address indexed winner, GameEndReason endReason, Hand player1Hand);
    event GameCancelled(string gameId);
    event RevealTimedOut(string gameId);

    /* FUNCTIONS */
    function startGame(string memory gameId, bytes32 player1Commit, uint256 bet) external payable {
        require(msg.value == bet, "Incorrect bet amount");
        require(bet >= MIN_BET, "Bet amount is less than the minimum bet");
        
        bytes memory gameIdBytes = bytes(gameId);
        require(gameIdBytes.length == 8, "Invalid ID format"); // 2 characters for '0x' and 6 alphanumeric characters
        require(gameIdBytes[0] == '0' && gameIdBytes[1] == 'x', "Invalid ID format");
        for (uint256 i = 2; i < 8; i++) {
            require((gameIdBytes[i] >= '0' && gameIdBytes[i] <= '9') || (gameIdBytes[i] >= 'a' && gameIdBytes[i] <= 'f') || (gameIdBytes[i] >= 'A' && gameIdBytes[i] <= 'F'), "Invalid ID format");
        }
        require(!gameIds[gameId], "ID already exists");

        gameIds[gameId] = true;

        games[gameId] = Game({
            id: gameId,
            player1: msg.sender,
            player2: address(0),
            bet: bet,
            player1Commit: player1Commit,
            player1Hand: Hand.None,
            player2Hand: Hand.None,
            status: GameStatus.WaitingForPlayer,
            endReason: GameEndReason.NotEnded,
            startTime: 0,
            createTime: block.timestamp,
            endTime: 0,
            winner: address(0)
        });
        gameIdsArray.push(gameId);
        gameIdCounter++;
        emit GameCreated(gameId, msg.sender, bet, player1Commit);
    }

    function joinGame(string memory gameId, Hand player2Hand) external payable {
        require(gameIds[gameId], "Game doesnt exist");
        Game storage game = games[gameId];
        require(game.status == GameStatus.WaitingForPlayer, "Game not available");
        require(msg.value == game.bet, "Incorrect bet amount");
        require(msg.sender != game.player1, "Cannot join your own game");
        require(player2Hand > Hand.None && player2Hand <= Hand.Scissors, "Invalid hand");
        game.player2 = msg.sender;
        game.player2Hand = player2Hand;
        game.startTime = block.timestamp;
        game.status = GameStatus.WaitingForHandReveal;
        handCounts[player2Hand]++;
        emit GameJoined(gameId, msg.sender, player2Hand, game.startTime);
    }

    function revealHand(string memory gameId, Hand player1Hand, string memory secret) external {
        require(gameIds[gameId], "Game doesnt exist");
        Game storage game = games[gameId];
        require(game.status == GameStatus.WaitingForHandReveal, "Cannot reveal hand now");
        require(game.player1 == msg.sender, "Not your game");
        require(keccak256(abi.encode(player1Hand, secret)) == game.player1Commit, "Hand does not match commit");
        game.player1Hand = player1Hand;
        handCounts[player1Hand]++;
        if ((player1Hand == Hand.Rock && game.player2Hand == Hand.Scissors) ||
            (player1Hand == Hand.Paper && game.player2Hand == Hand.Rock) ||
            (player1Hand == Hand.Scissors && game.player2Hand == Hand.Paper)) {
            game.winner = game.player1;
            payable(game.player1).transfer(game.bet * 2);
        } else if (player1Hand == game.player2Hand) {
            game.winner = address(0);
            payable(game.player1).transfer(game.bet);
            payable(game.player2).transfer(game.bet);
        } else {
            game.winner = game.player2;
            payable(game.player2).transfer(game.bet * 2);
        }
        game.status = GameStatus.Finished;
        game.endReason = GameEndReason.NormalEnd;
        game.endTime = block.timestamp;
        emit GameFinished(gameId, game.winner, GameEndReason.NormalEnd, player1Hand);
    }

    function claimTimeout(string memory gameId) external {
        Game storage game = games[gameId];
        require(game.status == GameStatus.WaitingForHandReveal, "Cannot claim timeout now");
        require(block.timestamp > game.startTime + REVEAL_TIMEOUT, "Cannot claim timeout yet");
        game.winner = game.player2;
        game.status = GameStatus.Finished;
        game.endReason = GameEndReason.RevealTimedOut;
        game.endTime = block.timestamp;
        payable(game.player2).transfer(game.bet * 2);
        emit RevealTimedOut(gameId);
        emit GameFinished(gameId, game.winner, GameEndReason.RevealTimedOut, Hand.None);
    }

    function cancelGame(string memory gameId) external {
        Game storage game = games[gameId];
        require(game.status == GameStatus.WaitingForPlayer, "Game cannot be cancelled now");
        require(game.player1 == msg.sender, "Not your game");
        game.status = GameStatus.Finished;
        game.endReason = GameEndReason.Cancelled;
        game.endTime = block.timestamp;
        payable(game.player1).transfer(game.bet);
        emit GameCancelled(gameId);
    }

    // get a list of all games
    function getAllGames() external view returns (Game[] memory) {
        Game[] memory gamesArray = new Game[](gameIdsArray.length);
        for (uint256 i = 0; i < gameIdsArray.length; i++) {
            gamesArray[i] = games[gameIdsArray[i]];
        }
        return gamesArray;
    }

    // get the number of games
    function getGamesCount() external view returns (uint256) {
        return gameIdCounter;
    }

    function getPlayerStats(address player) external view returns (uint256 gamesPlayed, uint256 gamesWon, uint256 gamesLost) {
        for (uint256 i = 0; i < gameIdsArray.length; i++) {
            Game storage game = games[gameIdsArray[i]];
            if (game.player1 == player || game.player2 == player) {
                gamesPlayed++;
                if (game.winner == player) {
                    gamesWon++;
                } else if (game.winner != address(0)) {
                    gamesLost++;
                }
            }
        }
        return (gamesPlayed, gamesWon, gamesLost);
    }

    function getJoinableGames() external view returns (Game[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < gameIdsArray.length; i++) {
            if (games[gameIdsArray[i]].status == GameStatus.WaitingForPlayer) {
                count++;
            }
        }
        Game[] memory joinableGames = new Game[](count);
        count = 0;
        for (uint256 i = 0; i < gameIdsArray.length; i++) {
            if (games[gameIdsArray[i]].status == GameStatus.WaitingForPlayer) {
                joinableGames[count] = games[gameIdsArray[i]];
                count++;
            }
        }
        return joinableGames;
    }

    function getGame(string memory gameId) external view returns (Game memory) {
        return games[gameId];
    }

    function getHandStats() external view returns (uint256, uint256, uint256) {
        return (handCounts[Hand.Rock], handCounts[Hand.Paper], handCounts[Hand.Scissors]);
    }
}