// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title A Lottery Contract
 * @author Piyush Dixit
 * @notice this contract is for creating a sample raffle refers to cyfrin updraft course
 * @dev Implements Chainlink VRFv2.5
 */

// VRFConsumerBaseV2Plus is a abstract contract, it has a unimplemented function named fulfillRandomWords. So we need to define it before inherenting
import {VRFConsumerBaseV2Plus} from "chainlink-contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpened();
    error Raffle__TransferFailed();
    // error Raffle__TimeHasntComeYet();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffState);

    /* Type Declarations (ENUM)*/
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /* State Variables*/
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee;
    uint32 private immutable i_callbackGasLimit;
    bool private immutable i_enableNativePayment;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address _vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        bool enableNativePayment
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_enableNativePayment = enableNativePayment;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpened();
        }

        s_players.push(payable(msg.sender)); // payable : for address to receive eth

        // Rule of Thumb: Anytime you edit a storage variable you need to emit the event
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the chainlinks node will call to see if the lottery is ready to pick,
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly , your subscription has LINK
     * @param -ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // Pick Winner will do : (cRon JOb)
    //  - pick a random player
    //  - must be called automatically after a time period
    //  - refactor the pickWinner function to perform upkeep to keep polling the checkUpKeep function (chainlink automation)
    function performUpkeep(
        bytes calldata /* performData */
    )
        external
    {
        // check if enough time has passsed
        (bool upKeepNeeded,) = checkUpkeep(""); // change the function def to memory from calldata
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: i_enableNativePayment}))
        });

        // Get our random number from chainlink VRF
        s_vrfCoordinator.requestRandomWords(request);
    }

    // this function is gonna call by parentclass.rawfulfillRandomWords function which is external by VRF Coordinator
    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    )
        internal
        override
    {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /*
     *Getter Functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
