// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {Helperconfig} from "./Helperconfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public returns(uint64){
        Helperconfig helperconfig = new Helperconfig();
        ( , , , , ,address vrfCoordinator,  ,uint256 deployerKey) = helperconfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator,deployerKey);
    }

    function createSubscription(address vrfCoordinator,uint256 deployerKey) public returns(uint64){
        console.log("creating subscription on chainId:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 sub_id = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subID is",sub_id); 
        console.log("please update subscriptionID in helperconfig.s.sol"); 
        return sub_id;
    }

    function run() external returns(uint64){
        return createSubscriptionUsingConfig();
    }

}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public{
        Helperconfig helperconfig = new Helperconfig();
        ( uint64 subId, , , , ,address vrfCoordinator, address link,uint256 deployerkey) = helperconfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator,subId,link,deployerkey);
    }

    function fundSubscription(address vrfcoordinator,uint64 subId, address link,uint256 deployerkey)public {
        console.log("Funding subscription",subId);
        console.log("using vrfcoordinato",vrfcoordinator); 
        console.log("On chainId",block.chainid);
        if(block.chainid == 31337){
            vm.startBroadcast(deployerkey);
            VRFCoordinatorV2Mock(vrfcoordinator).fundSubscription(subId,FUND_AMOUNT);
            vm.stopBroadcast();
        }else{
            vm.startBroadcast(deployerkey);
            LinkToken(link).transferAndCall(vrfcoordinator,FUND_AMOUNT,abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}


// Add a contract to be able to add a consumer
contract Addconsumer is Script{

    function addConsumer(address raffle,address vrfCoordinator, uint64 subId,uint256 deployerkey) public {
        console.log("Adding Consumer contract:", raffle);
        console.log("Using vrfCoordinator:",vrfCoordinator);
        console.log("On chainId",block.chainid);
        vm.startBroadcast(deployerkey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId,raffle); 
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        Helperconfig helperConfig = new Helperconfig();
        (uint64 subId , ,  , , ,address vrfCoordinator, address link, uint256 deployerkey) = helperConfig
        .activeNetworkConfig();

        addConsumer(raffle,vrfCoordinator,subId,deployerkey);

    }
    function run() external {
         address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
          block.chainid
          );
          addConsumerUsingConfig(raffle);
    }
}