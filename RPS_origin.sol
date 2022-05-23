// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract RPS {
    constructor() payable{}

    enum Hand {
        rock, paper, scissors
    }

    enum PlayerStatus {
        win, lose, tie, pending
    }

    enum GameStatus {
        pending, start, compelete
    }

    struct Player {
        address addr;
        uint playerBetAmount;
        Hand hand;
        PlayerStatus playerStatus;
    }

    struct Game {
        Player originator;
        Player joiner;
        uint gameBetAmount;
        GameStatus gameStatus;
    }

    mapping (uint => Game) rooms;
    uint roomLength = 0;

    modifier isValid(Hand _hand) {
        require(_hand == Hand.rock || _hand == Hand.paper || _hand == Hand.scissors);
        _;
    }

    function createGame(Hand _hand) public payable isValid(_hand) returns(uint roomNum) {
        rooms[roomLength] = Game({
            originator : Player({
                addr : payable(msg.sender),
                playerBetAmount : msg.value,
                hand : _hand,
                playerStatus : PlayerStatus.pending
            }),
            joiner : Player({
                addr : payable(msg.sender),
                playerBetAmount : 0,
                hand : Hand.rock,
                playerStatus : PlayerStatus.pending
            }),
            gameBetAmount : msg.value,
            gameStatus : GameStatus.pending
        });
        roomNum = roomLength;
        roomLength = roomLength+1;
    }

    function joinGame(uint roomNum, Hand _hand) payable public {
        rooms[roomNum].joiner = Player({
            addr : payable(msg.sender),
            playerBetAmount : msg.value,
            hand : _hand,
            playerStatus : PlayerStatus.pending
        });
        rooms[roomNum].gameBetAmount = rooms[roomNum].gameBetAmount + msg.value;
        compareHand(roomNum);
        payOut(roomNum);
    }
    
    function compareHand(uint roomNum) private {
        uint originator = uint(rooms[roomNum].originator.hand);
        uint joiner = uint(rooms[roomNum].joiner.hand);
        rooms[roomNum].gameStatus = GameStatus.start;

        if(originator == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.tie;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.tie;
        } else if ((originator + 1) % 3 == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.lose;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.win;
        } else if ((originator + 2) % 3 == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.win;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.lose;
        }
    }

    function payOut(uint roomNum) public payable {
        address payable originatorAddr = payable(rooms[roomNum].originator.addr);
        address payable joinerAddr = payable(rooms[roomNum].joiner.addr);
        uint gameBetAmount = rooms[roomNum].gameBetAmount;

        if (rooms[roomNum].originator.playerStatus == PlayerStatus.tie && rooms[roomNum].joiner.playerStatus == PlayerStatus.tie) {
            originatorAddr.transfer(rooms[roomNum].originator.playerBetAmount);
            joinerAddr.transfer(rooms[roomNum].joiner.playerBetAmount);
        } else if (rooms[roomNum].originator.playerStatus == PlayerStatus.win && rooms[roomNum].joiner.playerStatus == PlayerStatus.lose) {
            originatorAddr.transfer(gameBetAmount);
        } else if (rooms[roomNum].originator.playerStatus == PlayerStatus.lose && rooms[roomNum].joiner.playerStatus == PlayerStatus.win) {
            joinerAddr.transfer(gameBetAmount);
        }
    }
}