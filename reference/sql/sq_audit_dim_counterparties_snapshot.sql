INSERT INTO `msklad-bi-prod.audit.dim_counterparties_snapshots`
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM `msklad-bi-prod.core.dim_counterparties`;
