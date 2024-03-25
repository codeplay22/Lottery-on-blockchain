//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import{Helperconfig} from "./Helperconfig.s.sol";
import {CreateSubscription,FundSubscription,Addconsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script{
    function run()  external returns (Raffle, Helperconfig){
        Helperconfig helperconfig = new Helperconfig();
        (
        uint64 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        address link,
        uint256 deployerKey
        ) = helperconfig.activeNetworkConfig();

        if(subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinatorV2,deployerKey);

            //Fund It

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinatorV2,subscriptionId,link,deployerKey);

        }

        vm.startBroadcast(deployerKey);
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinatorV2,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        Addconsumer addConsumer = new Addconsumer();
        addConsumer.addConsumer(address(raffle),vrfCoordinatorV2,subscriptionId,deployerKey);
        return (raffle,helperconfig);
    }

}

