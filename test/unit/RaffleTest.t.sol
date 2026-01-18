// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
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

        modifier RaffleEnter(){
         vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
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

    function testRaffleRevertNotOpened() public RaffleEnter {
       

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
        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }

    function testCheckUpkeepForNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }
    function testCheckUpkeepForClosedState() public  RaffleEnter{
     
        raffle.performUpkeep("");

        (bool checkUpKeep, ) = raffle.checkUpkeep("");
        assert(!checkUpKeep);
    }

    /* ///////////////////////////////////////////////////////////////
                        Constructor
    ////////////////////////////////////////////////////////////////*/

    function testRaffleConstructorInit() public {
        Raffle rafflev1 = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            enableNativePayment
        );
        assert(rafflev1.getEntranceFee() == entranceFee);
    }

    /* ///////////////////////////////////////////////////////////////
                        Perform Upkeep
    ////////////////////////////////////////////////////////////////*/

    function testRaffleRevertUpKeepNotNeeded() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                0,
                0,
                0
            )
        );
        raffle.performUpkeep("");
    }




    function testPerformUpKeepEmitsRequestId() public  RaffleEnter{
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
                        FullFill Random Words
    ////////////////////////////////////////////////////////////////*/
    
}
