# Multi-Scale Network Analysis for Fraud Detection in NFT Markets

Graph-based forensic framework, built in **Neo4j**, that detects manipulation patterns in NFT markets (wash trading, circular trading, bot activity, coordinated trading) by moving from a **single NFT** to the **network of wallets** around it.

> Bachelor's thesis – BSc Management and Computer Science, LUISS Guido Carli (2024/2025), course of Cybercrime and Fraud Detection

![Expanded wallet network](images/wallet_network.png)

## Key findings

- **A single NFT looks clean:** the seed NFT's ownership history is a linear chain with no cycles and every fraud module at ZERO or LOW risk
- **Risk appears only at network scale:** after expanding to the owners' trading partners, a few hub wallets concentrate brokerage, short trading loops and bot-like timing
- **Hub wallets:** Trader3 has the highest betweenness (107), closeness (0.40) and PageRank (1.61) and appears in **20 directed cycles** of length 3–5
- Results are **risk signals, not proof of fraud**: part of the expansion uses synthetic transactions and sale prices are not available on-chain

## Approach

| Scale | What is analysed | Main tools |
|---|---|---|
| **Micro** | Ownership history of one seed NFT | Density, degree, homophily, clustering, cycle detection |
| **Meso** | Wallets and their trading partners | Centrality, Louvain communities, Jaccard / cosine similarity |
| **Macro** | Collections held by the same wallets | Ownership overlap between collections |

1. **Baseline graph** – the seed NFT, its 6 transfers, 7 wallets and their public profiles (CSV import)
2. **Holdings expansion** – NFT portfolios of the 6 owners via the Alchemy NFT API (`getNFTsForOwner`, first page of up to 100 NFTs per wallet), with a `contract:tokenId` UID to avoid collisions across collections
3. **Trading-partner expansion** – top 5 counterparties of the 4 most active traders in a 90-day window, with transactions capped in proportion to activity and flagged as `synthetic`
4. **Graph algorithms** – Neo4j Graph Data Science on directed and undirected wallet projections
5. **Fraud modules** – rule-based scores (ZERO / LOW / MEDIUM / HIGH) for six patterns

## Results

### Network size

| | Baseline | Expanded |
|---|---|---|
| Wallets | 7 | 21 |
| Transactions | 6 | 50 |
| NFTs / collections | 1 / 1 | 385 / 93 |
| Directed density (wallet graph) | 14.3% | 6.2% |
| Reciprocal wallet pairs | – | 23% |

### Graph algorithms

| Metric | Baseline | Expanded |
|---|---|---|
| Top betweenness | Trader3 9 · Trader2 8 · Trader4 8 | Trader3 107 · Trader2 98 · Trader5 86.5 · Trader4 76.5 |
| Top PageRank | CurrentOwner 0.68 · Trader5 0.62 | Trader3 1.61 |
| Louvain modularity | 0.319 (3 small groups along the chain) | 0.513 (3 communities) |
| Cycles of length 3–5 | none | Trader3 in 20 · Trader4 in 12 · Trader5 in 8 |
| Average path length | 2.67 | – |

### Fraud detection modules

| Module | Rule | Baseline | Expanded |
|---|---|---|---|
| Wash trading | Same token back and forth between two wallets, high risk within 24 h | ZERO | **HIGH** (transfers less than 1 h apart) |
| Circular trading | Directed loops of 3–6 wallets (3–5 in the expanded network) | ZERO | **HIGH** for 5 wallets |
| Volume inflation | Many trades with few partners in a short window (1 h baseline, 6 h expanded) | LOW | LOW for Trader2, otherwise ZERO |
| Bot activity | Sub-minute gaps between a wallet's transactions | ZERO | **HIGH** for Trader2, MEDIUM for 3 wallets |
| Coordinated trading | Several wallets trading in the same 15-minute window | LOW | **HIGH** for 2 wallets (8 events each) |
| Pump and dump | Rise > 30% then drop > 25% with few wallets | tested only on simulated prices | ZERO |

## Data and anonymization

All data come from the public Ethereum blockchain (Alchemy API, Etherscan) and NFT marketplaces. Because the results flag specific wallets as risky, **everything that could identify a real person has been removed**:

- wallet addresses → stable aliases (`w_trader3`, `w_p01`, …), the same in every file
- transaction hashes → `tx_001`, `tx_002`, …
- collection names → `SeedCollection`, `Collection_01`, …; NFT metadata URLs removed
- social profiles (OpenSea, X/Twitter, ENS) → `redacted_01`, …; ENS names removed
- Alchemy API key → `YOUR_ALCHEMY_KEY`

The anonymized files reproduce the **wallet network exactly** (21 wallets, 26 directed links). The Alchemy holdings step cannot be re-run on anonymized addresses, so NFT and collection counts come from the original run.

## Repository structure

```
├── cypher/
│   ├── 01_import_baseline.cypher           # constraints, nodes and relationships from CSV
│   ├── 02_baseline_analysis.cypher         # network statistics and GDS algorithms (single NFT)
│   ├── 03_baseline_fraud_detection.cypher  # fraud modules on the baseline
│   ├── 04_expansion_holdings_alchemy.cypher# wallet portfolios via Alchemy API
│   ├── 05_expansion_trading_partners.cypher# top trading partners of the traders
│   ├── 06_expanded_analysis.cypher         # statistics and GDS algorithms (expanded network)
│   └── 07_expanded_fraud_detection.cypher  # fraud modules on the expanded network
├── data/                                   # anonymized CSV files for Neo4j /import
├── images/
└── README.md
```

## How to run

1. Create a database in **Neo4j Desktop** (5.x) with the **APOC** and **Graph Data Science** plugins
2. Copy the files in `data/` into the database's `import` folder
3. Run the scripts in `cypher/` in order, in Neo4j Browser
4. Step 04 needs your own Alchemy key and real wallet addresses, so it cannot run on the anonymized data. Steps 05–07 still run: wallet-level results are reproduced, while holdings-based figures (NFT counts, collection overlap) will differ

## Tech stack

Neo4j · Cypher · Graph Data Science (centrality, Louvain, node similarity) · APOC · Alchemy NFT API · Neo4j Bloom

## Limitations and ethics

- Part of the expansion relies on **synthetic transactions** (capped and flagged), which may not reflect real market behaviour
- The network is bounded to the wallets connected to one seed NFT, so results are relative, not market-wide
- On-chain transfers carry no sale price, so pump-and-dump detection could only be tested on simulated prices
- Clustering and similarity methods can erode pseudonymity and flag legitimate users: this is why the data are anonymized

---

*Elisa Presciutti · [LinkedIn](https://www.linkedin.com/in/elisapresciutti)*
