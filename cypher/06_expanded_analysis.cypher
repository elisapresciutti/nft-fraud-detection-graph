// BASIC NETWORK STATISTICS ANALYSIS ON FULL dataset


MATCH (n)
RETURN head(labels(n)) AS label, count(*) AS count
ORDER BY count DESC;


MATCH ()-[r]->()
RETURN type(r) AS rel_type, count(*) AS count
ORDER BY count DESC;


//Network Density 
// Directed density = M / (N*(N-1))
MATCH (w:Wallet)
WITH count(w) AS N
MATCH (a:Wallet)-[:TRANSFERRED_TO]->(b:Wallet)
WITH N, count(DISTINCT [id(a), id(b)]) AS M
RETURN N AS node_count, M AS unique_arcs,
       (N*(N-1)) AS max_possible_arcs,
       (1.0 * M) / (N*(N-1)) AS density_directed;


// Undirected density = E / (N*(N-1)/2), counting each unordered pair only once
MATCH (w:Wallet)
WITH count(w) AS N
MATCH (a:Wallet)-[:TRANSFERRED_TO]->(b:Wallet)
WITH N, collect(DISTINCT CASE WHEN id(a) < id(b) THEN [id(a),id(b)] ELSE [id(b),id(a)] END) AS undirected_pairs
RETURN N AS node_count,
       size(undirected_pairs) AS unique_pairs,
       (N*(N-1))/2.0 AS max_possible_pairs,
       (1.0 * size(undirected_pairs)) / ((N*(N-1))/2.0) AS density_undirected;


// Node degree distribution (how many connections each node has)

MATCH (w:Wallet)-[:TRANSFERRED_TO]-(:Wallet)
WITH w, count(*) AS degree
RETURN degree, count(*) AS num_wallets
ORDER BY degree DESC;


MATCH (w:Wallet)
OPTIONAL MATCH (w)<-[in:TRANSFERRED_TO]-()
OPTIONAL MATCH (w)-[out:TRANSFERRED_TO]->()
WITH w, count(in) AS in_deg, count(out) AS out_deg, (count(in)+count(out)) AS total_deg
RETURN total_deg, count(*) AS num_wallets
ORDER BY total_deg DESC;


// DIADICITY on Wallet–TRANSFERRED_TO (UNDIRECTED) 

MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)        
WITH a,b,
     exists( (a)-[:TRANSFERRED_TO]->(b) ) AS ab,
     exists( (b)-[:TRANSFERRED_TO]->(a) ) AS ba
WITH count(*) AS unique_pairs,
     count(CASE WHEN ab AND ba THEN 1 END) AS mutual_pairs
RETURN unique_pairs, mutual_pairs,
       1.0 * mutual_pairs / unique_pairs AS reciprocity_by_dyad;


MATCH (a:Wallet)-[:TRANSFERRED_TO]->(b:Wallet)
WITH coalesce(a.type,'UNKNOWN') AS ta, coalesce(b.type,'UNKNOWN') AS tb
RETURN count(*) AS edges,
       count(CASE WHEN ta = tb THEN 1 END) AS same_type_edges,
       1.0 * count(CASE WHEN ta = tb THEN 1 END) / count(*) AS same_type_share;


//--- HOMOPHILY


MATCH (a:Wallet)-[:TRANSFERRED_TO]-(b:Wallet)
WHERE id(a) < id(b)
WITH coalesce(a.type,'UNKNOWN') AS ta,
     coalesce(b.type,'UNKNOWN') AS tb
WITH count(*) AS totalEdges,
     count(CASE WHEN ta = tb THEN 1 END) AS sameTypeEdges
RETURN sameTypeEdges,
       totalEdges,
       round(1.0 * sameTypeEdges / totalEdges, 3) AS homophily;


//APPLY GRAPH ALGORITHMS ON FULL DATASET
// Graph projections (created first: used by clustering, WCC and all algorithms below)


CALL gds.graph.drop('nftUndirected', false);
CALL gds.graph.drop('nftDirected',  false);


CALL gds.graph.project(
  'nftUndirected',
  'Wallet',
  {
    TRANSFERRED_TO: {
      type: 'TRANSFERRED_TO',
      orientation: 'UNDIRECTED',
      aggregation: 'SINGLE'   // collapse multi-edges
    }
  }
);


CALL gds.graph.project(
  'nftDirected',
  'Wallet',
  {
    TRANSFERRED_TO: {
      type: 'TRANSFERRED_TO',
      orientation: 'NATURAL',
      aggregation: 'SINGLE'
    }
  }
);

//--- CLUSTERING COEFFICIENT

CALL gds.localClusteringCoefficient.stream('nftUndirected')
YIELD nodeId, localClusteringCoefficient AS cc
WITH gds.util.asNode(nodeId) AS w, cc
RETURN w.address AS wallet, coalesce(w.alias,'Unknown') AS alias, round(cc,3) AS clustering_coefficient
ORDER BY clustering_coefficient DESC
LIMIT 5;


// --- CONNECTIVITY VALIDATION (100% graph connectivity, no isolated nodes, no orphaned transactions)

MATCH (w:Wallet)
WHERE NOT (w)-[:TRANSFERRED_TO]-(:Wallet)
RETURN count(w) AS isolated_wallets, collect(w.address)[0..25] AS sample_isolated;


MATCH (t:Transaction)
WHERE NOT (t)<-[:INVOLVED_IN]-(:Wallet)
RETURN count(t) AS orphan_transactions, collect(t.tx_hash)[0..25] AS sample_orphans;


CALL gds.wcc.stream('nftUndirected')
YIELD componentId
RETURN count(DISTINCT componentId) = 1 AS all_wallets_connected;


//1) CENTRALITY ANALYSIS:  - Degree Centrality - Betweenness Centrality - Closeness Centrality - PageRank

//--- DEGREE CENTRALITY 
CALL gds.degree.stream('nftUndirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).address AS wallet,
       coalesce(gds.util.asNode(nodeId).alias, 'Unknown') AS alias,
       score AS degree
ORDER BY degree DESC
LIMIT 20;


//--- BETWEENNESS CENTRALITY 
CALL gds.betweenness.stream('nftUndirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).address AS wallet,
       coalesce(gds.util.asNode(nodeId).alias,'Unknown') AS alias,
       round(score, 4) AS betweenness
ORDER BY betweenness DESC
LIMIT 10;


//--- CLOSENESS CENTRALITY 
CALL gds.closeness.harmonic.stream('nftDirected')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).address AS wallet,
       coalesce(gds.util.asNode(nodeId).alias,'Unknown') AS alias,
       round(score, 6) AS closeness_harmonic
ORDER BY closeness_harmonic DESC
LIMIT 15;


//--- PAGERANK 
CALL gds.pageRank.stream('nftDirected', { dampingFactor: 0.85, maxIterations: 40 })
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).address AS wallet,
       coalesce(gds.util.asNode(nodeId).alias,'Unknown') AS alias,
       round(score, 6) AS pagerank
ORDER BY pagerank DESC
LIMIT 20;


//2) COMMUNITY DETECTION

// Louvain memberships (undirected)

CALL gds.louvain.stream('nftUndirected')
YIELD nodeId, communityId
WITH gds.util.asNode(nodeId) AS w, communityId
RETURN w.address           AS wallet,
       coalesce(w.alias, coalesce(w.wallet_name, 'Unknown')) AS alias,
       communityId
ORDER BY communityId, alias, wallet
LIMIT 20;


// --- 1.2 Community sizes 
CALL gds.louvain.stream('nftUndirected')
YIELD communityId, nodeId
WITH communityId, collect(gds.util.asNode(nodeId)) AS ws
RETURN communityId,
       size(ws)                                         AS members,
       [w IN ws | coalesce(w.alias, w.wallet_name, w.address)][0..25] AS sample_aliases
ORDER BY members DESC, communityId
LIMIT 20;


//--- 1.3 Modularity score 

CALL gds.louvain.stats('nftUndirected')
YIELD communityCount, modularity
RETURN communityCount AS communities,
       round(modularity, 3) AS modularity_score;


//3) CYCLE DETECTION

//--- Directed 3–5 cycles (each counted once)


MATCH p = (w:Wallet)-[:TRANSFERRED_TO*3..5]->(w)
WITH p, nodes(p) AS ns

WHERE id(head(ns)) = apoc.coll.min([n IN ns | id(n)])
WITH [n IN ns | coalesce(n.alias, n.wallet_name, n.address)] AS cycle_nodes, length(p) AS L
RETURN cycle_nodes, L
ORDER BY L, cycle_nodes
LIMIT 50;


CALL gds.triangleCount.stream('nftUndirected')
YIELD nodeId, triangleCount
WITH gds.util.asNode(nodeId) AS w, triangleCount
WHERE triangleCount > 0
RETURN coalesce(w.alias, w.wallet_name, w.address) AS wallet,
       triangleCount
ORDER BY triangleCount DESC
LIMIT 20;


//4) SIMILARITY MEASURE
//Jaccard (undirected)

CALL gds.nodeSimilarity.stream(
  'nftUndirected',
  { topK: 20, degreeCutoff: 1, similarityCutoff: 0.0 }   // filter isolates
)
YIELD node1, node2, similarity
WITH gds.util.asNode(node1) AS a, gds.util.asNode(node2) AS b, similarity
RETURN coalesce(a.alias, a.wallet_name, a.address) AS wallet1,
       coalesce(b.alias, b.wallet_name, b.address) AS wallet2,
       round(similarity, 3)                        AS jaccard_similarity
ORDER BY jaccard_similarity DESC, wallet1, wallet2
LIMIT 50;


// Cosine 

CALL gds.nodeSimilarity.stream(
  'nftUndirected',
  { topK: 20, degreeCutoff: 1, similarityMetric: 'COSINE' }
)
YIELD node1, node2, similarity
WITH gds.util.asNode(node1) AS a, gds.util.asNode(node2) AS b, similarity
RETURN coalesce(a.alias, a.wallet_name, a.address) AS wallet1,
       coalesce(b.alias, b.wallet_name, b.address) AS wallet2,
       round(similarity, 3)                        AS cosine_similarity
ORDER BY cosine_similarity DESC, wallet1, wallet2
LIMIT 50;


// 5) HOMOPHILY


MATCH (w:Wallet)
OPTIONAL MATCH (w)-[o:TRANSFERRED_TO]->()
OPTIONAL MATCH ()-[i:TRANSFERRED_TO]->(w)
RETURN w.address        AS wallet,
       coalesce(w.alias, w.wallet_name, 'Unknown') AS name,
       count(o) AS out_tx,
       count(i) AS in_tx,
       (count(o) + count(i)) AS total_tx,
       CASE WHEN count(i) > 0 THEN 1.0 * count(o) / count(i) ELSE count(o) END AS activity_ratio
ORDER BY total_tx DESC, wallet;


// Behavioral homophily across connected pairs

MATCH (w1:Wallet)-[:TRANSFERRED_TO]-(w2:Wallet)
WHERE id(w1) < id(w2)
OPTIONAL MATCH (w1)-[o1:TRANSFERRED_TO]->()
OPTIONAL MATCH ()-[i1:TRANSFERRED_TO]->(w1)
OPTIONAL MATCH (w2)-[o2:TRANSFERRED_TO]->()
OPTIONAL MATCH ()-[i2:TRANSFERRED_TO]->(w2)
WITH w1, w2,
     count(o1) AS out1, count(i1) AS in1,
     count(o2) AS out2, count(i2) AS in2
WITH w1, w2, out1, in1, out2, in2,
     abs(out1 - out2) + abs(in1 - in2) AS diff,
     (out1 + in1 + out2 + in2)         AS total
WITH w1, w2, out1, in1, out2, in2, total,
     CASE WHEN total = 0 THEN 0 ELSE 1.0 - (1.0 * diff / total) END AS similarity
RETURN coalesce(w1.alias,w1.wallet_name,w1.address) AS wallet1,
       coalesce(w2.alias,w2.wallet_name,w2.address) AS wallet2,
       out1, in1, out2, in2,
       round(similarity,3)                          AS behavioral_homophily
ORDER BY behavioral_homophily DESC, wallet1, wallet2
LIMIT 25;


// 6) NETWORK TOPOLOGY
// Global clustering coefficient 
CALL gds.localClusteringCoefficient.stream('nftUndirected')
YIELD localClusteringCoefficient
RETURN round(avg(localClusteringCoefficient), 3) AS global_clustering_coefficient;


// Average Path length 
CALL gds.allShortestPaths.stream('nftUndirected')
YIELD sourceNodeId, targetNodeId, distance
WHERE distance IS NOT NULL AND distance > 0
RETURN round(avg(distance), 3) AS average_path_length,
       min(distance)          AS shortest_path,
       max(distance)          AS longest_path,
       count(*)               AS pair_count;


// Density evolution over time (monthly snapshots)

:param startMonth => date('2024-12-01');  
:param endMonth   => date('2025-09-01');  


WITH range(0, duration.between($startMonth, $endMonth).months - 1) AS mrange
UNWIND mrange AS m
WITH date.truncate('month', ($startMonth + duration({months:m}))) AS monthStart,
     date.truncate('month', ($startMonth + duration({months:m+1}))) AS monthEnd


MATCH (a:Wallet)-[tr:TRANSFERRED_TO]->(b:Wallet)
WITH monthStart, monthEnd, a, b, tr,
     CASE
       WHEN tr.timestamp IS NULL THEN NULL
       WHEN tr.timestamp =~ '^\d+$' THEN datetime({epochSeconds: toInteger(tr.timestamp)})
       ELSE datetime(replace(toString(tr.timestamp),' ','T'))
     END AS ts
WHERE ts IS NOT NULL
  AND date(ts) >= monthStart AND date(ts) < monthEnd


WITH monthStart AS month,
     collect( DISTINCT CASE WHEN id(a) < id(b) THEN [id(a),id(b)] ELSE [id(b),id(a)] END ) AS undirectedPairs
UNWIND undirectedPairs AS pair
WITH month, pair[0] AS id1, pair[1] AS id2
MATCH (w1:Wallet) WHERE id(w1) = id1
MATCH (w2:Wallet) WHERE id(w2) = id2
WITH month, collect(DISTINCT w1) + collect(DISTINCT w2) AS ws, count(*) AS E
WITH month, apoc.coll.toSet(ws) AS wallets, E
WITH month, size(wallets) AS N, E
RETURN toString(month) AS month,
       N               AS nodes_in_month,
       E               AS undirected_edges,
       CASE WHEN N < 2 THEN 0.0 ELSE round( (1.0 * E) / (N*(N-1)/2.0), 4) END AS density_undirected
ORDER BY month;
