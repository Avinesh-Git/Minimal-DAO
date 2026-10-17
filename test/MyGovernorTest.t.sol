//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    // IVotes token = new GovToken();
    TimeLock timeLock;
    GovToken govToken;
    MyGovernor governor;
    Box box;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DEALY = 3600; // 1 hour, after a vote passes.
    uint256 public constant VOTING_DELAY = 1; // this is how many blocks till a vote is active.
    uint256 public constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;
    bytes[] callDatas;
    address[] targets;
    uint256[] values;
    // address admin;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        vm.startPrank(USER);
        govToken.delegate(USER); //votes are delegated to the user
        timeLock = new TimeLock(MIN_DEALY, proposers, executors, msg.sender);
        // vm.stopPrank();
        governor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, USER);

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        //Arrange
        vm.expectRevert();
        box.store(1);
        //Act
        //Assert
    }

    function testGovernanceUpdatesBox() public {
        //Arrange
        uint256 valueToStore = 67;
        string memory description = "store 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        callDatas.push(encodedFunctionCall);
        targets.push(address(box));
        //Act
        //1. propose to the DAO
        uint256 proposalId = governor.propose(targets, values, callDatas, description);
        // view the state of the DAO
        console.log("proposal state:", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("proposal state:", uint256(governor.state(proposalId)));
        //2. vote
        string memory reason = "trial";
        uint8 vote = 1; // voting for
        vm.startPrank(USER);
        governor.castVoteWithReason(proposalId, vote, reason);
        vm.stopPrank();
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        //3. Queue the Tx

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, callDatas, descriptionHash);
        vm.warp(block.timestamp + MIN_DEALY + 1);
        vm.roll(block.number + MIN_DEALY + 1);

        // 4. Execute Tx
        governor.execute(targets, values, callDatas, descriptionHash);

        //Assert
        console.log("box value:", box.getNumber());
        assert(box.getNumber() == valueToStore);
    }
}
