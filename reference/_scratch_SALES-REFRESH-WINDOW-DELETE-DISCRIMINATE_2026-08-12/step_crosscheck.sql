WITH g AS (
  SELECT 'G1_marketplace' AS grp, '31d135bc-4df8-11f1-0a80-1c8a0053c5b4' AS agent_id, DATE('2026-05-12') AS d UNION ALL
  SELECT 'G2_0603',   'b3667c34-3ca3-11f0-0a80-15ce0025d38d', DATE('2026-06-03') UNION ALL
  SELECT 'G3_0604',   '18a13a53-87c0-11ef-0a80-1568002f42aa', DATE('2026-06-04') UNION ALL
  SELECT 'G4_0615',   'b3667c34-3ca3-11f0-0a80-15ce0025d38d', DATE('2026-06-15') UNION ALL
  SELECT 'G5_0702',   '2db2c3dd-5f17-11f1-0a80-1d6500046ebf', DATE('2026-07-02') UNION ALL
  SELECT 'G6_0711',   'b3667c34-3ca3-11f0-0a80-15ce0025d38d', DATE('2026-07-11') UNION ALL
  SELECT 'G7_0713',   '4d4bb3c6-7396-11f1-0a80-1357002a9eb8', DATE('2026-07-13') UNION ALL
  SELECT 'G8_0720',   'a08652a8-5e52-11f1-0a80-0cb7000604b7', DATE('2026-07-20') UNION ALL
  SELECT 'G9_0721',   '356fb156-83ed-11f1-0a80-173600242e0d', DATE('2026-07-21') UNION ALL
  SELECT 'G10_0727a', '75d7c694-78f9-11f0-0a80-077d000b5e09', DATE('2026-07-27') UNION ALL
  SELECT 'G11_0727b', 'f4201bf6-6390-11f0-0a80-0fa2000d75eb', DATE('2026-07-27') UNION ALL
  SELECT 'G12_0729',  '79dc242a-1baf-11f1-0a80-138a002eeb35', DATE('2026-07-29') UNION ALL
  SELECT 'G13_0730',  'b3667c34-3ca3-11f0-0a80-15ce0025d38d', DATE('2026-07-30')
),
snap_cnt AS (
  SELECT agent_id, DATE(transaction_date) AS d, COUNT(*) AS n_snap
  FROM `msklad-bi-prod.core.fact_sales_profit_snap_20260811_163306`
  GROUP BY 1, 2
),
cur_cnt AS (
  SELECT agent_id, DATE(transaction_date) AS d, COUNT(*) AS n_current
  FROM `msklad-bi-prod.core.fact_sales_profit`
  GROUP BY 1, 2
)
SELECT
  g.grp,
  g.agent_id,
  g.d AS transaction_date,
  IFNULL(s.n_snap, 0)    AS n_snap,
  IFNULL(c.n_current, 0) AS n_current,
  IFNULL(s.n_snap, 0) - IFNULL(c.n_current, 0) AS delta
FROM g
LEFT JOIN snap_cnt s USING (agent_id, d)
LEFT JOIN cur_cnt  c USING (agent_id, d)
ORDER BY g.grp;
