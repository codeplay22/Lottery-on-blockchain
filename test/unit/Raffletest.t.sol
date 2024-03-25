// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import{Raffle} from "../../src/Raffle.sol";
import{Test, console} from "forge-std/Test.sol";
import {Helperconfig} from "../../script/Helperconfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract Raffletest is Test {

    event EnteredRaffle(address indexed player);

    Raffle raffle;
    Helperconfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit = 500000;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
   

    function setUp () external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
          vm.deal(PLAYER,STARTING_USER_BALANCE);
        (
            subscriptionId,
            gasLane,
            interval,
            entranceFee,
            callBackGasLimit,
            vrfCoordinator,
            link,
            
        ) = helperConfig.activeNetworkConfig();
      
   
    }

    function testRaffleInitialisesinOpenState() public view {
        assert(raffle.getRafflestate() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontpayEnough() public{
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        console.log("Entrance Fee:", entranceFee);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
        
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true,true,false,false,address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector); //The next call is going to revert
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        
    }

    ///////////////////////
    // Check upKeep///

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        console.log( "upkeepneeded is",upKeepNeeded);

        //assert
        assert(!upKeepNeeded);
    }
    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {

        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act

        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        console.log("upkeepNeeded is",upKeepNeeded);

        //assert
        // assert(upKeepNeeded == false);

    }

    // function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public{
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value:entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    // }

     function testCheckUpkeepReturnsTrueWhenParametersAreGood() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        console.log("upkeepneeded is", upkeepNeeded);
        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        //Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
         (bool upkeepNeeded,) = raffle.checkUpkeep("");
         console.log("upkeepNeeded is",upkeepNeeded);

        raffle.performUpkeep("");

    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed(){

        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        _;
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed{
        vm.recordLogs();
        raffle.performUpkeep(""); // emit request id
        Vm.Log [] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRafflestate();
        console.log(uint256(rState));
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);

    }

    modifier skipFork(){
        if(block.chainid != 31337 ){
            return;
        }
        _;
    }
    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork{
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork{
        //Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (uint i = 0; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player,STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }


        uint256 prize = entranceFee *(additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emit request id
        Vm.Log [] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        // pretend to be a chainlink vrf to get the random number & pick random winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //Asserts
        assert(uint256(raffle.getRafflestate()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance == 
                STARTING_USER_BALANCE + prize
            );

    }

}