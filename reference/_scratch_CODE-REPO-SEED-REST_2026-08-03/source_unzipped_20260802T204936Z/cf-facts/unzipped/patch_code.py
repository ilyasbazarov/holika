import os

with open("fetch_purchases.py", "r") as f:
    fetch_code = f.read()

if "order_name =" not in fetch_code:
    fetch_code = fetch_code.replace(
        'moment_str   = order.get("moment", "")',
        'order_name   = order.get("name")\n        moment_str   = order.get("moment", "")'
    )
    fetch_code = fetch_code.replace(
        '"purchase_order_id":      order_id,',
        '"order_name":             order_name,\n                "purchase_order_id":      order_id,'
    )
    with open("fetch_purchases.py", "w") as f:
        f.write(fetch_code)
    print("✅ fetch_purchases.py успешно пропатчен")

with open("bq_ops.py", "r") as f:
    bq_code = f.read()

if '"order_name"' not in bq_code:
    bq_code = bq_code.replace(
        'bigquery.SchemaField("position_id",',
        'bigquery.SchemaField("order_name",        "STRING"),\n    bigquery.SchemaField("position_id",'
    )
    with open("bq_ops.py", "w") as f:
        f.write(bq_code)
    print("✅ bq_ops.py успешно пропатчен")
