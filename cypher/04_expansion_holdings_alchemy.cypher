// API IMPLEMENTATION


CREATE CONSTRAINT wallet_addr IF NOT EXISTS
FOR (w:Wallet) REQUIRE w.address IS UNIQUE;

CREATE CONSTRAINT nft_uid IF NOT EXISTS
FOR (n:NFT) REQUIRE n.uid IS UNIQUE;


CREATE CONSTRAINT tx_hash_unique IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.tx_hash IS UNIQUE;

:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param contract   => 'c_seed_collection';
:param token_id   => '3600';

// To ensure global uniqueness across multi-contract NFT analysis, implement a compound UID property formatted as "contract:token_id" (e.g., "c_seed_collection:3600"). 
// This prevents data conflicts when analyzing NFTs from different collections that may share identical token IDs, enabling scalable cross-collection fraud detection 
// while maintaining referential integrity in the graph database. The UID serves as the primary key for NFT identification throughout the analysis framework

// --- UID for the seed NFT
MATCH (n:NFT {token_id: 3600})
SET n.uid = toLower(n.contract) + ':' + toString(n.token_id)
RETURN n.uid AS uid_created, n.name AS nft_name;

CREATE CONSTRAINT nft_uid IF NOT EXISTS
FOR (n:NFT) REQUIRE n.uid IS UNIQUE;


// ADDRESS NORMALIZATION:
// Address Normalization 
MATCH (w:Wallet)
WHERE w.address <> toLower(w.address)  
SET w.address = toLower(w.address)
RETURN count(w) AS addresses_normalized;

//1) CURRENT OWNER - w_currentowner
:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_currentowner';
:param pageKey    => null;   


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url
CALL apoc.load.json(url) YIELD value
RETURN size(coalesce(value.ownedNfts, [])) AS n_in_this_page,
       value.pageKey AS nextPageKey,
       [x IN coalesce(value.ownedNfts, [])[0..5] |
         coalesce(x.name, x.title, x.rawMetadata.name, 'NFT')] AS sampleNames;

// --- DETAILED LIST

WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;

 // IMPORT REALE
WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;


//CONTINUING WITH OTHER WALLETS 
//2) w_initialowner --> INITIAL OWNER 
// --- SET YOUR PARAMS ---
:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_initialowner';
:param pageKey    => null; 


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url
CALL apoc.load.json(url) YIELD value
RETURN size(coalesce(value.ownedNfts, [])) AS n_in_this_page,
       value.pageKey AS nextPageKey,
       [x IN coalesce(value.ownedNfts, [])[0..5] |
         coalesce(x.name, x.title, x.rawMetadata.name, 'NFT')] AS sampleNames;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;


// 3)w_trader2-->Trader2


:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_trader2';
:param pageKey    => null; 

// --- PREVIEW (no writes)

WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url
CALL apoc.load.json(url) YIELD value
RETURN size(coalesce(value.ownedNfts, [])) AS n_in_this_page,
       value.pageKey AS nextPageKey,
       [x IN coalesce(value.ownedNfts, [])[0..5] |
         coalesce(x.name, x.title, x.rawMetadata.name, 'NFT')] AS sampleNames;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;

// 4) w_trader3 --> Trader 3

:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_trader3';
:param pageKey    => null; 


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url
CALL apoc.load.json(url) YIELD value
RETURN size(coalesce(value.ownedNfts, [])) AS n_in_this_page,
       value.pageKey AS nextPageKey,
       [x IN coalesce(value.ownedNfts, [])[0..5] |
         coalesce(x.name, x.title, x.rawMetadata.name, 'NFT')] AS sampleNames;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;

// Note about pagination:  
//if nextPageKey is returned: use that value to fetch the next 100 NFTs
//If nextPageKey is null in the response: Then the wallet has ≤100 NFTs total
//Trader3 ha più di 100 NFT, quindi dobbiamo continuare con la pagina successiva

//  Trader3 - Pagina 2 (NON RUNNATO PER EVITARE ESPLOSIONE DATASET)
:param owner => 'w_trader3';
:param pageKey => 'NEXT_PAGE_KEY_FROM_PREVIOUS_RESPONSE';

// 5) w_trader4 --> Trader4

:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_trader4';
:param pageKey    => null; 


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;


//6) w_trader5 --> Trader5


:param alchemyKey => 'YOUR_ALCHEMY_KEY';
:param owner      => 'w_trader5';
:param pageKey    => null; 


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n
WITH owner, nextPageKey,
     toLower(n.contract.address) AS contract_address,
     coalesce(n.tokenId, n.id.tokenId) AS token_id,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nft_name,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collection_name,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS token_type
RETURN 
    contract_address,
    token_id,
    nft_name,
    collection_name,
    token_type,
    contract_address + ':' + toString(token_id) AS uid_that_would_be_merged
ORDER BY collection_name, token_id;


WITH $alchemyKey AS key, toLower($owner) AS owner, $pageKey AS pk
WITH 'https://eth-mainnet.g.alchemy.com/nft/v3/' + key +
     '/getNFTsForOwner?owner=' + owner +
     '&withMetadata=true&pageSize=100' +
     CASE WHEN pk IS NULL THEN '' ELSE '&pageKey=' + pk END AS url,
     owner
CALL apoc.load.json(url) YIELD value
WITH owner, coalesce(value.ownedNfts, []) AS nfts, value.pageKey AS nextPageKey
UNWIND nfts AS n


WITH owner, nextPageKey,
     toLower(n.contract.address) AS c,
     coalesce(n.tokenId, n.id.tokenId) AS tidRaw,
     coalesce(n.name, n.title, n.rawMetadata.name, 'NFT') AS nftName,
     coalesce(n.image.cachedUrl, n.rawMetadata.image, n.media[0].gateway) AS img,
     coalesce(n.contract.openSea.collectionName, n.contract.name, 'Unknown') AS collName,
     coalesce(n.contract.tokenType, n.id.tokenMetadata.tokenType) AS ttype


WITH owner, nextPageKey, c, tidRaw, nftName, img, collName, ttype,
     c + ':' + toString(tidRaw) AS uid


WHERE NOT (c = toLower($contract) AND toString(tidRaw) = toString($token_id))

MERGE (w:Wallet {address: owner})
MERGE (nft:NFT {uid: uid})
  ON CREATE SET nft.contract = c,
                nft.token_id = toString(tidRaw),
                nft.name = nftName,
                nft.image_url = img,
                nft.tokenType = ttype,
                nft.createdAt = timestamp()
  ON MATCH SET nft.name = coalesce(nft.name, nftName),
               nft.image_url = coalesce(nft.image_url, img),
               nft.tokenType = coalesce(nft.tokenType, ttype)

MERGE (w)-[r:OWNS]->(nft)
  ON CREATE SET r.source = 'alchemy',
                r.fetchedAt = timestamp(),
                r.current = true
  ON MATCH SET r.current = true,
               r.fetchedAt = timestamp()

MERGE (col:Collection {name: collName})
MERGE (nft)-[:PART_OF]->(col)

WITH count(nft) AS imported_count, nextPageKey
RETURN imported_count AS nfts_imported, nextPageKey;


MATCH (w:Wallet)-[:OWNS]->(n:NFT)
WITH w, count(n) AS nft_count
ORDER BY nft_count DESC
LIMIT 10
RETURN w.address AS wallet_address, 
       w.alias AS wallet_name, 
       nft_count AS total_nfts_owned
ORDER BY nft_count DESC;
