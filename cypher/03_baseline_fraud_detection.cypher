//FRAUD PATTERNS 


// 1) WASH TRADING

:param tokenId => 3600;          
:param maxHours => 24; 

// WASH-TRADING RISK (back-and-forth A<->B on same token) 
MATCH (a:Wallet)-[e1:TRANSFERRED_TO]->(b:Wallet)
WHERE ($tokenId IS NULL OR e1.token_id = $tokenId)
WITH a,b,collect(e1) AS e1s
MATCH (b)-[e2:TRANSFERRED_TO]->(a)
WHERE ($tokenId IS NULL OR e2.token_id = $tokenId)
WITH a,b,e1s,collect(e2) AS e2s

WITH a,b,
     [x IN e1s |
        CASE
          WHEN x.timestamp =~ '^\d+$' THEN toInteger(x.timestamp)
          ELSE toInteger(datetime(replace(x.timestamp,' ','T')).epochSeconds)
        END] AS t1s,
     [y IN e2s |
        CASE
          WHEN y.timestamp =~ '^\d+$' THEN toInteger(y.timestamp)
          ELSE toInteger(datetime(replace(y.timestamp,' ','T')).epochSeconds)
        END] AS t2s

WITH a,b,size(t1s) AS AB, size(t2s) AS BA,
     reduce(m=999999999, t1 IN t1s |
       reduce(m2=m, t2 IN t2s | CASE WHEN abs(t1 - t2) < m2 THEN abs(t1 - t2) ELSE m2 END)
     ) AS minGapSec
WITH a,b,AB,BA, CASE WHEN minGapSec=999999999 THEN NULL ELSE minGapSec END AS minGapSec

WITH CASE
       WHEN AB>=1 AND BA>=1 AND minGapSec IS NOT NULL AND minGapSec <= $maxHours*3600 THEN 3
       WHEN AB>=1 AND BA>=1 THEN 2
       ELSE 1
     END AS riskScore

RETURN CASE
         WHEN count(*) = 0           THEN 'ZERO'
         WHEN max(riskScore) = 3     THEN 'HIGH'
         WHEN max(riskScore) = 2     THEN 'MEDIUM'
         ELSE 'LOW'
       END AS wash_trading_risk;


// 2) CIRCULAR TRADING
:param tokenId => 3600;     

// CIRCULAR TRADING RISK (3–6 wallet directed loops) 
MATCH p = (w:Wallet)-[:TRANSFERRED_TO*3..6]->(w)
WHERE
  all(r IN relationships(p) WHERE $tokenId IS NULL OR r.token_id = $tokenId)
  AND all(n IN nodes(p) WHERE id(w) <= id(n))
WITH count(p) AS cycles

RETURN CASE
         WHEN cycles = 0   THEN 'ZERO'
         WHEN cycles <= 2  THEN 'MEDIUM'
         ELSE 'HIGH'
       END AS circular_trading_risk;


// 3) VOLUME INFLATION RISK
:param tokenId => 3600;
:param timeWindowMinutes => 60;

// VOLUME INFLATION RISK (1h window) 
MATCH (t:Transaction)-[:EXCHANGED]->(:NFT {token_id: $tokenId})
WHERE t.timestamp IS NOT NULL
WITH t,
     CASE
       WHEN t.timestamp =~ '^\d+$'           
         THEN toInteger(t.timestamp)
       ELSE datetime(replace(t.timestamp,' ','T')).epochSeconds
     END AS ts
WITH floor(ts / ($timeWindowMinutes * 60)) AS bucket, t
WITH bucket, count(*) AS txCount,
     collect(DISTINCT t.from_wallet) + collect(DISTINCT t.to_wallet) AS all_wallets
WITH txCount, size(apoc.coll.toSet(all_wallets)) AS walletCount

WITH max(
  CASE
    WHEN txCount >= 5 AND walletCount <= 3 THEN 3     
    WHEN txCount >= 3 AND walletCount <= 4 THEN 2     
    ELSE 1                                            
  END
) AS maxBucketScore

RETURN CASE
         WHEN maxBucketScore IS NULL THEN 'ZERO'
         WHEN maxBucketScore = 3 THEN 'HIGH'
         WHEN maxBucketScore = 2 THEN 'MEDIUM'
         ELSE 'LOW'
       END AS volume_inflation_risk;


// 4) BOT ACTIVITY RISK 
MATCH (w:Wallet)-[:INVOLVED_IN]->(t:Transaction)-[:EXCHANGED]->(:NFT {token_id: $tokenId})
WHERE t.timestamp IS NOT NULL

WITH w,
     CASE
       WHEN t.timestamp =~ '^\d+$'
         THEN toInteger(t.timestamp)
       ELSE datetime(replace(t.timestamp,' ','T')).epochSeconds
     END AS ts

WITH w, apoc.coll.sort(collect(ts)) AS times
WITH w, size(times) AS txCount,
     CASE
       WHEN size(times) < 2 THEN null
       ELSE [i IN range(1, size(times)-1) | times[i] - times[i-1]]
     END AS gaps
WITH w, txCount,
     CASE
       WHEN gaps IS NULL OR size(gaps) = 0 THEN null
       ELSE apoc.coll.min(gaps)
     END AS minGapSeconds

WITH
  CASE
    WHEN txCount >= 4 AND minGapSeconds <= 60    THEN 3   
    WHEN txCount >= 3 AND minGapSeconds <= 300   THEN 2   
    WHEN txCount >= 2 AND minGapSeconds <= 900   THEN 1   
    ELSE 0
  END AS walletScore
WITH max(walletScore) AS maxScore
RETURN CASE
         WHEN maxScore IS NULL OR maxScore = 0 THEN 'ZERO'
         WHEN maxScore = 1 THEN 'LOW'
         WHEN maxScore = 2 THEN 'MEDIUM'
         ELSE 'HIGH'
       END AS bot_activity_risk;


//---- PRICE ASSIGNMENT

:param tokenId => 3600;
:param basePrice => 1.00;
:param gentleRisePerStep => 0.01;   
:param pumpMultiplier => 1.60;      
:param dumpMultiplier => 0.85;      

// --- ASSIGN SYNTHETIC PRICES (0–40% small rise → 40–60% pump → 60–100% dump) ---
MATCH (t:Transaction)-[:EXCHANGED]->(:NFT {token_id: $tokenId})
WITH t,
     CASE 
       WHEN t.timestamp =~ '^\d+$' 
         THEN toInteger(t.timestamp)
       ELSE datetime(replace(t.timestamp,' ','T')).epochSeconds
     END AS ts
ORDER BY ts
WITH collect(t) AS txs, size(collect(t)) AS n
FOREACH (i IN range(0, n-1) |
  FOREACH (tx IN [txs[i]] |
    SET tx.eth_value =
      CASE
        WHEN i < toInteger(n * 0.4)                           // 0..40%
          THEN $basePrice + ($gentleRisePerStep * i)
        WHEN i < toInteger(n * 0.6)                           // 40..60%
          THEN $basePrice * $pumpMultiplier
        ELSE                                                  // 60..100%
          $basePrice * $dumpMultiplier
      END
  )
)
RETURN 'synthetic prices set' AS status;


// 5) COORDINATED BUYING/SELLING
:param tokenId => 3600;
:param minutes  => 15;
:param priceTolerance => 0.05;
:param lowThresholdWallets  => 2;
:param medThresholdWallets  => 3;
:param highThresholdWallets => 4;

MATCH (t:Transaction)-[:EXCHANGED]->(:NFT {token_id:$tokenId})
WITH t,
     CASE
       WHEN t.timestamp =~ '^\d+$'
         THEN datetime({epochSeconds: toInteger(t.timestamp)})
       ELSE datetime(replace(t.timestamp,' ','T'))
     END AS ts

WITH t, toInteger(floor(ts.epochSeconds / ($minutes*60))) * ($minutes*60) AS bucketEpoch
WITH datetime({epochSeconds: bucketEpoch}) AS bucket, t
WITH bucket,
     apoc.coll.toSet(collect(t.from_wallet) + collect(t.to_wallet)) AS wallets,
     collect(toFloat(t.eth_value)) AS prices
WITH size(wallets) AS walletCount,
     apoc.coll.min(prices) AS pMin,
     apoc.coll.max(prices) AS pMax
WITH CASE
       WHEN pMin IS NULL OR pMin = 0 THEN 0
       WHEN walletCount >= $highThresholdWallets AND (pMax - pMin) <= pMin * $priceTolerance       THEN 3
       WHEN walletCount >= $medThresholdWallets  AND (pMax - pMin) <= pMin * ($priceTolerance*1.5) THEN 2
       WHEN walletCount >= $lowThresholdWallets                                                   THEN 1
       ELSE 0
     END AS windowScore
RETURN CASE max(windowScore)
         WHEN 3 THEN 'HIGH'
         WHEN 2 THEN 'MEDIUM'
         WHEN 1 THEN 'LOW'
         ELSE 'ZERO'
       END AS coordinated_price_risk;


// 6) PUMP AND DUMP
:param tokenId => 3600;
:param minutes => 60;               
:param lookaheadBuckets => 3;       
:param spikePct => 0.30;            
:param dropPct  => 0.25;            
:param lowDiversity => 3;           

// PUMP & DUMP RISK (returns ZERO / MEDIUM / HIGH)

MATCH (t:Transaction)-[:EXCHANGED]->(:NFT {token_id: $tokenId})
WITH
  CASE
    WHEN t.timestamp =~ '^\d+$' THEN toInteger(t.timestamp)
    ELSE datetime(replace(t.timestamp,' ','T')).epochSeconds
  END AS ts,
  toFloat(t.eth_value) AS price,
  t.from_wallet AS fromW,
  t.to_wallet   AS toW
WHERE price IS NOT NULL


WITH toInteger(floor(ts / ($minutes * 60))) AS bucket, price, fromW, toW
WITH bucket,
     avg(price) AS avgPrice,
     size( (collect(DISTINCT fromW) + collect(DISTINCT toW)) ) AS walletCount
ORDER BY bucket


WITH collect({b: bucket, p: avgPrice, w: walletCount}) AS s
WHERE size(s) >= 2


UNWIND range(0, size(s)-2) AS i
WITH s, i, s[i] AS cur,
     CASE
       WHEN i + $lookaheadBuckets < size(s) THEN i + $lookaheadBuckets
       ELSE size(s) - 1
     END AS endIndex


WITH cur,
     [x IN s[i+1..endIndex] | x.p] AS futurePrices,
     [x IN s[i+1..endIndex] | x.w] AS futureWallets

WITH cur,
     reduce(mx = 0.0, x IN futurePrices  | CASE WHEN x > mx THEN x ELSE mx END) AS pmax,
     reduce(mn = 1e15, x IN futurePrices | CASE WHEN x < mn THEN x ELSE mn END) AS pmin,
     reduce(mw = 1e9,  x IN futureWallets| CASE WHEN x < mw THEN x ELSE mw END) AS minWallets
WITH
  cur,
  CASE WHEN cur.p > 0  THEN (pmax - cur.p) / cur.p ELSE 0 END AS spike,
  CASE WHEN pmax  > 0  THEN (pmax - pmin) / pmax ELSE 0 END AS dump,
  minWallets


WHERE spike >= $spikePct
  AND dump  >= $dropPct
  AND minWallets <= $lowDiversity


RETURN CASE
         WHEN count(*) = 0 THEN 'ZERO'
         WHEN count(*) = 1 THEN 'MEDIUM'
         ELSE 'HIGH'
       END AS pump_dump_risk;


// Remove synthetic ETH values from all transactions
MATCH (t:Transaction)
WHERE t.eth_value IS NOT NULL
REMOVE t.eth_value
RETURN count(t) AS cleaned_transactions;


// Check if any synthetic prices were saved
MATCH (t:Transaction)
WHERE t.eth_value IS NOT NULL
RETURN count(t) AS transactions_with_prices,
       collect(distinct t.eth_value)[0..10] AS sample_prices;
