// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title A Lottery Contract
 * @author Piyush Dixit
 * @notice this contract is for creating a sample raffle refers to cyfrin updraft course
 * @dev Implements Chainlink VRFv2.5
 */

contract Raffle {
    /* Errors */

    error Raffle_SendMoreToEnterRaffle();

    /* State Variables*/

    uint256 private immutable i_ENTRANCE_FEE;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_Interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_ENTRANCE_FEE = entranceFee;
        i_Interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_ENTRANCE_FEE) {
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
        if ((block.timestamp - s_lastTimeStamp) < i_Interval) {
            revert();
        }

        // Get our random number

        s_lastTimeStamp = block.timestamp;
    }

    /*
     *Getter Functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_ENTRANCE_FEE;
    }
}
