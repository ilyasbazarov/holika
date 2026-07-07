INSERT INTO `msklad-bi-prod.audit.dim_employees_snapshots`
SELECT *, CURRENT_TIMESTAMP() AS snapshot_at
FROM `msklad-bi-prod.core.dim_employees`;
