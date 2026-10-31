// FRAUD PATTERNS

//1) WASH TRADING

:param tokenId => null;    
:param maxHours => 24;    

// --- WASH-TRADING RISK (directed back-and-forth loops) ---
MATCH (a:Wallet)-[e1:TRANSFERRED_TO]->(b:Wallet)
WHERE a <> b AND ($tokenId IS NULL OR e1.token_id = $tokenId)
WITH a,b,collect(e1) AS abEdges

MATCH (b)-[e2:TRANSFERRED_TO]->(a)
WHERE ($tokenId IS NULL OR e2.token_id = $tokenId)
WITH a,b,abEdges,collect(e2) AS baEdges


WITH a,b,
     [x IN abEdges |
        CASE
          WHEN x.timestamp IS NULL THEN null
          WHEN x.timestamp =~ '^\d+$' THEN toInteger(x.timestamp)
          ELSE datetime(replace(toString(x.timestamp),' ','T')).epochSeconds
        END] AS tAB,
     [y IN baEdges |
        CASE
          WHEN y.timestamp IS NULL THEN null
          WHEN y.timestamp =~ '^\d+$' THEN toInteger(y.timestamp)
          ELSE datetime(replace(toString(y.timestamp),' ','T')).epochSeconds
        END] AS tBA

WITH a,b,
     [t IN tAB WHERE t IS NOT NULL] AS tAB,
     [t IN tBA WHERE t IS NOT NULL] AS tBA
WHERE size(tAB) > 0 AND size(tBA) > 0


WITH a,b,
     reduce(minGap = 999999999,
            t1 IN tAB |
              reduce(m2 = minGap, t2 IN tBA |
                CASE WHEN abs(t1 - t2) < m2 THEN abs(t1 - t2) ELSE m2 END)
     ) AS minGapSec

WITH CASE
       WHEN minGapSec < 999999999 AND minGapSec <= $maxHours * 3600 THEN 3   
       WHEN minGapSec < 999999999 THEN 2                                    
       ELSE 1
     END AS score
RETURN CASE
         WHEN count(*) = 0        THEN 'ZERO'
         WHEN max(score) = 3      THEN 'HIGH'
         WHEN max(score) = 2      THEN 'MEDIUM'
         ELSE 'LOW'
       END AS wash_trading_risk;


MATCH (a:Wallet)-[e1:TRANSFERRED_TO]->(b:Wallet)
WHERE a <> b
  AND ($tokenId IS NULL OR toString(e1.token_id) = toString($tokenId))
WITH a,b,
     collect({
       dir: 'A→B',
       tx:  e1.tx_hash,
       tok: toString(e1.token_id),
       ts:  CASE
              WHEN e1.timestamp IS NULL THEN NULL
              WHEN e1.timestamp =~ '^\d+$'
                THEN datetime({epochSeconds: toInteger(e1.timestamp)})
              ELSE datetime(replace(toString(e1.timestamp),' ','T'))
            END
     }) AS ab

MATCH (b)-[e2:TRANSFERRED_TO]->(a)
WHERE ($tokenId IS NULL OR toString(e2.token_id) = toString($tokenId))
WITH a,b,ab,
     collect({
       dir: 'B→A',
       tx:  e2.tx_hash,
       tok: toString(e2.token_id),
       ts:  CASE
              WHEN e2.timestamp IS NULL THEN NULL
              WHEN e2.timestamp =~ '^\d+$'
                THEN datetime({epochSeconds: toInteger(e2.timestamp)})
              ELSE datetime(replace(toString(e2.timestamp),' ','T'))
            END
     }) AS ba
WHERE size(ab) > 0 AND size(ba) > 0


UNWIND ab AS x
UNWIND ba AS y
WITH a,b,x,y,
     abs(duration.inSeconds(x.ts, y.ts).seconds) AS diffSec
WHERE x.ts IS NOT NULL AND y.ts IS NOT NULL


WITH a,b,
     collect({ab:x, ba:y, diffSec:diffSec}) AS crossPairs

WITH a,b,
     [p IN crossPairs WHERE p.diffSec <= ($maxHours*3600) | p] AS fastPairs,
     [p IN crossPairs | p.diffSec]                              AS allDiffs
WITH a,b, fastPairs, allDiffs,
     size(fastPairs)                                            AS hits,
     CASE WHEN size(allDiffs)=0 THEN null
          ELSE reduce(m=allDiffs[0], d IN allDiffs | CASE WHEN d<m THEN d ELSE m END)
     END                                                        AS minDiff


WITH a,b,hits,minDiff,
     CASE WHEN hits >= 3 THEN 'HIGH'
          WHEN hits = 2 THEN 'MEDIUM'
          WHEN hits = 1 THEN 'LOW'
          ELSE 'NONE'
     END AS risk,
     fastPairs[0..5]                                            AS samples

RETURN
  toLower(a.address) AS from_wallet,
  coalesce(a.alias, a.wallet_name, 'Unknown') AS from_alias,
  toLower(b.address) AS to_wallet,
  coalesce(b.alias, b.wallet_name, 'Unknown') AS to_alias,
  hits AS fast_back_and_forth,
  CASE WHEN minDiff IS NULL THEN null ELSE round(minDiff/3600.0,3) END AS min_hours_between_any,
  risk AS wash_trading_risk,
  [p IN samples |
     {
       token:   p.ab.tok,
       ab_tx:   p.ab.tx, ab_ts: p.ab.ts,
       ba_tx:   p.ba.tx, ba_ts: p.ba.ts,
       gap_min: round(p.diffSec/60.0,1)
     }
  ] AS sample_evidence
ORDER BY fast_back_and_forth DESC, min_hours_between_any ASC
LIMIT 5;


//2) CIRCULAR TRADING 

:param days => 7;          
:param tokenId => null;     

// - DIRECTED 3–5 CYCLES
MATCH p = (w:Wallet)-[rs:TRANSFERRED_TO*3..5]->(w)
WITH nodes(p) AS ns, relationships(p) AS rels


WHERE $tokenId IS NULL OR all(r IN rels WHERE r.token_id = $tokenId)


WITH ns, rels,
     [r IN rels |
        CASE
          WHEN r.timestamp IS NULL                      THEN NULL
          WHEN r.timestamp =~ '^\d+$'                   THEN datetime({epochSeconds: toInteger(r.timestamp)})
          ELSE datetime(replace(toString(r.timestamp),' ','T'))
        END
     ] AS tss
WHERE all(t IN tss WHERE t IS NOT NULL)
  AND duration.between(apoc.coll.min(tss), apoc.coll.max(tss)).days <= $days


WITH ns, [n IN ns | id(n)] AS ids
WITH ns, ids,
     apoc.coll.min(ids)                                  AS mn,
     apoc.coll.indexOf(ids, apoc.coll.min(ids))          AS pos,
     size(ids)                                           AS L
WITH ns, [i IN range(0, L-1) | ids[(i + pos) % L]]       AS canonIds
WITH ns, apoc.text.join([x IN canonIds | toString(x)], '-') AS cycleSig


UNWIND ns AS participant
WITH participant, collect(DISTINCT cycleSig) AS cycles
RETURN
  coalesce(participant.alias, participant.wallet_name, participant.address) AS wallet,
  size(cycles) AS cycles_count,
  CASE
    WHEN size(cycles) = 0   THEN 'ZERO'
    WHEN size(cycles) <= 2  THEN 'LOW'
    WHEN size(cycles) <= 5  THEN 'MEDIUM'
    ELSE                        'HIGH'
  END AS circular_trading_risk
ORDER BY cycles_count DESC, wallet
LIMIT 100;


//3) VOLUME INFLATION
:param bucketHours => 6;        
:param minTx       => 3;        
:param lowRatio    => 2.0;      
:param mediumRatio => 3.5;
:param highRatio   => 5.0;


MATCH (w:Wallet)-[tr:TRANSFERRED_TO]-(c:Wallet)
WITH w, c, tr,
     CASE
       WHEN tr.timestamp IS NULL                    THEN NULL
       WHEN tr.timestamp =~ '^\d+$'                 THEN datetime({epochSeconds: toInteger(tr.timestamp)})
       ELSE datetime(replace(toString(tr.timestamp),' ','T'))
     END AS ts
WHERE ts IS NOT NULL

WITH w, c, toInteger(floor(ts.epochSeconds / (3600 * $bucketHours))) AS bIdx
WITH w, c, datetime({epochSeconds: bIdx * 3600 * $bucketHours}) AS bucket


WITH coalesce(w.alias, w.wallet_name, w.address) AS wallet,
     bucket,
     count(*)                                    AS tx_count,
     count(DISTINCT toLower(coalesce(c.address, c.addr_lc))) AS partners
WITH wallet, bucket, tx_count,
     CASE WHEN partners = 0 THEN 1 ELSE partners END AS partners,
     1.0 * tx_count / CASE WHEN partners = 0 THEN 1 ELSE partners END AS ratio


WITH wallet,
     max(tx_count) AS max_tx_in_bucket,
     max(ratio)    AS max_ratio


RETURN wallet,
       max_tx_in_bucket,
       round(max_ratio, 2) AS max_tx_per_partner_ratio,
       CASE
         WHEN max_tx_in_bucket < $minTx                 THEN 'ZERO'
         WHEN max_ratio >= $highRatio                   THEN 'HIGH'
         WHEN max_ratio >= $mediumRatio                 THEN 'MEDIUM'
         WHEN max_ratio >= $lowRatio                    THEN 'LOW'
         ELSE 'LOW'
       END AS volume_inflation_risk
ORDER BY volume_inflation_risk DESC, max_tx_in_bucket DESC, wallet
LIMIT 100;


// 4) BOT ACCOUNTS 
:param shortGapSec   => 600;   
:param veryShortSec  => 60;    
:param minTx         => 3;     


MATCH (w:Wallet)-[tr:TRANSFERRED_TO]-()
WITH w, tr,
     CASE
       WHEN tr.timestamp IS NULL                    THEN NULL
       WHEN tr.timestamp =~ '^\d+$'                 THEN toInteger(tr.timestamp)
       ELSE datetime(replace(toString(tr.timestamp),' ','T')).epochSeconds
     END AS ts
WHERE ts IS NOT NULL


WITH w, collect(ts) AS times
WITH w, apoc.coll.sort(times) AS t
WITH w, size(t) AS n,
     CASE
       WHEN size(t) < 2 THEN []
       ELSE [i IN range(1, size(t)-1) | t[i] - t[i-1]]
     END AS gaps


WITH w, n, gaps,
     CASE WHEN size(gaps)=0 THEN 999999999 ELSE reduce(m=999999999, g IN gaps | CASE WHEN g < m THEN g ELSE m END) END AS minGap,
     size(gaps) AS gcount,
     reduce(c=0, g IN gaps | CASE WHEN g <= $shortGapSec THEN c+1 ELSE c END) AS shortCnt,
     reduce(c=0, g IN gaps | CASE WHEN g <= $veryShortSec THEN c+1 ELSE c END) AS vShortCnt,
     CASE
       WHEN size(gaps) < 2 THEN 0
       ELSE reduce(r=0, i IN range(1, size(gaps)-1) |
             CASE WHEN gaps[i-1] <= $shortGapSec AND gaps[i] <= $shortGapSec THEN r+1 ELSE r END)
     END AS shortRuns

WITH coalesce(w.alias, w.wallet_name, w.address) AS wallet,
     n,
     gcount,
     minGap,
     (CASE WHEN gcount = 0 THEN 0.0 ELSE 1.0 * shortCnt  / gcount END) AS shortShare,
     (CASE WHEN gcount = 0 THEN 0.0 ELSE 1.0 * vShortCnt / gcount END) AS vShortShare,
     shortRuns


WITH wallet, n, minGap, shortShare, vShortShare, shortRuns,
     CASE
       WHEN n < $minTx                                     THEN 'ZERO'
       WHEN vShortShare >= 0.30 OR minGap <= $veryShortSec THEN 'HIGH'     
       WHEN shortShare  >= 0.70 OR shortRuns >= 2          THEN 'HIGH'     
       WHEN shortShare  >= 0.40 OR minGap <= $shortGapSec  THEN 'MEDIUM'   
       WHEN shortShare  >= 0.20                            THEN 'LOW'
       ELSE 'ZERO'
     END AS bot_activity_risk

RETURN wallet,
       bot_activity_risk
ORDER BY
  CASE bot_activity_risk WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 1 ELSE 0 END DESC,
  wallet
LIMIT 8;


:param basePrice => 1.00;
:param gentleRisePerStep => 0.01;
:param pumpMultiplier => 1.60;
:param dumpMultiplier => 0.85;


// --- ASSIGN SYNTHETIC PRICES TO ALL TRANSACTIONS (same scheme as the baseline:
// 0–40% small rise → 40–60% pump → 60–100% dump). On-chain transfers carry no price,
// so modules 5 and 6 below are tested on these simulated values.
MATCH (t:Transaction)
WITH t,
     CASE
       WHEN toString(t.timestamp) =~ '^\d+$' THEN toInteger(t.timestamp)
       ELSE datetime(replace(toString(t.timestamp),' ','T')).epochSeconds
     END AS ts
ORDER BY ts, t.tx_hash
WITH collect(t) AS txs
WITH txs, size(txs) AS n
FOREACH (i IN range(0, n-1) |
  FOREACH (tx IN [txs[i]] |
    SET tx.eth_value =
      CASE
        WHEN i < toInteger(n * 0.4) THEN $basePrice + ($gentleRisePerStep * i)
        WHEN i < toInteger(n * 0.6) THEN $basePrice * $pumpMultiplier
        ELSE $basePrice * $dumpMultiplier
      END
  )
)
RETURN 'synthetic prices set' AS status, n AS transactions;


MATCH (t:Transaction)
WHERE t.eth_value IS NOT NULL
RETURN min(t.eth_value) AS min_price,
       max(t.eth_value) AS max_price,
       avg(t.eth_value) AS avg_price,
       count(*)         AS tx_with_prices;


//5) COORDINATED BUYING/SELLING

:param windowMinutes => 15;     
:param priceBucket   => 0.02;   
:param minGroup      => 3;      


MATCH (tx:Transaction)
WHERE tx.eth_value IS NOT NULL
WITH tx,
     CASE
       WHEN tx.timestamp =~ '^\d+$'
         THEN toInteger(tx.timestamp)
       ELSE datetime(replace(toString(tx.timestamp),' ','T')).epochSeconds
     END AS ts
MATCH (seller:Wallet)-[:INVOLVED_IN {role:'sender'}]->(tx)
MATCH (buyer:Wallet )-[:INVOLVED_IN {role:'receiver'}]->(tx)
WITH tx, seller, buyer,
     toInteger(floor(ts / ($windowMinutes * 60)))              AS tBucket,
     toInteger(round(tx.eth_value / $priceBucket))             AS pBucket


WITH tBucket, pBucket, collect(DISTINCT seller) + collect(DISTINCT buyer) AS wallets
WHERE size(wallets) >= $minGroup


UNWIND wallets AS w
WITH w, count(*) AS events


RETURN coalesce(w.alias, w.wallet_name, w.address) AS wallet,
       events                                       AS coordinated_events,
       CASE
         WHEN events = 0 THEN 'ZERO'
         WHEN events = 1 THEN 'LOW'
         WHEN events <= 3 THEN 'MEDIUM'
         ELSE 'HIGH'
       END                                         AS coordinated_trade_risk
ORDER BY coordinated_events DESC, wallet
LIMIT 100;


//6) PUMP AND DUMP


:param windowMinutes => 60;      
:param spikePct       => 0.30;   
:param dumpPct        => 0.30;   
:param concThreshold  => 0.60;   


CALL {
  MATCH (s:Wallet)-[:INVOLVED_IN {role:'sender'}]->(t:Transaction)
  WHERE t.eth_value IS NOT NULL

  WITH t, s,
       CASE
         WHEN t.timestamp IS NULL THEN NULL
         WHEN toString(t.timestamp) =~ '^\d+$'
           THEN datetime({epochSeconds: toInteger(t.timestamp)})
         WHEN toString(t.timestamp) =~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
           THEN datetime(replace(toString(t.timestamp),' ','T'))
         ELSE datetime(toString(t.timestamp))
       END AS ts,
       toFloat(t.eth_value) AS price

  WHERE ts IS NOT NULL

  WITH datetime({epochMillis: (
         (ts.epochMillis / ($windowMinutes*60000)) * ($windowMinutes*60000)
       )}) AS bucket,
       price, s
  WITH bucket, collect(price) AS prices, collect(s) AS sellers,
       count(*) AS txCount, avg(price) AS avgPrice

  WITH bucket, txCount, avgPrice, sellers,
       reduce(mx=0, w IN sellers |
         CASE WHEN size([x IN sellers WHERE x=w]) > mx
              THEN size([x IN sellers WHERE x=w]) ELSE mx END) AS maxCnt
  WITH bucket, txCount, avgPrice, (toFloat(maxCnt)/txCount) AS sellerConc
  ORDER BY bucket

  WITH collect({b:bucket, avg:avgPrice, tx:txCount, conc:sellerConc}) AS bs
  UNWIND range(0, size(bs)-1) AS i
  WITH bs, i, bs[i] AS cur,
       CASE WHEN i>0 THEN bs[i-1] END AS prev,
       CASE WHEN i<size(bs)-1 THEN bs[i+1] END AS nxt
  WITH cur, prev, nxt,
       CASE WHEN prev IS NULL OR prev.avg = 0
            THEN 0.0 ELSE (cur.avg - prev.avg) / prev.avg END AS spike,
       CASE WHEN nxt  IS NULL OR cur.avg  = 0
            THEN 0.0 ELSE (cur.avg - nxt.avg)  / cur.avg END  AS dropPct,
       cur.conc AS conc
  WITH collect({spike:spike, drop:dropPct, conc:conc}) AS rows

  RETURN
    size(rows) AS total_windows,
    size([r IN rows
          WHERE r.spike >= $spikePct
            AND r.drop  >= $dumpPct
            AND r.conc  >= $concThreshold]) AS flagged_windows,
    apoc.coll.max([r IN rows | r.spike]) AS max_spike,
    apoc.coll.max([r IN rows | r.drop])  AS max_drop,
    apoc.coll.max([r IN rows | r.conc])  AS max_conc
}
RETURN
  coalesce(flagged_windows, 0)                 AS flagged_windows,
  coalesce(total_windows, 0)                   AS total_windows,
  round(coalesce(max_spike, 0.0), 3)           AS max_spike,
  round(coalesce(max_drop,  0.0), 3)           AS max_drop,
  round(coalesce(max_conc,  0.0), 3)           AS max_concentration,
  CASE
    WHEN coalesce(flagged_windows,0) = 0 THEN 'ZERO'
    WHEN flagged_windows <= 1              THEN 'LOW'
    WHEN flagged_windows <= 3              THEN 'MEDIUM'
    ELSE                                       'HIGH'
  END AS pump_dump_risk;
