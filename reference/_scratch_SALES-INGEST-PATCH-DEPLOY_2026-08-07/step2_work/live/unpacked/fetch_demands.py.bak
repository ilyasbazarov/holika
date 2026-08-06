"""
fetch_demands.py — Pull entity/demand and their positions from МойСклад.

Critical constraint (confirmed in bootstrap Аппендикс Е):
  expand=positions in the list request does NOT work — МойСклад does not expand
  MetaArray collections in list mode. Positions must be fetched separately per demand.

Revenue formula (verified on live data):
  revenue_kgs = (price / 100) * quantity * (1 - discount / 100)
"""

import logging
from datetime import date, timedelta
from typing import Optional

import requests

from config import MSKLAD_RPS
from helpers import now_utc_str, paginate_entity, parse_href

log = logging.getLogger(__name__)

def _fetch_sales_channel_map(token: str, session: requests.Session) -> dict:
    """Build {uuid: name} map for all sales channels."""
    rows = paginate_entity(token, "entity/saleschannel", session=session)
    return {row["id"]: row.get("name") for row in rows}

def _fetch_project_map(token: str, session: requests.Session) -> dict:
    """Build {uuid: name} map for all projects."""
    rows = paginate_entity(token, "entity/project", session=session)
    return {row["id"]: row.get("name") for row in rows}

def _format_moment(d: date) -> str:
    """МойСклад datetime filter format: 'YYYY-MM-DD HH:MM:SS'."""
    return f"{d.isoformat()} 00:00:00"


def fetch_demand_positions(
    token: str,
    date_from: date,
    date_to: date,
    run_id: str,
    session: Optional[requests.Session] = None,
) -> list[dict]:
    """
    Fetch all demand positions in [date_from, date_to] date range.
    Returns flat list of position records ready for NDJSON / BQ staging.

    date_from: inclusive start (moment >= date_from 00:00:00)
    date_to:   inclusive end   (moment <= date_to   23:59:59)
    """
    if session is None:
        session = requests.Session()

    # ── Build lookup maps (fetched once, reused for all demands)
    channel_map = _fetch_sales_channel_map(token, session)
    project_map = _fetch_project_map(token, session)
    log.info("Loaded %d sales channels, %d projects", len(channel_map), len(project_map))

    loaded_at = now_utc_str()

    # ── Step 1: fetch demand headers (no positions, they're a MetaArray)
    moment_from = _format_moment(date_from)
    moment_to   = f"{date_to.isoformat()} 23:59:59"

    log.info("Fetching demands: %s → %s", moment_from, moment_to)

    demands = paginate_entity(
        token,
        "entity/demand",
        params={
            "filter": f"moment>={moment_from};moment<={moment_to}",
            "order": "moment,asc",
        },
        session=session,
    )

    log.info("Found %d demands", len(demands))

    # ── Step 2: per-demand positions fetch
    all_records: list[dict] = []
    skipped_demands = 0

    for demand in demands:
        demand_id = demand.get("id")
        if not demand_id:
            log.warning("Demand missing id: %s", demand)
            skipped_demands += 1
            continue

        agent_href = (
            demand.get("agent", {}).get("meta", {}).get("href", "")
        )
        agent_id = parse_href(agent_href)
        moment_str = demand.get("moment", "")  # "2025-05-06 14:05:00.000"

        # ── Sales channel
        sc_href = demand.get("salesChannel", {}).get("meta", {}).get("href", "")
        sc_id   = parse_href(sc_href) if sc_href else None
        sc_name = channel_map.get(sc_id) if sc_id else None

        # ── Project
        proj_href = demand.get("project", {}).get("meta", {}).get("href", "")
        proj_id   = parse_href(proj_href) if proj_href else None
        proj_name = project_map.get(proj_id) if proj_id else None

        if not agent_id:
            log.warning("Demand %s has no agent — agent_id will be NULL", demand_id)

        # Fetch positions for this demand (separate request — expand doesn't work)
        positions = paginate_entity(
            token,
            f"entity/demand/{demand_id}/positions",
            session=session,
        )

        if not positions:
            log.debug("Demand %s has 0 positions — skipping", demand_id)
            continue

        for pos in positions:
            pos_id = pos.get("id")
            if not pos_id:
                continue

            assortment = pos.get("assortment", {})
            assortment_meta = assortment.get("meta", {})
            product_href = assortment_meta.get("href", "")
            product_id   = parse_href(product_href)
            entity_type  = assortment_meta.get("type", "product")  # product/variant/bundle

            if not product_id:
                log.warning("Position %s in demand %s has no product_id — skipping", pos_id, demand_id)
                continue

            # Financial fields (all in тыйыны → ÷100 → KGS)
            price_kgs  = pos.get("price", 0) / 100.0
            quantity   = pos.get("quantity", 0.0)
            discount   = pos.get("discount", 0.0)          # percent, 0–100
            revenue_kgs = round(price_kgs * quantity * (1.0 - discount / 100.0), 4)

            all_records.append({
                "run_id":               run_id,
                "demand_id":            demand_id,
                "position_id":          pos_id,
                "transaction_date_raw": moment_str,
                "product_id":           product_id,
                "agent_id":             agent_id,
                "quantity":             quantity,
                "price_kgs":            price_kgs,
                "discount":             discount,
                "revenue_kgs":          revenue_kgs,
                "entity_type":          entity_type,
                "_loaded_at":           loaded_at,
                "sales_channel_id":     sc_id,
                "sales_channel_name":   sc_name,
                "project_id":           proj_id,
                "project_name":         proj_name,
            })

    if skipped_demands:
        log.warning("Skipped %d demands (missing id)", skipped_demands)

    log.info(
        "Fetched %d position records from %d demands",
        len(all_records), len(demands) - skipped_demands,
    )
    return all_records