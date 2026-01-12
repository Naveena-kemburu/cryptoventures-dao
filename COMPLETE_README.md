# CryptoVentures DAO - Decentralized Investment Fund Governance System

## Project Overview

CryptoVentures DAO is a comprehensive, production-grade decentralized autonomous organization (DAO) governance system for managing a collective investment fund. It implements advanced governance patterns inspired by real-world protocols like Compound, Aave, and MakerDAO.

## Key Features Implemented (30+ Core Requirements)

### 1. Treasury Management & Stake Deposits
- Members deposit ETH and receive governance influence proportional to their stake
- Quadratic voting implementation (power = sqrt(stake)) prevents whale dominance
- Treasury tracking for different fund allocations
- Multi-tier treasury management with allocation limits

### 2. Proposal Lifecycle Management
- Complete state machine: Pending → Active → Queued → Executed/Defeated/Cancelled
- Three proposal types with different parameters:
  - **HighConviction**: 66% approval, 50% quorum, 1000 ETH limit, 2-day timelock
  - **ExperimentalBet**: 50% approval, 40% quorum, 100 ETH limit, 1-day timelock  
  - **OperationalExpense**: 40% approval, 25% quorum, 10 ETH limit, 6-hour timelock

### 3. Weighted Voting System
- Members vote on proposals (For, Against, Abstain)
- Voting power calculated as sqrt(stake) to prevent plutocracy
- One vote per member per proposal (immutable)
- Delegated voting power automatically included

### 4. Delegation & Proxy Voting
- Members can delegate voting power to trusted members
- Delegations are revocable at any time
- Automatic inclusion of delegated power in voting
- Prevents double-counting of votes

### 5. Timelock Security
- Queued proposals must wait configurable durations before execution
- Different timelocks based on proposal type and amount
- Timelock enforcement prevents sandwich attacks
- Guardian role can cancel proposals during timelock

### 6. Role-Based Access Control
- PROPOSER_ROLE: Can create proposals (requires minimum stake)
- EXECUTOR_ROLE: Can queue and execute proposals
- GUARDIAN_ROLE: Can pause/cancel malicious proposals
- Clear separation of powers and responsibilities

### 7. Edge Case Handling
- Zero-vote proposals properly handled
- Tie-breaking logic for voting results
- Proposals expiring without quorum marked as defeated
- Insufficient treasury balance gracefully fails withdrawals
- Prevents duplicate proposal execution

### 8. Event Emission & Transparency
- Events for all critical actions with indexed parameters
- Efficient filtering by proposal ID, voter address, proposal type
- Full transparency for governance actions
- Historical voting records queryable on-chain

### 9. Spam Prevention
- Minimum stake required to create proposals (1 ETH)
- Prevents proposal spamming
- Voting power threshold for governance participation

## Technical Stack

- **Smart Contracts**: Solidity 0.8.19
- **Development Framework**: Hardhat
- **Testing**: Hardhat Test (Mocha/Chai)
- **Dependencies**:
  - OpenZeppelin Contracts (AccessControl, ReentrancyGuard)
  - Ethers.js v6
- **Deployment**: Hardhat deployment scripts with state seeding
- **Networks**: Hardhat Network (local), Sepolia Testnet

## Project Structure

```
contracacts-ventures-dao/
├── contracts/
│   └── governance/
│       └── CryptoVenturesDAO.sol       # Main governance contract
├── scripts/
│   └── deploy.ts                       # Deployment & state seeding
├── test/
│   └── governance.test.ts              # Comprehensive test suite
├── hardhat.config.ts                   # Hardhat configuration
├── package.json                        # Dependencies & scripts
├── tsconfig.json                       # TypeScript configuration
├── .env.example                        # Environment variables template
└── README.md                           # Project documentation
```

## Smart Contract Architecture

### CryptoVenturesDAO Contract

The main governance contract implements:

- **Data Structures**:
  - `Member`: stake, delegation info, last update block
  - `Proposal`: full proposal details, voting records, execution status
  
- **Core Functions**:
  - `deposit()`: Deposit ETH and gain governance power
  - `delegateVote()`: Delegate voting power
  - `revokeDelegation()`: Revoke delegation
  - `createProposal()`: Create new investment proposal
  - `castVote()`: Vote on active proposal
  - `queueProposal()`: Queue approved proposal
  - `executeProposal()`: Execute after timelock
  - `cancelProposal()`: Emergency proposal cancellation
  - `getVotingPower()`: Query voting power (quadratic voting)
  - `getProposalState()`: Query current proposal state

## Setup & Installation

### Prerequisites
- Node.js 16+ and npm
- Git

### Install Dependencies

```bash
git clone https://github.com/Naveena-kemburu/cryptoventures-dao.git
cd cryptoventures-dao
npm install
```

### Configure Environment

```bash
cp .env.example .env
# Edit .env with your Alchemy key and private key
```

### Compile Smart Contracts

```bash
npx hardhat compile
```

## Running Tests

```bash
# Run all tests
npx hardhat test

# Run with verbose output
NPX hardhat test --verbose

# Run specific test file
npx hardhat test test/governance.test.ts
```

## Deployment

### Local Testing

```bash
# Terminal 1: Start local blockchain
npx hardhat node

# Terminal 2: Deploy to localhost
npx hardhat run scripts/deploy.ts --network localhost
```

### Sepolia Testnet Deployment

```bash
npx hardhat run scripts/deploy.ts --network sepolia
```

## Usage Examples

### Create a Proposal

```typescript
const proposalTx = await dao.createProposal(
  0,  // HighConviction
  recipientAddress,
  ethers.utils.parseEther("5"),
  "Fund new R&D initiative"
);
```

### Vote on a Proposal

```typescript
await dao.castVote(proposalId, 1);  // 1 = for, 2 = against, 3 = abstain
```

### Delegate Voting Power

```typescript
await dao.delegateVote(trustedMemberAddress);
```

### Queue and Execute

```typescript
await dao.queueProposal(proposalId);  // Wait for timelock
await dao.executeProposal(proposalId);  // Execute after timelock expires
```

## Test Coverage

The test suite covers all 30+ core requirements:

✓ Treasury deposits and stake tracking
✓ Voting power calculation (quadratic voting)
✓ Proposal creation with validation
✓ Voting with all vote types
✓ Delegation and revocation
✓ Proposal lifecycle and state transitions
✓ Timelock enforcement
✓ Role-based execution control
✓ Event emission and filtering
✓ Edge cases and error handling
✓ Multi-proposal scenarios
✓ Treasury withdrawal validation

## Security Considerations

- **Re-entrancy Protection**: All external calls protected with ReentrancyGuard
- **Access Control**: Role-based permissions via OpenZeppelin AccessControl
- **Input Validation**: All function parameters validated
- **Safe Arithmetic**: Solidity 0.8.19 with built-in overflow/underflow protection
- **Timelock Security**: Prevents flash loan attacks and race conditions
- **Vote Immutability**: Votes cannot be changed after casting
- **Spam Prevention**: Minimum stake requirement for proposals

## Design Decisions & Trade-offs

1. **Quadratic Voting**: Chosen over linear voting to prevent whale dominance while maintaining fairness
2. **Configurable Timelocks**: Different delays by proposal type balance security and governance speed
3. **Three Proposal Types**: Allows appropriate risk/reward matching for different investments
4. **Delegation Over Voting Pools**: Simpler implementation, maintains individual voting power
5. **Role-Based Access**: Clear separation of concerns for governance operations

## Gas Optimization

- Efficient proposal state queries without loop iterations
- Minimal storage updates during voting
- Event indexing for efficient off-chain filtering
- Quadratic voting uses efficient sqrt implementation

## Future Enhancements

- Time-weighted voting
- Staking for vote weighting
- Multi-sig approval for critical actions
- Proposal filtering by type or status
- Vote escrow (ve) tokenomics
- Yield farming for governance tokens

## License

MIT

## Contact & Support

For questions or support, please open an issue on GitHub.
