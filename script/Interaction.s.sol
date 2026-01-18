// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "chainlink-contracts/mocks/MockLinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address _vrfCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on chainId:", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription(); // performing deployed mock contract  call
        vm.stopBroadcast();

        console.log("Your subID:", subId);

        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function createSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address LinkTokenAddr = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, LinkTokenAddr);
    }

    function fundSubscription(address _vrfCoordinator, uint256 _subscriptionId, address linkToken) public {
        console.log("funding Subscription: ", _subscriptionId);
        console.log("using vrfCoordinator: ", _vrfCoordinator);
        console.log("on Chainid: ", block.chainid);
        console.log("with LinkToken addr: ", linkToken);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            MockLinkToken(linkToken).transferAndCall(_vrfCoordinator, FUND_AMOUNT, abi.encode(_subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function createConsumerUsingConfig(address RecentDeployedAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        addConsumer(RecentDeployedAddress, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address recentlyDeployed, address vrfCoordinator, uint256 subId) public {
        console.log("adding Consumer to vrfCoordinator: ", vrfCoordinator);
        console.log("adding consumer contract: ", recentlyDeployed);
        console.log("on Chainid: ", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, recentlyDeployed);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("raffle", block.chainid);
        createConsumerUsingConfig(mostRecentlyDeployed);
    }
}
