// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract RPS {
    constructor() payable{}
    // gameCreate, gameJoin을 할 때 실행한 주소, 베팅한 금액, 방에 들어있는 총 베팅금액을 이벤트로 출력해준다.
    event checkAmount(address sender, uint playerBetEther, uint gameBetEther);
    // 공평한 게임을 위해, 룸넘버를 입력하면 해당 방의 originator가 지불한 금액이 나온다.
    event howMuch(uint amountForJoinTheRoom);
    event whoWin(string winner, string loser);
    event tie(string tie);
    

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
        require((_hand == Hand.rock) || (_hand == Hand.paper) || (_hand == Hand.scissors), "It's not Valid");
        _;
    }

    // 게임을 실행해보니, originator가 금액을 지불하고 방을 만들었는데 joiner는 돈을 지불하지 않고 참여해서 이기면 돈을 가져가는 구조가 발생했다.
    // 아래 modifier에서는 require문을 통해서 joiner가 참여할 때 originator가 지불한 금액과 같은 amount를 지불해야하도록 강제한다.
    // => joinGame 함수에 적용
    modifier FairGame(uint originatorBetAmount) {
        require(originatorBetAmount == msg.value, "Your payment must be equal to originator's. Click the function 'checkRoomAmout' with roomNumber");
        _;
    }

    //금액이 너무 작아지지 않기위해 최소금액을 1 ether로 설정하였다. => createGame 함수에 적용
    modifier least1Ether() {
        require(msg.value >= 1 ether, "You have to pay more than 1 ether");
        _;
    }

    // 개선해야할 부분 중, 숫자를 기입하여 createRoom 함수를 실행하면, 트랜잭션 정보의 decoded input에 originator가 입력한 값이 그대로 노출되게 된다.
    // 이에 대한 악용을 방지하기 위해 함수를 생성하여 인풋값 없이 실행해도 원하는 값과 함께 방을 생성할 수 있도록 하였다.
    function createGameWithRock() public payable {
        createGame(Hand.rock);
    }

    function createGameWithPaper() public payable {
        createGame(Hand.paper);
    }

    function createGameWithScissors() public payable {
        createGame(Hand.scissors);
    }

    // function createGame(Hand _hand) public payable least1Ether returns(uint roomNum) {
    //     rooms[roomLength] = Game({
    //         originator : Player({
    //             addr : payable(msg.sender),
    //             playerBetAmount : msg.value,
    //             hand : _hand,
    //             playerStatus : PlayerStatus.pending
    //         }),
    //         joiner : Player({
    //             addr : payable(msg.sender),
    //             playerBetAmount : 0,
    //             hand : Hand.rock,
    //             playerStatus : PlayerStatus.pending
    //         }),
    //         gameBetAmount : msg.value,
    //         gameStatus : GameStatus.pending
    //     });
    //     // 이벤트로 출력됐을 때 알아보기 편하게 이더 단위로 나눠서 출력해준다.
    //     emit checkAmount(rooms[roomNum].originator.addr, rooms[roomNum].originator.playerBetAmount / 1 ether, rooms[roomNum].gameBetAmount / 1 ether);
    //     roomNum = roomLength;
    //     roomLength = roomLength+1;
    // }

    function createGame(Hand _hand) private returns(uint) {
        rooms[roomLength] = Game({
            originator : Player({
                addr : payable(msg.sender),
                playerBetAmount : 0,
                hand : _hand,
                playerStatus : PlayerStatus.pending
            }),
            joiner : Player({
                addr : payable(msg.sender),
                playerBetAmount : 0,
                hand : Hand.rock,
                playerStatus : PlayerStatus.pending
            }),
            gameBetAmount : 0,
            gameStatus : GameStatus.pending
        });
        rooms[roomLength].gameBetAmount = rooms[roomLength].originator.playerBetAmount;
        // 이벤트로 출력됐을 때 알아보기 편하게 이더 단위로 나눠서 출력해준다.
        uint roomNum = roomLength;
        roomLength = roomLength+1;
        return roomNum;
    }

    function insertEther(uint roomNum) public payable least1Ether {
        rooms[roomNum].originator.playerBetAmount = msg.value;
        rooms[roomNum].gameBetAmount = msg.value;
        emit checkAmount(rooms[roomNum].originator.addr, rooms[roomNum].originator.playerBetAmount / 1 ether, rooms[roomNum].gameBetAmount / 1 ether);
    }

    // 룸 넘버를 입력하여 해당 룸의 예치금이 얼마인지 확인하고 그에 맞춰 룸에 입장할 수 있도록 도와주는 함수
    function checkRoomAmount(uint roomNum) public {
        emit howMuch(rooms[roomNum].originator.playerBetAmount / 1 ether);
    }

    // joiner가 originator와 같은 amount의 value를 지불하도록 강제하기위해 rooms에 저장되어있는 originator의 amount를 modifier의 인자로 건네주었다.
    // joiner는 위 checkRoomAmount 함수를 통해 룸에 예치되어있는 금액을 확인하고 이에 맞춰 금액을 지불해야 입장할 수 있다.
    function joinGame(uint roomNum, Hand _hand) payable FairGame(rooms[roomNum].originator.playerBetAmount) public {
        rooms[roomNum].joiner = Player({
            addr : payable(msg.sender),
            playerBetAmount : msg.value,
            hand : _hand,
            playerStatus : PlayerStatus.pending
        });
        rooms[roomNum].gameBetAmount = rooms[roomNum].gameBetAmount + msg.value;
        emit checkAmount(rooms[roomNum].joiner.addr, rooms[roomNum].joiner.playerBetAmount / 1 ether, rooms[roomNum].gameBetAmount / 1 ether);
        compareHand(roomNum);
        // 원래는 payOut 함수를 public으로 활성화할때 돈을 주는 형식이었는데, joiner가 참여하면서 본인의 HAND를 제시하면 곧바로 결과가 나오기때문에
        // 바로 payOut함수를 실행하여 결괏값을 반환하도록 하였다.
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
    
    function compareHand(uint roomNum) private {
        uint originator = uint(rooms[roomNum].originator.hand);
        uint joiner = uint(rooms[roomNum].joiner.hand);
        rooms[roomNum].gameStatus = GameStatus.start;

        if(originator == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.tie;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.tie;
            emit tie("tie");
        } else if ((originator + 1) % 3 == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.lose;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.win;
            emit whoWin("joiner", "originator");
        } else if ((originator + 2) % 3 == joiner) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.win;
            rooms[roomNum].joiner.playerStatus = PlayerStatus.lose;
            emit whoWin("originator", "joiner");
        }
    }
}