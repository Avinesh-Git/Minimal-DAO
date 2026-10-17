//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay is minimum time you have to wait before execution.
    // proposers is the list of addresses that can propose.
    // executors is the list of addresses that can execute.
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
