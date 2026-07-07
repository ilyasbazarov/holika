INSERT INTO `msklad-bi-prod.audit.dim_products_snapshots`
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM `msklad-bi-prod.core.dim_products`;
