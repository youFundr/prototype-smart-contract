// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Youfundr {
    using SafeMath for uint256;

    Project[] private projects;

    event fundStarted(
        address fundAddress,
        address fundStarter,
        string fundName,
        string fundDescription,
        uint256 deadline,
        uint256 goal,
        uint256 currentAmount,
        Project.State state,
        bool donator
    );

    function startFund(
        string calldata name,
        string calldata description,
        uint deadline,
        uint amountNeeded
    ) external {
        Project newProject = new Project(
            payable(msg.sender),
            name,
            description,
            deadline,
            amountNeeded
        );
        projects.push(newProject);

        emit fundStarted(
            address(newProject),
            msg.sender,
            name,
            description,
            deadline,
            amountNeeded,
            0,
            newProject.state(),
            false
        );
    }

    function allProjects() external view returns (Project[] memory) {
        return projects;
    }

    receive() external payable {}

    fallback() external payable {}
}

contract Project {
    using SafeMath for uint256;

    enum State {
        Fundraising,
        Expired,
        Successful
    }

    address payable public founder;
    uint public amountNeeded;
    uint public completeAt;
    uint256 public currentBalance;
    uint public raiseBy;
    string public name;
    string public description;
    State public state;

    mapping(address => uint) public donations;

    event MoneyReceived(address contributor, uint amount, uint currentTotal);

    event FounderPaid(address recipient);

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    modifier isFounder() {
        require(msg.sender == founder);
        _;
    }

    constructor(
        address payable fundStarter,
        string memory fundName,
        string memory fundDescription,
        uint fundRaisingDeadline,
        uint goal
    ) {
        founder = fundStarter;
        name = fundName;
        description = fundDescription;
        amountNeeded = goal;
        raiseBy = fundRaisingDeadline;
        currentBalance = 0;
        state = State.Fundraising;
    }

    function sendFunds() external payable inState(State.Fundraising) {
        require(msg.sender != founder);
        donations[msg.sender] = donations[msg.sender].add(msg.value);
        currentBalance = currentBalance.add(msg.value);
        emit MoneyReceived(msg.sender, msg.value, currentBalance);
        transferCompletedOrExpired();
    }

    function transferCompletedOrExpired() public {
        if (currentBalance >= amountNeeded) {
            state = State.Successful;
            payFounder();
        } else if (block.timestamp > raiseBy) {
            state = State.Expired;
        }
        completeAt = block.timestamp;
    }

    function payFounder() internal inState(State.Successful) returns (bool) {
        uint256 moneyRaised = currentBalance;
        currentBalance = 0;

        if (founder.send(moneyRaised)) {
            emit FounderPaid(founder);
            return true;
        } else {
            currentBalance = moneyRaised;
            state = State.Successful;
        }
        return false;
    }

    function refundSenders() public inState(State.Expired) returns (bool) {
        require(donations[msg.sender] > 0);

        uint refundingAmount = donations[msg.sender];
        donations[msg.sender] = 0;

        if (!payable(msg.sender).send(refundingAmount)) {
            donations[msg.sender] = refundingAmount;
            return false;
        } else {
            currentBalance = currentBalance.sub(refundingAmount);
        }

        return true;
    }

    function details()
        public
        view
        returns (
            address projectAddress,
            address payable fundStarter,
            string memory fundName,
            string memory fundDescription,
            uint256 deadline,
            State currentState,
            uint256 currentAmount,
            uint256 goal,
            bool donator
        )
    {
        projectAddress = address(this);
        fundStarter = founder;
        fundName = name;
        fundDescription = description;
        deadline = raiseBy;
        currentState = state;
        currentAmount = currentBalance;
        goal = amountNeeded;
        donator = (donations[msg.sender] > 0 ? true : false);
    }

    receive() external payable {}

    fallback() external payable {}
}
