"""
fetch_byvariant.py — Pull report/profit/byvariant for COGS refresh (weekly mode).

Used only in weekly (90d rolling) runs to get fresh FIFO-recalculated COGS.
Hourly mode uses the static byvariant backup from bootstrap.

Endpoint confirmed in Аппендикс Г:
  report/profit/byvariant  (NOT /bygood — byvariant keeps SKU-level granularity)

Data is fetched WEEK BY WEEK (like bootstrap) because the endpoint returns
aggregates for the specified window — not daily granularity. Weekly bucketing
is required for the JOIN with demand positions.

Week standard: WEEK(SATURDAY) — confirmed in Аппендикс Ж.
"""

import logging
from datetime import date, timedelta
from typing import Optional

import requests

from helpers import now_utc_str, paginate_entity, parse_href

log = logging.getLogger(__name__)


def _week_boundaries(d: date) -> tuple[date, date]:
    """
    Return (week_start, week_end) for the WEEK(SATURDAY) bucket containing d.
    Week starts on Saturday (МойСклад bootstrap standard, Аппендикс Ж).
    """
    # dow: Monday=0 … Sunday=6. Saturday=5.
    days_since_sat = (d.weekday() - 5) % 7   # 0 if Saturday, 1 if Sunday, …
    week_start = d - timedelta(days=days_since_sat)
    week_end   = week_start + timedelta(days=6)
    return week_start, week_end


def _weeks_in_range(date_from: date, date_to: date) -> list[tuple[date, date]]:
    """
    Return list of (week_start, week_end) buckets covering [date_from, date_to].
    """
    weeks = []
    current = date_from
    while current <= date_to:
        ws, we = _week_boundaries(current)
        if not weeks or weeks[-1][0] != ws:
            weeks.append((ws, min(we, date_to)))
        current = ws + timedelta(days=7)
    return weeks


def fetch_byvariant_cogs(
    token: str,
    date_from: date,
    date_to: date,
    session: Optional[requests.Session] = None,
) -> list[dict]:
    """
    Fetch byvariant profitability data week by week for [date_from, date_to].
    Returns flat list of weekly COGS records for BQ staging load.

    All monetary values: API returns тыйыны → ÷100 → KGS.
    """
    if session is None:
        session = requests.Session()

    loaded_at = now_utc_str()
    weeks     = _weeks_in_range(date_from, date_to)
    all_records: list[dict] = []

    log.info("Fetching byvariant COGS for %d weeks (%s → %s)", len(weeks), date_from, date_to)

    for week_start, week_end in weeks:
        moment_from = f"{week_start.isoformat()} 00:00:00"
        moment_to   = f"{week_end.isoformat()} 23:59:59"

        rows = paginate_entity(
            token,
            "report/profit/byvariant",
            params={
                "momentFrom": moment_from,
                "momentTo":   moment_to,
            },
            session=session,
        )

        if not rows:
            log.debug("Week %s: 0 rows from byvariant", week_start)
            continue

        for row in rows:
            assortment = row.get("assortment", {})
            product_href = assortment.get("meta", {}).get("href", "")
            product_id   = parse_href(product_href)
            if not product_id:
                continue

            # All monetary values in тыйыны → ÷100 → KGS
            sell_sum_kgs    = row.get("sellSum", 0) / 100.0
            cogs_kgs        = row.get("sellCostSum", 0) / 100.0
            return_sum_kgs  = row.get("returnSum", 0) / 100.0
            return_cost_kgs = row.get("returnCostSum", 0) / 100.0
            profit_kgs      = row.get("profit", 0) / 100.0
            sell_quantity   = row.get("sellQuantity", 0.0)

            all_records.append({
                "product_id":       product_id,
                "_week_start":      week_start.isoformat(),
                "sell_quantity":    sell_quantity,
                "sell_sum_kgs":     round(sell_sum_kgs, 4),
                "cogs_kgs":         round(cogs_kgs, 4),
                "return_sum_kgs":   round(return_sum_kgs, 4),
                "return_cost_kgs":  round(return_cost_kgs, 4),
                "profit_kgs":       round(profit_kgs, 4),
                "_loaded_at":       loaded_at,
            })

        log.debug("Week %s: %d byvariant rows", week_start, len(rows))

    log.info("Total byvariant records fetched: %d across %d weeks", len(all_records), len(weeks))
    return all_records
