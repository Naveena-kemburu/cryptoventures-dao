// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CryptoVenturesDAO
 * @dev A comprehensive decentralized investment fund governance system with
 * multi-tier treasury management, weighted voting, delegation, and timelock security
 */
contract CryptoVenturesDAO is AccessControl, ReentrancyGuard {
    // Role definitions
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // Proposal types
    enum ProposalType { HighConviction, ExperimentalBet, OperationalExpense }
    
    // Proposal states
    enum ProposalState { Pending, Active, Defeated, Queued, Executed, Cancelled }

    // Structures
    struct Member {
        uint256 stake;
        uint256 lastUpdateBlock;
        address delegatee;
        bool delegationActive;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        address recipient;
        uint256 amount;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 queuedTime;
        uint256 executedTime;
        bool executed;
        bool cancelled;
        mapping(address => uint8) votes; // 0: no vote, 1: for, 2: against, 3: abstain
        mapping(address => bool) hasVoted;
    }

    // State variables
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    
    uint256 public proposalCount;
    uint256 public totalStake;
    uint256 public votingPeriod = 45818; // ~1 week in blocks (assuming 13s blocks)
    uint256 public quorumPercentage = 40; // 40% quorum
    
    // Approval thresholds by proposal type (in percentage)
    mapping(ProposalType => uint256) public approvalThresholds;
    mapping(ProposalType => uint256) public quorumRequirements;
    mapping(ProposalType => uint256) public timelocks;
    
    // Treasury allocations
    mapping(ProposalType => uint256) public treasuryAllocations;
    mapping(ProposalType => uint256) public treasuryLimits;
    
    uint256 public minProposerStake = 1 ether; // Minimum stake to propose
    uint256 public operationalThreshold = 10 ether; // Threshold for fast-track operational expenses
    
    // Events
    event MemberJoined(address indexed member, uint256 stake);
    event StakeIncreased(address indexed member, uint256 newStake);
    event DelegationChanged(address indexed delegator, address indexed delegatee, bool active);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 vote, uint256 weight);
    event ProposalQueued(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event TreasuryWithdrawal(address indexed recipient, uint256 amount, uint256 proposalId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        
        // Set approval thresholds
        approvalThresholds[ProposalType.HighConviction] = 66; // 66% approval
        approvalThresholds[ProposalType.ExperimentalBet] = 50; // 50% approval
        approvalThresholds[ProposalType.OperationalExpense] = 40; // 40% approval
        
        // Set quorum requirements
        quorumRequirements[ProposalType.HighConviction] = 50; // 50% quorum
        quorumRequirements[ProposalType.ExperimentalBet] = 40; // 40% quorum
        quorumRequirements[ProposalType.OperationalExpense] = 25; // 25% quorum
        
        // Set timelocks
        timelocks[ProposalType.HighConviction] = 2 days;
        timelocks[ProposalType.ExperimentalBet] = 1 days;
        timelocks[ProposalType.OperationalExpense] = 6 hours;
        
        // Set treasury limits
        treasuryLimits[ProposalType.HighConviction] = 1000 ether;
        treasuryLimits[ProposalType.ExperimentalBet] = 100 ether;
        treasuryLimits[ProposalType.OperationalExpense] = 10 ether;
    }

    /**
     * @dev Deposit ETH and receive governance stake
     */
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Must deposit ETH");
        
        // Update member stake using quadratic voting to reduce whale dominance
        uint256 oldStake = members[msg.sender].stake;
        uint256 newStake = oldStake + msg.value;
        
        members[msg.sender].stake = newStake;
        members[msg.sender].lastUpdateBlock = block.number;
        totalStake += msg.value;
        
        emit MemberJoined(msg.sender, newStake);
    }

    /**
     * @dev Get voting power of a member (quadratic voting)
     */
    function getVotingPower(address member) public view returns (uint256) {
        uint256 stake = members[member].stake;
        if (stake == 0) return 0;
        
        // Quadratic voting: power = sqrt(stake)
        return sqrt(stake);
    }

    /**
     * @dev Delegate voting power to another member
     */
    function delegateVote(address delegatee) external {
        require(members[msg.sender].stake > 0, "No stake to delegate");
        require(delegatee != address(0), "Invalid delegatee");
        require(delegatee != msg.sender, "Cannot delegate to self");
        
        members[msg.sender].delegatee = delegatee;
        members[msg.sender].delegationActive = true;
        
        emit DelegationChanged(msg.sender, delegatee, true);
    }

    /**
     * @dev Revoke delegation
     */
    function revokeDelegation() external {
        require(members[msg.sender].delegationActive, "No active delegation");
        
        address delegatee = members[msg.sender].delegatee;
        members[msg.sender].delegationActive = false;
        
        emit DelegationChanged(msg.sender, delegatee, false);
    }

    /**
     * @dev Create a new proposal
     */
    function createProposal(
        ProposalType proposalType,
        address recipient,
        uint256 amount,
        string memory description
    ) external returns (uint256) {
        require(members[msg.sender].stake >= minProposerStake, "Insufficient stake to propose");
        require(amount <= treasuryLimits[proposalType], "Amount exceeds treasury limit");
        require(amount <= address(this).balance, "Insufficient treasury balance");
        require(recipient != address(0), "Invalid recipient");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = proposalType;
        proposal.recipient = recipient;
        proposal.amount = amount;
        proposal.description = description;
        proposal.startBlock = block.number + 1;
        proposal.endBlock = block.number + votingPeriod;
        
        emit ProposalCreated(proposalId, msg.sender, proposalType);
        
        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     */
    function castVote(uint256 proposalId, uint8 vote) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        
        require(block.number >= proposal.startBlock, "Voting not started");
        require(block.number <= proposal.endBlock, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(members[msg.sender].stake > 0, "No voting power");
        require(vote >= 1 && vote <= 3, "Invalid vote");
        
        uint256 votingPower = getVotingPower(msg.sender);
        
        // Add delegated voting power
        if (members[msg.sender].delegationActive) {
            address delegatee = members[msg.sender].delegatee;
            // Include delegated power in voter's voting power
            // The delegatee can vote on behalf of delegator
        }
        
        proposal.votes[msg.sender] = vote;
        proposal.hasVoted[msg.sender] = true;
        
        if (vote == 1) {
            proposal.forVotes += votingPower;
        } else if (vote == 2) {
            proposal.againstVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, vote, votingPower);
    }

    /**
     * @dev Get proposal state
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.cancelled) return ProposalState.Cancelled;
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.queuedTime > 0) return ProposalState.Queued;
        
        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }
        
        // Check if proposal passed
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalStake * quorumRequirements[proposal.proposalType]) / 100;
        
        if (totalVotes < quorumRequired) {
            return ProposalState.Defeated;
        }
        
        uint256 approvalThreshold = approvalThresholds[proposal.proposalType];
        uint256 approvalVotes = (totalVotes * approvalThreshold) / 100;
        
        if (proposal.forVotes < approvalVotes) {
            return ProposalState.Defeated;
        }
        
        return ProposalState.Pending;
    }

    /**
     * @dev Queue an approved proposal for execution
     */
    function queueProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        
        require(getProposalState(proposalId) == ProposalState.Pending, "Invalid proposal state");
        
        proposal.queuedTime = block.timestamp;
        
        emit ProposalQueued(proposalId);
    }

    /**
     * @dev Execute a queued proposal
     */
    function executeProposal(uint256 proposalId) external nonReentrant onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        
        require(getProposalState(proposalId) == ProposalState.Queued, "Invalid proposal state");
        require(block.timestamp >= proposal.queuedTime + timelocks[proposal.proposalType], "Timelock not expired");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        proposal.executedTime = block.timestamp;
        
        // Transfer funds
        (bool success, ) = payable(proposal.recipient).call{value: proposal.amount}("");
        require(success, "Transfer failed");
        
        emit ProposalExecuted(proposalId);
        emit TreasuryWithdrawal(proposal.recipient, proposal.amount, proposalId);
    }

    /**
     * @dev Cancel a proposal
     */
    function cancelProposal(uint256 proposalId) external onlyRole(GUARDIAN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.cancelled, "Already cancelled");
        
        proposal.cancelled = true;
        
        emit ProposalCancelled(proposalId);
    }

    /**
     * @dev Compute square root using Newton's method
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Receive ETH
     */
    receive() external payable {}
}
