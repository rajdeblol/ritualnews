# Ritual Sovereign Agent — Crypto Sentiment Feed

An autonomous on-chain agent on **Ritual testnet (Chain ID 1979)** that fetches crypto news every hour, analyzes market sentiment via LLM inference, and writes structured snapshots to a `SentimentFeed` smart contract — self-rescheduling forever with zero external infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Scheduler (System Contract)           │
│    0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B   │
│            triggers runCycle() hourly            │
└──────────────────────┬──────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────┐
│              SentimentAgent.sol                  │
│                                                 │
│  STEP 1: Fetch news (HTTP precompile 0x0801)    │
│    → CryptoPanic, CryptoCompare, NewsAPI        │
│    → Skip failed sources, continue              │
│                                                 │
│  STEP 2: Analyze (LLM precompile 0x0802)        │
│    → Score (-100 to +100), signal, risk         │
│    → Retry once on parse failure                │
│                                                 │
│  STEP 3: Write on-chain                         │
│    → SentimentFeed.pushSnapshot(...)            │
│                                                 │
│  STEP 4: Self-reschedule                        │
│    → IScheduler.schedule() for next hour        │
│    → ALWAYS reschedules, even on failure        │
└──────────────────────┬──────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────┐
│             SentimentFeed.sol                    │
│    On-chain storage for hourly snapshots         │
│    score, signal, riskLevel, summary,            │
│    topTokens, headlines, sources, sentiments     │
└─────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Funded wallet on Ritual testnet (get tokens from [faucet](https://faucet.ritualfoundation.org))
- API keys for news sources:
  - [CryptoPanic](https://cryptopanic.com/developers/api/)
  - [CryptoCompare](https://min-api.cryptocompare.com/) (free tier)
  - [NewsAPI](https://newsapi.org/) (free tier)

### Setup

```bash
# Clone and enter project
cd "ritual news"

# Copy environment template and fill in your values
cp .env.example .env
# Edit .env with your PRIVATE_KEY and API keys

# Install dependencies
forge install

# Compile
forge build

# Run tests
forge test -vvv
```

### Deploy

```bash
# Load environment variables
source .env

# Deploy SentimentFeed + SentimentAgent
forge script script/Deploy.s.sol --rpc-url ritual --broadcast

# Note the deployed addresses and update .env:
# SENTIMENT_FEED_ADDRESS=0x...
# SENTIMENT_AGENT_ADDRESS=0x...

# Fund the agent with RITUAL tokens
forge script script/FundAgent.s.sol --rpc-url ritual --broadcast

# Start the autonomous loop
forge script script/StartAgent.s.sol --rpc-url ritual --broadcast
```

### Monitor

```bash
# Check latest sentiment snapshot
cast call $SENTIMENT_FEED_ADDRESS "getLatest()" --rpc-url https://rpc.ritualfoundation.org

# Check agent status
cast call $SENTIMENT_AGENT_ADDRESS "getStatus()" --rpc-url https://rpc.ritualfoundation.org

# Check total snapshots
cast call $SENTIMENT_FEED_ADDRESS "totalSnapshots()" --rpc-url https://rpc.ritualfoundation.org

# Get recent scores (last 24 hours)
cast call $SENTIMENT_FEED_ADDRESS "getRecentScores(uint256)(int8[],uint256[])" 24 --rpc-url https://rpc.ritualfoundation.org
```

## Project Structure

```
ritual-news/
├── app/                             # Next.js 14 App Router frontend
├── components/                      # Dashboard UI and providers
├── lib/                             # wagmi config, ABI, helpers
├── package.json                     # Frontend dependencies/scripts
├── tailwind.config.js               # Beige terminal design tokens
├── foundry.toml                    # Foundry configuration
├── .env.example                    # Environment variable template
├── .env.local.example              # Frontend env template
├── src/
│   ├── SentimentFeed.sol           # On-chain sentiment storage
│   ├── SentimentAgent.sol          # Sovereign agent (autonomous loop)
│   └── interfaces/
│       ├── IScheduler.sol          # Scheduler precompile interface
│       ├── ISentimentFeed.sol      # SentimentFeed interface
│       └── IRitualWallet.sol       # RitualWallet interface
├── script/
│   ├── Deploy.s.sol                # Deploy both contracts
│   ├── StartAgent.s.sol            # Start the agent loop
│   └── FundAgent.s.sol             # Fund the agent
├── test/
│   └── SentimentAgent.t.sol        # Tests with mocked precompiles
└── README.md
```

## Frontend

The repo now includes a read-only Next.js 14 dashboard that reads directly from Ritual Chain RPC with `wagmi` + `viem`.

### Frontend setup

```bash
cp .env.local.example .env.local
# set NEXT_PUBLIC_SENTIMENT_FEED_ADDRESS to your deployed SentimentFeed

npm install
npm run dev
```

### Frontend stack

- Next.js 14 App Router + TypeScript + Tailwind CSS
- `wagmi` + `viem` for on-chain reads only
- `react-chartjs-2` + Chart.js for the 24-point sentiment chart
- Polling every 30 seconds from `getLatest()` and `getRecentScores(24)`
- No backend, database, or wallet connection required

## Contracts

### SentimentFeed

| Function | Description |
|----------|-------------|
| `pushSnapshot(...)` | Write an hourly sentiment snapshot (agent only) |
| `getLatest()` | Get the most recent snapshot |
| `getSnapshot(uint256)` | Get snapshot by index |
| `getRecentScores(uint256)` | Get last N scores and timestamps |
| `totalSnapshots()` | Total number of snapshots stored |
| `setAgent(address)` | Change authorized agent (current agent only) |

### SentimentAgent

| Function | Description |
|----------|-------------|
| `runCycle()` | Main autonomous loop (called by Scheduler) |
| `startAgent()` | Kick off the first scheduled cycle |
| `stopAgent()` | Stop the agent from rescheduling |
| `getStatus()` | Get agent state (active, cycles, balance) |
| `set*Url(string)` | Update news source URLs |
| `setLlmModel(string)` | Change LLM model |
| `withdrawFunds(address, uint256)` | Withdraw stuck RITUAL |

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Single news source fails | Skip it, continue with remaining sources |
| All news sources fail | Skip this cycle, still reschedule |
| LLM returns invalid JSON | Retry once with stricter prompt |
| LLM fails twice | Skip this cycle, still reschedule |
| **Any failure** | **Always reschedule — agent never stops** |

## Ritual Precompiles Used

| Precompile | Address | Purpose |
|------------|---------|---------|
| HTTP | `0x0801` | Fetch news from 3 API sources |
| LLM | `0x0802` | Analyze sentiment with `zai-org/GLM-4.7-FP8` |
| Scheduler | `0x56e7...D58B` | Self-reschedule every 3600 seconds |

## Network

| Parameter | Value |
|-----------|-------|
| Network | Ritual Testnet |
| Chain ID | `1979` |
| RPC | `https://rpc.ritualfoundation.org` |
| Explorer | `https://explorer.ritualfoundation.org` |
| Faucet | `https://faucet.ritualfoundation.org` |
| Currency | RITUAL |

## License

MIT
