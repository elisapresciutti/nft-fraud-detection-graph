CREATE CONSTRAINT wallet_address IF NOT EXISTS
FOR (w:Wallet) REQUIRE w.address IS UNIQUE;

CREATE CONSTRAINT tx_hash IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.tx_hash IS UNIQUE;

CREATE CONSTRAINT nft_token IF NOT EXISTS
FOR (n:NFT) REQUIRE n.token_id IS UNIQUE;

CREATE CONSTRAINT collection_name IF NOT EXISTS
FOR (c:Collection) REQUIRE c.name IS UNIQUE;

CREATE INDEX social_wallet IF NOT EXISTS
FOR (s:SocialProfile) ON (s.wallet_address);

// STEP 2: CREATE ALL NODES 

// 1. COLLECTION NODES (1 row)
LOAD CSV WITH HEADERS FROM 'file:///collection.csv' AS row
CREATE (c:Collection {
    name: row.name,
    creator: row.creator,
    platform: row.platform
});

// 2. NFT NODES (1 row)
LOAD CSV WITH HEADERS FROM 'file:///nft.csv' AS row
CREATE (n:NFT {
    token_id: toInteger(row.token_id),
    name: row.name,
    uri: row.uri,
    image_url: row.image_url
});

// 3. WALLET NODES (7 rows) - IMPORTAZIONE WALLET DA wallet_pm.csv
LOAD CSV WITH HEADERS FROM 'file:///wallet_pm.csv' AS row
CREATE (w:Wallet {
    address: row.address,
    alias: row.alias,
    ens: row.ens,
    type: row.type,
    discovered_from: 'post_migration_csv',
    created_at: datetime()
})
RETURN count(w) AS wallets_imported;

// 4. TRANSACTION NODES (6 rows) - IMPORTAZIONE TRANSAZIONI DA transactions_post_migration.csv
LOAD CSV WITH HEADERS FROM 'file:///transactions_post_migration.csv' AS row
CREATE (t:Transaction {
    tx_hash: row.tx_hash,
    from_wallet: trim(row.from_wallet),  // rimuovi spazi
    to_wallet: trim(row.to_wallet),      // rimuovi spazi
    token_id: toInteger(row.token_id),
    timestamp: trim(row.timestamp),
    platform: trim(row.platform),
    type: row.type,
    contract: 'c_seed_collection',
    era: 'post_migration',
    created_at: datetime()
})
RETURN count(t) AS transactions_imported;

// 5. SOCIAL PROFILE NODES
LOAD CSV WITH HEADERS FROM 'file:///social_profiles.csv' AS row
CREATE (s:SocialProfile {
    wallet_address: row.wallet,  
    platform: row.platform,
    handle: row.handle,
    profile_url: row.url
});


// Check all created nodes
MATCH (n)
RETURN labels(n)[0] AS node_type, count(n) AS count
ORDER BY node_type;


// 1. OWNS - current ownership reconstruction
MATCH (t:Transaction)
WHERE t.token_id = 3600
WITH t ORDER BY t.timestamp DESC LIMIT 1
MATCH (current_owner:Wallet {address: trim(t.to_wallet)})
MATCH (nft:NFT {token_id: 3600})
CREATE (current_owner)-[:OWNS {
    acquired_at: t.timestamp,
    acquired_via: t.platform,
    tx_hash: t.tx_hash,
    era: 'post_migration'
}]->(nft)
RETURN current_owner.alias AS current_owner_alias,
       current_owner.address AS current_owner_address;

// 2. TRANSFERRED_TO - transaction counterparties, central for detecting structures
MATCH (t:Transaction)
MATCH (from_wallet:Wallet {address: trim(t.from_wallet)})
MATCH (to_wallet:Wallet {address: trim(t.to_wallet)})
CREATE (from_wallet)-[rel:TRANSFERRED_TO {
    tx_hash: t.tx_hash,
    token_id: t.token_id,
    timestamp: t.timestamp,
    platform: t.platform,
    type: t.type,
    contract: t.contract,
    era: t.era,
    nft_name: 'Seed NFT #3600'
}]->(to_wallet)
RETURN count(rel) AS transfer_relations_created;

// 3. PART_OF - collection membership
MATCH (nft:NFT)
MATCH (c:Collection)
CREATE (nft)-[:PART_OF]->(c)
RETURN count(*) AS part_of_relations_created;

// 4. EXCHANGED - associate transaction with the asset exchanged
MATCH (t:Transaction)
MATCH (nft:NFT {token_id: t.token_id})
CREATE (t)-[:EXCHANGED {
    token_id: t.token_id,
    transfer_type: t.type,
    platform: t.platform,
    timestamp: t.timestamp
}]->(nft)
RETURN count(*) AS exchanged_relations_created;

// 5. INVOLVED_IN - track wallet participation in transaction event (buyer/seller roles)
MATCH (t:Transaction)
MATCH (from_wallet:Wallet {address: trim(t.from_wallet)})
MATCH (to_wallet:Wallet {address: trim(t.to_wallet)})
CREATE (from_wallet)-[:INVOLVED_IN {
    role: 'sender',
    tx_hash: t.tx_hash,
    timestamp: t.timestamp
}]->(t)
CREATE (to_wallet)-[:INVOLVED_IN {
    role: 'receiver', 
    tx_hash: t.tx_hash,
    timestamp: t.timestamp
}]->(t)
RETURN count(*) AS involved_in_relations_created;

// 6. HAS_PROFILE - link wallets to their social identities
MATCH (w:Wallet)
MATCH (sp:SocialProfile {wallet_address: w.address})
CREATE (w)-[:HAS_PROFILE {
    platform: sp.platform,
    verified: false,
    created_at: datetime()
}]->(sp)
RETURN count(*) AS has_profile_relations_created;
