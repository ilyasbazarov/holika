#!/bin/bash
set -u
echo "=== UTC (старт) ==="; date -u
echo "=== gcloud auth list (старт) ==="; gcloud auth list 2>&1 | sed -n '3p'
echo; echo "--- сколько из 29 присутствуют в ядре СЕЙЧАС, с датами загрузки ---"
bq query --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT
  COUNT(*)                        AS present_cnt,
  ROUND(SUM(revenue_kgs),2)       AS sum_kgs,
  MIN(_loaded_at)                 AS loaded_min,
  MAX(_loaded_at)                 AS loaded_max,
  COUNTIF(_loaded_at >= TIMESTAMP "2026-08-11") AS loaded_after_deploy
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_id IN ("786f54b87f1e81ecf04efead3ab59250","8e05d4b486a48d5b018df201217eb7f3","143035c08bea9f9bf479465da01dd254","2dd7b9fda0f4e372442019fde4bdb1f3","df2d662ffe4189c916953d812391d381","7339a844877d1d393033bc3e5ab545cf","b4fb95a49cf529aec2f8c243001aaaa5","117c9c069f920f1d87d550f755040ce2","b52aba22dc70fed8a720cff790470ee9","c5ba231dc86abad9b5aa75d77452c6ae","844460b779964f97e1de571086dfeeef","dd3e3bb9d3677ac6ee454a833bfd0284","5981baeb9fa0cbcf2da68ff6f355762f","41559c6b38b39dfcbffcfa726b131a8f","95a69af832733a3601c244b913e3fb93","b0878364dc7ef46e2e1d971aa18be751","65d08e698b0541471dc772f3d6e91e33","20d93da5fba41b9110bfecce95608aaf","0b47b431aaef54236c0c24882a47e9e9","c393fa3a9646c4cc699ac38c9fed8680","a4e3b8435c8bada17b55c9cce8484ad6","ab1ae815d0cf68034d9053606b5c3087","b68dfe99b406e5709972520aa83b5899","99e65fddd5719ed7d20095f820e33c0d","86baf50a0682bc43d9536cf267010f58","f79a38d440ea111ccb43e8047fb23a59","48a33a41ddc9d429a533c0f1f0f21fb1","4200c0b0d7184d80e1c98aba9d16660b","961a459badd6e45493e4db351ca30d90")
'
echo; echo "--- распределение по датам загрузки ---"
bq query --use_legacy_sql=false --format=prettyjson --max_rows=100 '
SELECT DATE(_loaded_at) AS loaded_date, COUNT(*) AS cnt, ROUND(SUM(revenue_kgs),2) AS sum_kgs
FROM `msklad-bi-prod.core.fact_sales_profit`
WHERE transaction_id IN ("786f54b87f1e81ecf04efead3ab59250","8e05d4b486a48d5b018df201217eb7f3","143035c08bea9f9bf479465da01dd254","2dd7b9fda0f4e372442019fde4bdb1f3","df2d662ffe4189c916953d812391d381","7339a844877d1d393033bc3e5ab545cf","b4fb95a49cf529aec2f8c243001aaaa5","117c9c069f920f1d87d550f755040ce2","b52aba22dc70fed8a720cff790470ee9","c5ba231dc86abad9b5aa75d77452c6ae","844460b779964f97e1de571086dfeeef","dd3e3bb9d3677ac6ee454a833bfd0284","5981baeb9fa0cbcf2da68ff6f355762f","41559c6b38b39dfcbffcfa726b131a8f","95a69af832733a3601c244b913e3fb93","b0878364dc7ef46e2e1d971aa18be751","65d08e698b0541471dc772f3d6e91e33","20d93da5fba41b9110bfecce95608aaf","0b47b431aaef54236c0c24882a47e9e9","c393fa3a9646c4cc699ac38c9fed8680","a4e3b8435c8bada17b55c9cce8484ad6","ab1ae815d0cf68034d9053606b5c3087","b68dfe99b406e5709972520aa83b5899","99e65fddd5719ed7d20095f820e33c0d","86baf50a0682bc43d9536cf267010f58","f79a38d440ea111ccb43e8047fb23a59","48a33a41ddc9d429a533c0f1f0f21fb1","4200c0b0d7184d80e1c98aba9d16660b","961a459badd6e45493e4db351ca30d90")
GROUP BY loaded_date ORDER BY loaded_date
'
echo; echo "=== UTC (конец) ==="; date -u
echo "=== gcloud auth list (конец) ==="; gcloud auth list 2>&1 | sed -n '3p'
