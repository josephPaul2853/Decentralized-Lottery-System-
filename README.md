# Decentralized Lottery System

A provably fair lottery smart contract with transparent random number generation, multiple prize tiers, and automatic winner selection.

## Features

- **Provably Fair**: Uses block height and keccak256 hashing for transparent randomness
- **Multiple Prize Tiers**: 60% jackpot, 20% second prize, 10% third prize, 10% house fee
- **Fraud Prevention**: Immutable ticket records and transparent draw process
- **Automatic Winner Selection**: Deterministic winner selection based on ticket numbers
- **Prize Claims**: Winners must claim prizes manually for security

## Core Functions

### Owner Functions
- `start-lottery()` - Starts a new lottery round (24-hour duration)
- `emergency-stop()` - Emergency halt for security
- `withdraw-house-fees()` - Collect 10% house fees

### User Functions
- `buy-ticket()` - Purchase lottery ticket for 1 STX
- `claim-prize(lottery-id)` - Claim won prizes

### Drawing
- `draw-lottery()` - Execute draw after 24 hours (~144 blocks)

## Prize Distribution

| Tier | Percentage | Description |
|------|------------|-------------|
| Jackpot | 60% | Single winner |
| Second | 20% | Single winner |
| Third | 10% | Single winner |
| House | 10% | Platform fee |

## Security Features

1. **Block-height based timing** - Prevents manipulation of draw timing
2. **Deterministic randomness** - Uses block hash + lottery data for fair selection
3. **Immutable ticket records** - All purchases permanently recorded
4. **Manual prize claims** - Winners must actively claim to prevent auto-drain attacks
5. **Emergency stop** - Owner can halt in case of issues

## Usage Example

```clarity
;; Start lottery (owner only)
(contract-call? .lottery start-lottery)

;; Buy tickets
(contract-call? .lottery buy-ticket)

;; Check lottery status
(contract-call? .lottery get-lottery-info)

;; Draw winners (after 24 hours)
(contract-call? .lottery draw-lottery)

;; Claim prize
(contract-call? .lottery claim-prize u1)
```

## Read-Only Functions

- `get-lottery-info()` - Current lottery status
- `get-user-tickets(lottery-id, user)` - User's tickets for specific lottery
- `get-lottery-results(lottery-id)` - Results of completed lottery
- `get-prize-claim(lottery-id, user)` - Prize claim status
- `get-ticket-info(lottery-id, ticket-id)` - Individual ticket details

## Constants

- **Ticket Price**: 1 STX (1,000,000 micro-STX)
- **Draw Duration**: ~24 hours (144 blocks)
- **Max Tickets per User**: 100 per lottery
- **Prize Distribution**: 60/20/10/10% split
