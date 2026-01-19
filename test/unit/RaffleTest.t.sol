// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BAL = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    bool enableNativePayment;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        enableNativePayment = config.enableNativePayment;

        vm.deal(PLAYER, STARTING_PLAYER_BAL);
    }

    modifier raffleEnter() {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testRaffleInitializeState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* ///////////////////////////////////////////////////////////////
                        ENTER RAFFLE
    ////////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act // Asset
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert

        assert(PLAYER == raffle.getPlayer(0));
    }

    function testRaffleEnteredEvent() public {
        // arrange
        vm.prank(PLAYER);
        // ACT
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertNotOpened() public raffleEnter {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpened.selector);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* ///////////////////////////////////////////////////////////////
                        Check Upkeep
    ////////////////////////////////////////////////////////////////*/

    function testCheckUpkeepForEnoughBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool checkUpKeep,) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }

    function testCheckUpkeepForNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        (bool checkUpKeep,) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }

    function testCheckUpkeepForClosedState() public raffleEnter {
        raffle.performUpkeep("");

        (bool checkUpKeep,) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }

    /* ///////////////////////////////////////////////////////////////
                        Constructor
    ////////////////////////////////////////////////////////////////*/

    function testRaffleConstructorInit() public {
        Raffle rafflev1 = new Raffle(
            entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, enableNativePayment
        );
        assert(rafflev1.getEntranceFee() == entranceFee);
    }

    /* ///////////////////////////////////////////////////////////////
                        Perform Upkeep
    ////////////////////////////////////////////////////////////////*/

    function testRaffleRevertUpKeepNotNeeded() public {
        vm.prank(PLAYER);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, 0, 0, 0));
        raffle.performUpkeep("");
    }

    function testPerformUpKeepEmitsRequestId() public raffleEnter {
        // Arrange

        // Act
        // read all the logs
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    /* ///////////////////////////////////////////////////////////////
                        FulFill Random Words
    ////////////////////////////////////////////////////////////////*/

    // Fuzz test (foundry test for default 256 random request id by itself)
    function testFulFillRandomWordsAfterPerformUpkeep(uint256 randomRequestId) public raffleEnter skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulFillRandomWordsPicksAWinnerAndResetsThePlayers() public raffleEnter skipFork {
        uint160 totalEntries = 4;
        for (uint160 currentPlayer = 1; currentPlayer < totalEntries; currentPlayer++) {
            hoax(address(currentPlayer), 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        address expectedWinner = address(1);
        uint256 WinnerStartingBalance = expectedWinner.balance;

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        uint256 totalAmountContractHolds = 4 * entranceFee;
        assert(address(raffle).balance == totalAmountContractHolds);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState currentState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();

        assert(winnerBalance == WinnerStartingBalance + totalAmountContractHolds);
        assert(expectedWinner == recentWinner);
        assert(currentState == Raffle.RaffleState.OPEN);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
