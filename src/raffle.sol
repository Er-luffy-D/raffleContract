// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title A Lottery Contract
 * @author Piyush Dixit
 * @notice this contract is for creating a sample raffle refers to cyfrin updraft course
 * @dev Implements Chainlink VRFv2.5
 */

// VRFConsumerBaseV2Plus is a abstract contract, it has fulfillRandomWords functions whose implementations does not provided. So we need to override its implementation
import {VRFConsumerBaseV2Plus} from "chainlink-contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */

    error Raffle_SendMoreToEnterRaffle();

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
    /* Events */
    event RaffleEntered(address indexed player);

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
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_enableNativePayment = enableNativePayment;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender)); // payable : for address to receive eth

        // Rule of Thumb: Anytime you edit a storage variable you need to emit the event
        emit RaffleEntered(msg.sender);
    }

    // Pick Winner will do : (cRon JOb)
    //  - pick a random player
    //  - must be called automatically after a time period
    function pickWinner() external {
        // check if enough time has passsed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: i_enableNativePayment}))
        });

        // Get our random number from chainlink VRF
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        s_lastTimeStamp = block.timestamp;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {}

    /*
     *Getter Functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
