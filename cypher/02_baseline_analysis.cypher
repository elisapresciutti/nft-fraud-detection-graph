//BASIC NETWORK STATISTICS ANALYSIS
//Count all nodes by type
MATCH (n) 
RETURN labels(n)[0] as NodeType, count(n) as Count
ORDER BY Count DESC;


//Count all relationships by type
MATCH ()-[r]->() 
RETURN type(r) as RelationshipType, count(r) as Count
ORDER BY Count DESC;


//Network Density 
MATCH (w:Wallet)
WITH count(w) AS node_count
MATCH ()-[r:TRANSFERRED_TO]->()
WITH node_count, count(r) AS edge_count
RETURN node_count,
       edge_count,
       node_count * (node_count - 1) AS max_possible_edges,
       1.0 * edge_count / (node_count * (node_count - 1)) AS density;


// Node degree distribution (how many connections each node has)
MATCH (n)
OPTIONAL MATCH (n)-[r]-()
RETURN labels(n)[0] as NodeType, 
       coalesce(n.alias, n.name, 'Unknown') as NodeName,
       count(r) as TotalConnections
ORDER BY TotalConnections DESC;


//DIADICITY on Wallet–TRANSFERRED_TO (UNDIRECTED) ---

// Total undirected edges 
CALL {
  MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
  WHERE id(a) < id(b)
  RETURN count(*) AS E
}

// Actual edges by unordered type pair (t1<=t2)
CALL {
  MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
  WHERE id(a) < id(b)
  WITH coalesce(a.type, 'UNKNOWN') AS ta, coalesce(b.type, 'UNKNOWN') AS tb
  WITH CASE WHEN ta <= tb THEN ta ELSE tb END AS t1,
       CASE WHEN ta <= tb THEN tb ELSE ta END AS t2
  RETURN t1, t2, count(*) AS actual_edges
} CALL {
  
  MATCH (w:Wallet)
  WHERE EXISTS { MATCH (w)-[:TRANSFERRED_TO]-(:Wallet) }
  WITH coalesce(w.type, 'UNKNOWN') AS t, count(*) AS n
  RETURN collect({type:t, n:n}) AS typeCounts, sum(n) AS N
}
WITH E, t1, t2, actual_edges, typeCounts, N,
     
     (N * (N - 1)) / 2.0 AS total_pairs,
     coalesce([x IN typeCounts WHERE x.type = t1][0].n, 0) AS n1,
     coalesce([x IN typeCounts WHERE x.type = t2][0].n, 0) AS n2
WITH E, t1, t2, actual_edges, total_pairs, n1, n2,
     
     CASE 
       WHEN total_pairs = 0 THEN 0.0
       WHEN t1 = t2 THEN ( (n1 * (n1 - 1)) / 2.0 ) / total_pairs
       ELSE ( (1.0 * n1 * n2) / total_pairs )
     END AS expected_prob
WITH E, t1, t2, actual_edges, expected_prob,
     CASE WHEN E > 0 THEN (1.0 * actual_edges) / E ELSE 0.0 END AS actual_prob
RETURN t1 AS TypeA,
       t2 AS TypeB,
       actual_edges AS ActualEdges,
       round(actual_prob, 4) AS ActualProb,
       round(expected_prob, 4) AS ExpectedProb,
       CASE 
         WHEN expected_prob = 0 THEN null
         ELSE round(actual_prob / expected_prob, 3)
       END AS DiadicityRatio
ORDER BY DiadicityRatio DESC, ActualEdges DESC;


// HOMOPHILY
MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
WHERE id(a) < id(b)                           
WITH coalesce(a.type,'UNKNOWN') AS ta,
     coalesce(b.type,'UNKNOWN') AS tb
WITH count(*) AS totalEdges,
     count(CASE WHEN ta = tb THEN 1 END) AS sameTypeEdges
RETURN sameTypeEdges,
       totalEdges,
       round(1.0 * sameTypeEdges / totalEdges, 3) AS homophily;


// Per-type homophily
MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
WITH coalesce(a.type,'UNKNOWN') AS ta,
     coalesce(b.type,'UNKNOWN') AS tb

WITH CASE WHEN ta <= tb THEN ta ELSE tb END AS t1,
     CASE WHEN ta <= tb THEN tb ELSE ta END AS t2
RETURN t1 AS TypeA,
       t2 AS TypeB,
       count(*) AS edgeCount
ORDER BY edgeCount DESC;


// undirected edge by type pair
CALL {
  MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
  WITH coalesce(a.type,'UNKNOWN') AS ta, coalesce(b.type,'UNKNOWN') AS tb
  WITH CASE WHEN ta <= tb THEN ta ELSE tb END AS t1,
       CASE WHEN ta <= tb THEN tb ELSE ta END AS t2
  RETURN t1, t2, count(*) AS e
}


WITH collect({t1:t1, t2:t2, e:e}) AS edges
UNWIND edges AS row
WITH row,
     [r IN edges WHERE r.t1 = row.t1 OR r.t2 = row.t1]  AS touching,
     [r IN edges WHERE r.t1 = row.t1 AND r.t2 = row.t1] AS sameType
WITH
  row.t1 AS Type,
  reduce(s=0, r IN touching | s + r.e)  AS EdgesTouchingType,
  reduce(s=0, r IN sameType | s + r.e) AS SameTypeEdges
RETURN
  Type,
  EdgesTouchingType,
  SameTypeEdges,
  CASE WHEN EdgesTouchingType = 0 THEN 0
       ELSE round(1.0 * SameTypeEdges / EdgesTouchingType, 3)
  END AS HomophilyForType
ORDER BY HomophilyForType DESC, EdgesTouchingType DESC;


//CLUSTERING COEFFICIENT

MATCH (w:Wallet)
OPTIONAL MATCH (w)-[:TRANSFERRED_TO]-(nbr:Wallet)
WITH w, collect(DISTINCT nbr) AS neighbors
WITH w, neighbors, size(neighbors) AS k
WHERE k >= 2                                   
UNWIND neighbors AS n1
UNWIND neighbors AS n2
WITH w, k, n1, n2
WHERE id(n1) < id(n2)                          
OPTIONAL MATCH (n1)-[:TRANSFERRED_TO]-(n2)
WITH w, k, count(*) AS closedPairs            
RETURN
  w.alias AS wallet,
  k AS degree,
  round( (1.0 * closedPairs) / (k * (k - 1) / 2), 3 ) AS clustering_coefficient
ORDER BY clustering_coefficient DESC;


//CONNECTIVITY VALIDATION (100% graph connectivity, no isolated nodes, no orphaned transactions)

MATCH (w:Wallet)
WHERE NOT (w)-[:TRANSFERRED_TO]-(:Wallet)
RETURN count(w) AS isolated_wallets;


MATCH (t:Transaction)
WHERE NOT (t)<-[:INVOLVED_IN]-(:Wallet)
RETURN count(t) AS orphaned_transactions;


MATCH (w:Wallet)
WITH collect(w) AS wallets
MATCH (w1:Wallet)-[:TRANSFERRED_TO*1..]-(w2:Wallet)
WHERE w1 IN wallets AND w2 IN wallets
WITH collect(DISTINCT w1) AS reachable, wallets
RETURN size(reachable) = size(wallets) AS allWalletsConnected;


//OWNERSHIP HISTORY AND TIMING PATTERNS

//Complete ownership timeline
MATCH (t:Transaction {token_id: 3600})
MATCH (from_wallet:Wallet {address: t.from_wallet})
MATCH (to_wallet:Wallet {address: t.to_wallet})
RETURN t.timestamp as TransactionTime,
       t.type as TransactionType,
       from_wallet.alias as FromWallet,
       to_wallet.alias as ToWallet,
       t.platform as Platform
ORDER BY t.timestamp;


MATCH (t:Transaction)
WHERE t.token_id = 3600
RETURN t.timestamp AS original_timestamp,
       replace(t.timestamp, ' ', 'T') AS modified_timestamp
LIMIT 1;


MATCH (t:Transaction)
WHERE t.token_id = 3600
WITH t ORDER BY t.timestamp
WITH collect(t) AS transactions

UNWIND range(0, size(transactions)-1) AS i
WITH transactions, i,
     transactions[i] AS current_tx,
     CASE WHEN i < size(transactions)-1 THEN transactions[i+1] ELSE null END AS next_tx

MATCH (to_wallet:Wallet {address: trim(current_tx.to_wallet)})

RETURN to_wallet.alias AS Owner,
       replace(current_tx.timestamp, ' ', 'T') AS AcquiredAt,
       CASE WHEN next_tx IS NOT NULL 
            THEN replace(next_tx.timestamp, ' ', 'T')
            ELSE 'Still Holding' END AS HeldUntil,
       current_tx.type AS AcquisitionType
ORDER BY current_tx.timestamp;


MATCH (t:Transaction)
WHERE t.token_id = 3600
WITH t ORDER BY t.timestamp
WITH collect(t) AS transactions

UNWIND range(0, size(transactions)-2) AS i
WITH transactions[i] AS acquisition, transactions[i+1] AS disposal

MATCH (holder:Wallet {address: trim(acquisition.to_wallet)})

WITH holder, acquisition, disposal,
     disposal.timestamp AS disposal_time,
     acquisition.timestamp AS acquisition_time

RETURN holder.alias AS Holder,
       holder.type AS HolderType,
       replace(acquisition.timestamp, ' ', 'T') AS AcquiredAt,
       replace(disposal.timestamp, ' ', 'T') AS DisposedAt,
       acquisition.type AS AcquisitionType,
       disposal.type AS DisposalType,
       disposal.platform AS DisposalPlatform,
       CASE 
         WHEN disposal.timestamp < '2023-05-01' AND acquisition.timestamp >= '2023-04-01' THEN 'Quick Flip'
         WHEN disposal.timestamp < '2024-01-01' AND acquisition.timestamp >= '2023-01-01' THEN 'Short Hold'
         WHEN disposal.timestamp < '2025-01-01' AND acquisition.timestamp >= '2024-01-01' THEN 'Medium Hold'
         ELSE 'Long Hold'
       END AS HoldingPattern
ORDER BY acquisition.timestamp;


//SOCIAL PROFILE CONNECTIONS ANALYSIS


MATCH (w:Wallet)-[:HAS_PROFILE]->(s:SocialProfile)
RETURN w.alias as Wallet,
       w.type as WalletType,
       collect(s.platform) as Platforms,
       count(s) as ProfileCount
ORDER BY ProfileCount DESC;


MATCH (w:Wallet)-[:HAS_PROFILE]->(s:SocialProfile)
RETURN s.platform as Platform,
       count(DISTINCT w) as WalletCount,
       collect(w.alias) as Wallets
ORDER BY WalletCount DESC;


//APPLY GRAPH ALGORITHMS
// --- Creating both projections directed and undirected
CALL gds.graph.project(
  'walletUndirected',
  'Wallet',
  {TRANSFERRED_TO: {orientation: 'UNDIRECTED'}}
);

CALL gds.graph.project(
  'walletDirected', 
  'Wallet',
  {TRANSFERRED_TO: {orientation: 'NATURAL'}}  // Keeps original direction
);


//1) CENTRALITY ANALYSIS: - Betweenness Centrality - Degree Centrality - Closeness Centrality - PageRank

//--- Betweenness Centrality
CALL gds.betweenness.stream('walletUndirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).alias AS wallet, score
ORDER BY score DESC;


// --- Degree centrality (undirected)
CALL gds.degree.stream('walletUndirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).alias  AS walletAlias,
       gds.util.asNode(nodeId).address AS wallet,
       score AS degree
ORDER BY degree DESC, wallet ASC;


//Closeness (undirected)
CALL gds.closeness.stream('walletUndirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).alias  AS walletAlias,
       gds.util.asNode(nodeId).address AS wallet,
       round(score, 4) AS closeness
ORDER BY closeness DESC, wallet ASC;


//--- PageRank (directed)
CALL gds.pageRank.stream('walletDirected', { dampingFactor: 0.85, maxIterations: 40 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).alias  AS walletAlias,
       gds.util.asNode(nodeId).address AS wallet,
       round(score, 6) AS pagerank
ORDER BY pagerank DESC, wallet ASC;


//2) COMMUNITY DETECTION

 //community detection is more of a sanity check:
	//•	If it finds just small groups (like 1–2 wallets per community), it confirms the market is clean and linear.
	//•	If in a bigger dataset it found a tight dense community , then it would be suspicious 


//Louvain (node-level memberships)
CALL gds.louvain.stream('walletUndirected')
YIELD nodeId, communityId
RETURN gds.util.asNode(nodeId).alias  AS wallet,
       gds.util.asNode(nodeId).type   AS wallet_type,
       communityId
ORDER BY communityId, wallet;


//Community sizes
CALL gds.louvain.stream('walletUndirected')
YIELD communityId, nodeId
RETURN communityId, count(*) AS members,
       collect(gds.util.asNode(nodeId).alias) AS wallets
ORDER BY members DESC;


// Get modularity score
CALL gds.louvain.stats('walletUndirected')
YIELD communityCount, modularity
RETURN communityCount AS communities,
       round(modularity, 3) AS modularity_score;


//Cycle detection: look for 3–5 wallet loops
MATCH path = (w:Wallet)-[:TRANSFERRED_TO*3..5]->(w)
WITH [n IN nodes(path) WHERE n:Wallet | n.alias] AS walletCycle,
     length(path) AS cycleLength
RETURN walletCycle AS cycle_nodes,
       cycleLength
LIMIT 20;


//3) SIMILARITY MEASURE
//1- Jaccard similarity
CALL gds.nodeSimilarity.stream(
  'walletUndirected',
  { topK: 20, degreeCutoff: 1 }   
)
YIELD node1, node2, similarity
RETURN gds.util.asNode(node1).alias AS Wallet1,
       gds.util.asNode(node2).alias AS Wallet2,
       round(similarity,3)          AS JaccardSimilarity
ORDER BY JaccardSimilarity DESC, Wallet1, Wallet2
LIMIT 50;

// 2- Cosine similarity


CALL gds.nodeSimilarity.stream(
  'walletUndirected',
  { topK: 20, degreeCutoff: 1, similarityMetric: 'COSINE' }
)
YIELD node1, node2, similarity
RETURN gds.util.asNode(node1).alias AS Wallet1,
       gds.util.asNode(node2).alias AS Wallet2,
       round(similarity,3)          AS CosineSimilarity
ORDER BY CosineSimilarity DESC, Wallet1, Wallet2
LIMIT 50;


// 4) HOMOPHILY
//--- Build wallet behavior profiles
MATCH (w:Wallet)-[t:TRANSFERRED_TO]->()
WITH w,
     count(t) AS txCount,
     coalesce(sum(t.value), 0) AS totalValue
RETURN w.address AS wallet,
       w.alias AS wallet_alias,
       txCount,
       totalValue
ORDER BY txCount DESC, totalValue DESC;


MATCH (w1:Wallet)-[:TRANSFERRED_TO]-(w2:Wallet)
WHERE id(w1) < id(w2)   

OPTIONAL MATCH (w1)-[t1:TRANSFERRED_TO]->() 
OPTIONAL MATCH (w2)-[t2:TRANSFERRED_TO]->()

WITH w1, w2,
     count(t1) AS txCount1,
     count(t2) AS txCount2,
     coalesce(sum(t1.value),0) AS totalVal1,
     coalesce(sum(t2.value),0) AS totalVal2

RETURN w1.alias AS Wallet1,
       w2.alias AS Wallet2,
       txCount1,
       txCount2,
       abs(txCount1 - txCount2) AS TxCountDiff,
       abs(totalVal1 - totalVal2) AS ValueDiff
ORDER BY TxCountDiff, ValueDiff
LIMIT 20;


//--- Homophily similarity score (0–1) 
MATCH (w1:Wallet)-[:TRANSFERRED_TO]-(w2:Wallet)
WHERE id(w1) < id(w2)

OPTIONAL MATCH (w1)-[t1:TRANSFERRED_TO]->()
OPTIONAL MATCH (w2)-[t2:TRANSFERRED_TO]->()

WITH w1, w2,
     count(t1) AS tx1,
     count(t2) AS tx2

WITH w1, w2, tx1, tx2,
     abs(tx1 - tx2) AS txDiff,
     (tx1 + tx2) AS totalTx

WITH w1, w2, tx1, tx2, txDiff, totalTx,
     CASE WHEN totalTx = 0 THEN 0
          ELSE 1.0 - (toFloat(txDiff) / totalTx)
     END AS similarityScore

RETURN w1.alias AS Wallet1,
       w2.alias AS Wallet2,
       tx1 AS Wallet1_TxCount,
       tx2 AS Wallet2_TxCount,
       round(similarityScore, 3) AS BehavioralHomophily
ORDER BY BehavioralHomophily DESC;

//5) NETWORK TOPOLOGY
//Average of local clustering across wallets
CALL gds.localClusteringCoefficient.stream('walletUndirected')
YIELD nodeId, localClusteringCoefficient
RETURN round(avg(localClusteringCoefficient), 3) AS global_clustering_coefficient;


//Average Path lenght 
CALL gds.allShortestPaths.stream('walletUndirected')
YIELD sourceNodeId, targetNodeId, distance
WHERE distance IS NOT NULL AND distance > 0
RETURN round(avg(distance), 3) AS average_path_length,
       min(distance)          AS shortest_path,
       max(distance)          AS longest_path,
       count(*)               AS pair_count;
