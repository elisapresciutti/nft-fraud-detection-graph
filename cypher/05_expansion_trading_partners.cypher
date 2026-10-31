//IDENTIFYING THE TOP TRADING PARTNERS OF MY WALLETS

// 1) Trader 3: w_trader3
:param file        => 'Trader3_top_trading_partners.csv';   // file name in Neo4j /import
:param coreAlias   => 'Trader3';
:param coreAddress => 'w_trader3'; // lowercase
:param tag         => 'partner_of_Trader3';                  // simple provenance tag

LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH DISTINCT toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> ''
WITH collect(addr) AS addrs
UNWIND addrs AS a
OPTIONAL MATCH (w:Wallet {address:a})
WITH addrs, count(w) AS already
RETURN size(addrs) AS partners_in_csv,
       already     AS already_in_db,
       (size(addrs) - already) AS new_to_create;


MERGE (core:Wallet {address: toLower($coreAddress)})
  ON CREATE SET core.alias     = $coreAlias,
                core.created_at = datetime()


WITH core
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH core, toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> '' AND addr <> core.address


WITH DISTINCT core, addr

MERGE (w:Wallet {address: addr})
  ON CREATE SET w.created_at = datetime(),
                w.added_as  = 'partner';


// 2) trader 4: w_trader4
:param file        => 'Trader4_top_trading_partners.csv';   // file name in Neo4j /import
:param coreAlias   => 'Trader4';
:param coreAddress => 'w_trader4'; // lowercase
:param tag         => 'partner_of_Trader4';                  // simple provenance tag
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH DISTINCT toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> ''
WITH collect(addr) AS addrs
UNWIND addrs AS a
OPTIONAL MATCH (w:Wallet {address:a})
WITH addrs, count(w) AS already
RETURN size(addrs) AS partners_in_csv,
       already     AS already_in_db,
       (size(addrs) - already) AS new_to_create;


MERGE (core:Wallet {address: toLower($coreAddress)})
  ON CREATE SET core.alias     = $coreAlias,
                core.created_at = datetime()


WITH core
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH core, toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> '' AND addr <> core.address


WITH DISTINCT core, addr

MERGE (w:Wallet {address: addr})
  ON CREATE SET w.created_at = datetime(),
                w.added_as  = 'partner';

// 3) trader 5: w_trader5
:param file        => 'Trader5_top_trading_partners.csv';   // file name in Neo4j /import
:param coreAlias   => 'Trader5';
:param coreAddress => 'w_trader5'; // lowercase
:param tag         => 'partner_of_Trader5';                  // simple provenance tag
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH DISTINCT toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> ''
WITH collect(addr) AS addrs
UNWIND addrs AS a
OPTIONAL MATCH (w:Wallet {address:a})
WITH addrs, count(w) AS already
RETURN size(addrs) AS partners_in_csv,
       already     AS already_in_db,
       (size(addrs) - already) AS new_to_create;


MERGE (core:Wallet {address: toLower($coreAddress)})
  ON CREATE SET core.alias     = $coreAlias,
                core.created_at = datetime()


WITH core
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH core, toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> '' AND addr <> core.address


WITH DISTINCT core, addr

MERGE (w:Wallet {address: addr})
  ON CREATE SET w.created_at = datetime(),
                w.added_as  = 'partner';

// 4) trader 2: w_trader2
:param file        => 'Trader2_top_trading_partners.csv';   // file name in Neo4j /import
:param coreAlias   => 'Trader2';
:param coreAddress => 'w_trader2'; // lowercase
:param tag         => 'partner_of_Trader2';                  // simple provenance tag

LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH DISTINCT toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> ''
WITH collect(addr) AS addrs
UNWIND addrs AS a
OPTIONAL MATCH (w:Wallet {address:a})
WITH addrs, count(w) AS already
RETURN size(addrs) AS partners_in_csv,
       already     AS already_in_db,
       (size(addrs) - already) AS new_to_create;


MERGE (core:Wallet {address: toLower($coreAddress)})
  ON CREATE SET core.alias     = $coreAlias,
                core.created_at = datetime()


WITH core
LOAD CSV WITH HEADERS FROM 'file:///' + $file AS row
WITH core, toLower(trim(row.counterparty)) AS addr
WHERE addr IS NOT NULL AND addr <> '' AND addr <> core.address


WITH DISTINCT core, addr

MERGE (w:Wallet {address: addr})
  ON CREATE SET w.created_at = datetime(),
                w.added_as  = 'partner';


// MOVING ON WITH THE EXPANSION

// Lower-case address key used below to match wallets
MATCH (w:Wallet)
SET w.addr_lc = toLower(w.address)
RETURN count(w) AS wallets_with_addr_lc;

//1)TRADER 3:
// w_trader4 : 5
// w_p01 : 2
// w_p02 : 2
// w_p03 : 1 
// w_p04 : 1

:param rows: [
  {"tx_hash":"tx_001","From":"w_trader3","To":"w_trader4","token_id":"379","token_name":"SeedCollection","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_001","From":"w_trader3","To":"w_trader4","token_id":"380","token_name":"SeedCollection","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_001","From":"w_trader3","To":"w_trader4","token_id":"381","token_name":"SeedCollection","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_001","From":"w_trader3","To":"w_trader4","token_id":"382","token_name":"SeedCollection","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_002","From":"w_trader3","To":"w_trader4","token_id":"4938","token_name":"SeedCollection","timestamp":"2025-01-02T14:26:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_003","From":"w_p01","To":"w_trader3","token_id":"650","token_name":"Collection_01","timestamp":"2024-12-31T16:35:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_004","From":"w_trader3","To":"w_p01","token_id":"1223","token_name":"Collection_01","timestamp":"2025-01-01T22:47:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_005","From":"w_p02","To":"w_trader3","token_id":"6139","token_name":"SeedCollection","timestamp":"2024-12-31T16:34:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_006","From":"w_trader3","To":"w_p02","token_id":"649","token_name":"Collection_01","timestamp":"2025-01-04T16:56:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_007","From":"w_p03","To":"w_trader3","token_id":"1508","token_name":"SeedCollection","timestamp":"2025-01-06T15:07:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_008","From":"w_p04","To":"w_trader3","token_id":"8576","token_name":"Collection_02","timestamp":"2025-01-13T17:52:47Z","platform":"opensea","type":"transfer"}
]


UNWIND $rows AS r
WITH r,
     toLower(trim(r.From)) AS from_lc,
     toLower(trim(r.To))   AS to_lc


MATCH (fromW:Wallet {addr_lc: from_lc})
MATCH (toW:Wallet   {addr_lc: to_lc})


WITH r, fromW, toW,
     CASE
       WHEN r.timestamp =~ '^\d+$'
         THEN datetime({epochSeconds: toInteger(r.timestamp)})
       ELSE datetime(replace(trim(r.timestamp),' ','T'))
     END AS ts


MERGE (tx:Transaction {tx_hash: r.tx_hash})
  ON CREATE SET tx.timestamp = ts,
                tx.platform  = coalesce(r.platform,'unknown'),
                tx.type      = coalesce(r.type,'transfer'),
                tx.synthetic = true


MERGE (fromW)-[:INVOLVED_IN {role:'sender'}]->(tx)
MERGE (toW)  -[:INVOLVED_IN {role:'receiver'}]->(tx)


MERGE (fromW)-[tr:TRANSFERRED_TO]->(toW)
  ON CREATE SET tr.tx_hash   = r.tx_hash,
                tr.token_id  = toString(r.token_id),
                tr.timestamp = tx.timestamp,
                tr.synthetic = true


WITH r, tx
WHERE r.token_id IS NOT NULL
MERGE (nft:NFT {uid: 'synthetic:' + toString(r.token_id)})
  ON CREATE SET nft.token_id = toString(r.token_id),
                nft.name     = coalesce(r.token_name,'Synthetic NFT'),
                nft.synthetic = true
MERGE (tx)-[:EXCHANGED]->(nft);


// 2) TRADER 4
:param rows: [
  {"tx_hash":"tx_009","From":"w_trader3","To":"w_trader4","token_id":"2111","token_name":"Collection_03","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_009","From":"w_trader3","To":"w_trader4","token_id":"1734","token_name":"SeedCollection","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_009","From":"w_trader3","To":"w_trader4","token_id":"2548","token_name":"Collection_03","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_009","From":"w_trader3","To":"w_trader4","token_id":"3937","token_name":"Collection_03","timestamp":"2025-01-02T03:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_010","From":"w_p05","To":"w_trader4","token_id":"6103","token_name":"Collection_04","timestamp":"2024-12-30T15:42:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_010","From":"w_p05","To":"w_trader4","token_id":"7147","token_name":"Collection_04","timestamp":"2024-12-30T15:42:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_010","From":"w_p05","To":"w_trader4","token_id":"3506","token_name":"Collection_05","timestamp":"2024-12-30T15:42:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_011","From":"w_trader4","To":"w_p02","token_id":"2663","token_name":"SeedCollection","timestamp":"2025-01-04T12:18:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_011","From":"w_trader4","To":"w_p02","token_id":"1548","token_name":"SeedCollection","timestamp":"2025-01-04T12:18:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_012","From":"w_p06","To":"w_trader4","token_id":"3993","token_name":"SeedCollection","timestamp":"2025-01-08T09:33:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_012","From":"w_p06","To":"w_trader4","token_id":"644","token_name":"SeedCollection","timestamp":"2025-01-08T09:33:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_013","From":"w_p03","To":"w_trader4","token_id":"1639","token_name":"SeedCollection","timestamp":"2025-01-12T18:15:23Z","platform":"opensea","type":"transfer"}
]

UNWIND $rows AS r
WITH r,
     toLower(trim(r.From)) AS from_lc,
     toLower(trim(r.To))   AS to_lc


MATCH (fromW:Wallet {addr_lc: from_lc})
MATCH (toW:Wallet   {addr_lc: to_lc})


WITH r, fromW, toW,
     CASE

       WHEN r.timestamp =~ '^\d+$'
         THEN datetime({epochSeconds: toInteger(r.timestamp)})
       ELSE datetime(replace(trim(r.timestamp),' ','T'))
     END AS ts


MERGE (tx:Transaction {tx_hash: r.tx_hash})
  ON CREATE SET tx.timestamp = ts,
                tx.platform  = coalesce(r.platform,'unknown'),
                tx.type      = coalesce(r.type,'transfer'),
                tx.synthetic = true


MERGE (fromW)-[:INVOLVED_IN {role:'sender'}]->(tx)
MERGE (toW)  -[:INVOLVED_IN {role:'receiver'}]->(tx)


MERGE (fromW)-[tr:TRANSFERRED_TO]->(toW)
  ON CREATE SET tr.tx_hash   = r.tx_hash,
                tr.token_id  = toString(r.token_id),
                tr.timestamp = tx.timestamp,
                tr.synthetic = true


WITH r, tx
WHERE r.token_id IS NOT NULL
MERGE (nft:NFT {uid: 'synthetic:' + toString(r.token_id)})
  ON CREATE SET nft.token_id = toString(r.token_id),
                nft.name     = coalesce(r.token_name,'Synthetic NFT'),
                nft.synthetic = true
MERGE (tx)-[:EXCHANGED]->(nft);

// 3) TRADER 5
// w_p01 : 19
// w_p07 : 2
// w_p08 : 2
// w_p09 :1
// w_p10 : 1

:param rows: [
  {"tx_hash":"tx_014","From":"w_p01","To":"w_trader5","token_id":"226","token_name":"Collection_06","timestamp":"2025-01-07T23:07:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_015","From":"w_trader5","To":"w_p01","token_id":"226","token_name":"Collection_06","timestamp":"2025-01-07T23:08:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_016","From":"w_p01","To":"w_trader5","token_id":"432","token_name":"Collection_06","timestamp":"2025-01-07T23:09:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_017","From":"w_trader5","To":"w_p01","token_id":"432","token_name":"Collection_06","timestamp":"2025-01-07T23:09:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_018","From":"w_p01","To":"w_trader5","token_id":"8539","token_name":"Collection_06","timestamp":"2025-01-07T23:11:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_019","From":"w_p01","To":"w_trader5","token_id":"7879","token_name":"Collection_06","timestamp":"2025-01-07T23:11:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_020","From":"w_trader5","To":"w_p01","token_id":"7879","token_name":"Collection_06","timestamp":"2025-01-07T23:12:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_021","From":"w_trader5","To":"w_p01","token_id":"8539","token_name":"Collection_06","timestamp":"2025-01-07T23:12:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_022","From":"w_trader5","To":"w_p01","token_id":"1711","token_name":"Collection_07","timestamp":"2025-01-08T17:11:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_023","From":"w_p01","To":"w_trader5","token_id":"3804","token_name":"Collection_07","timestamp":"2025-01-08T17:16:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_024","From":"w_p01","To":"w_trader5","token_id":"5006","token_name":"Collection_07","timestamp":"2025-01-08T17:16:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_025","From":"w_trader5","To":"w_p01","token_id":"1711","token_name":"Collection_07","timestamp":"2025-01-08T17:16:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_026","From":"w_trader5","To":"w_p01","token_id":"3804","token_name":"Collection_07","timestamp":"2025-01-08T17:17:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_027","From":"w_p01","To":"w_trader5","token_id":"802","token_name":"Collection_07","timestamp":"2025-01-08T17:17:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_028","From":"w_p01","To":"w_trader5","token_id":"8824","token_name":"Collection_07","timestamp":"2025-01-08T17:17:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_029","From":"w_trader5","To":"w_p01","token_id":"802","token_name":"Collection_07","timestamp":"2025-01-08T17:19:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_030","From":"w_trader5","To":"w_p01","token_id":"8824","token_name":"Collection_07","timestamp":"2025-01-08T17:19:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_031","From":"w_trader5","To":"w_p01","token_id":"5006","token_name":"Collection_07","timestamp":"2025-01-08T17:20:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_032","From":"w_trader5","To":"w_p01","token_id":"11700","token_name":"Collection_08","timestamp":"2025-01-08T17:21:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_033","From":"w_trader5","To":"w_p07","token_id":"1000001","token_name":"Collection_09","timestamp":"2025-08-13T07:26:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_034","From":"w_trader5","To":"w_p07","token_id":"1031","token_name":"Collection_10","timestamp":"2025-08-13T09:59:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_035","From":"w_trader5","To":"w_p08","token_id":"5958","token_name":"Collection_11","timestamp":"2025-05-22T09:11:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_036","From":"w_trader5","To":"w_p08","token_id":"4438","token_name":"Collection_11","timestamp":"2025-05-22T09:12:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_037","From":"w_trader5","To":"w_p09","token_id":"11524","token_name":"Collection_08","timestamp":"2025-01-23T02:31:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_038","From":"w_trader5","To":"w_p10","token_id":"3561","token_name":"Collection_12","timestamp":"2025-08-12T20:32:11Z","platform":"opensea","type":"transfer"}
]


UNWIND $rows AS r
WITH r,
     toLower(trim(r.From)) AS from_lc,
     toLower(trim(r.To))   AS to_lc


MATCH (fromW:Wallet {addr_lc: from_lc})
MATCH (toW:Wallet   {addr_lc: to_lc})


WITH r, fromW, toW,
     CASE

       WHEN r.timestamp =~ '^\d+$'
         THEN datetime({epochSeconds: toInteger(r.timestamp)})
       ELSE datetime(replace(trim(r.timestamp),' ','T'))
     END AS ts


MERGE (tx:Transaction {tx_hash: r.tx_hash})
  ON CREATE SET tx.timestamp = ts,
                tx.platform  = coalesce(r.platform,'unknown'),
                tx.type      = coalesce(r.type,'transfer'),
                tx.synthetic = true


MERGE (fromW)-[:INVOLVED_IN {role:'sender'}]->(tx)
MERGE (toW)  -[:INVOLVED_IN {role:'receiver'}]->(tx)


MERGE (fromW)-[tr:TRANSFERRED_TO]->(toW)
  ON CREATE SET tr.tx_hash   = r.tx_hash,
                tr.token_id  = toString(r.token_id),
                tr.timestamp = tx.timestamp,
                tr.synthetic = true


WITH r, tx
WHERE r.token_id IS NOT NULL
MERGE (nft:NFT {uid: 'synthetic:' + toString(r.token_id)})
  ON CREATE SET nft.token_id = toString(r.token_id),
                nft.name     = coalesce(r.token_name,'Synthetic NFT'),
                nft.synthetic = true
MERGE (tx)-[:EXCHANGED]->(nft);


//4) TRADER 2:

// w_p11: 4
// w_initialowner: 3
// w_p12: 1
// w_p13: 1
// w_p14: 1


:param rows: [
  {"tx_hash":"tx_039","From":"w_p11","To":"w_trader2","token_id":"132","token_name":"Collection_13","timestamp":"2025-04-24T20:30:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_040","From":"w_p11","To":"w_trader2","token_id":"4059","token_name":"Collection_14","timestamp":"2025-04-24T20:31:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_041","From":"w_p11","To":"w_trader2","token_id":"1274","token_name":"Collection_15","timestamp":"2025-04-24T20:36:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_041","From":"w_p11","To":"w_trader2","token_id":"1273","token_name":"Collection_15","timestamp":"2025-04-24T20:36:35Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_042","From":"w_initialowner","To":"w_trader2","token_id":"3600","token_name":"SeedCollection","timestamp":"2025-03-29T01:19:11Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_043","From":"w_initialowner","To":"w_trader2","token_id":"3600","token_name":"SeedCollection","timestamp":"2025-03-29T01:19:23Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_044","From":"w_initialowner","To":"w_trader2","token_id":"4744","token_name":"Collection_16","timestamp":"2025-03-29T01:19:59Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_045","From":"w_trader2","To":"w_p12","token_id":"1068","token_name":"Collection_17","timestamp":"2025-04-24T20:45:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_045","From":"w_trader2","To":"w_p13","token_id":"1274","token_name":"Collection_15","timestamp":"2025-04-24T20:45:47Z","platform":"opensea","type":"transfer"},
  {"tx_hash":"tx_045","From":"w_trader2","To":"w_p14","token_id":"1273","token_name":"Collection_15","timestamp":"2025-04-24T20:45:47Z","platform":"opensea","type":"transfer"}
]


UNWIND $rows AS r
WITH r,
     toLower(trim(r.From)) AS from_lc,
     toLower(trim(r.To))   AS to_lc


MATCH (fromW:Wallet {addr_lc: from_lc})
MATCH (toW:Wallet   {addr_lc: to_lc})


WITH r, fromW, toW,
     CASE

       WHEN r.timestamp =~ '^\d+$'
         THEN datetime({epochSeconds: toInteger(r.timestamp)})
       ELSE datetime(replace(trim(r.timestamp),' ','T'))
     END AS ts


MERGE (tx:Transaction {tx_hash: r.tx_hash})
  ON CREATE SET tx.timestamp = ts,
                tx.platform  = coalesce(r.platform,'unknown'),
                tx.type      = coalesce(r.type,'transfer'),
                tx.synthetic = true


MERGE (fromW)-[:INVOLVED_IN {role:'sender'}]->(tx)
MERGE (toW)  -[:INVOLVED_IN {role:'receiver'}]->(tx)


MERGE (fromW)-[tr:TRANSFERRED_TO]->(toW)
  ON CREATE SET tr.tx_hash   = r.tx_hash,
                tr.token_id  = toString(r.token_id),
                tr.timestamp = tx.timestamp,
                tr.synthetic = true


WITH r, tx
WHERE r.token_id IS NOT NULL
MERGE (nft:NFT {uid: 'synthetic:' + toString(r.token_id)})
  ON CREATE SET nft.token_id = toString(r.token_id),
                nft.name     = coalesce(r.token_name,'Synthetic NFT'),
                nft.synthetic = true
MERGE (tx)-[:EXCHANGED]->(nft);
