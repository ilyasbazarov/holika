"""
fetch_purchases.py — Pull entity/purchaseorder positions from МойСклад.

Endpoint: entity/purchaseorder (Заказы поставщикам)
Positions: fetched separately per order — expand=positions does NOT work in list mode
           (same constraint as entity/demand, confirmed in Аппендикс Е).

Key fields at POSITION level:
  quantity   — ordered quantity
  shipped    — received quantity (уже принято)
  inTransit  — in-transit quantity (в пути прямо сейчас) ← primary mart filter
  price      — тыйыны → ÷100 → KGS

Key fields at ORDER level:
  state.meta.href    → status UUID → parse to status_id
  rate.value         → exchange rate at order creation (KGS per currency unit)
  deliveryPlannedMoment → planned delivery date (can be None)
  sum                → total order sum тыйыны → ÷100 → KGS

Status UUIDs (confirmed from /purchaseorder/metadata 2026-05-08):
  491d6da5-8b37-11ef-0a80-0762000253a8 — В пути       ← IN_TRANSIT
  491d62b6-8b37-11ef-0a80-0762000253a7 — Прибыл
  87b7a192-349f-11f1-0a80-1a0f000384c2 — Прибыл частично
  87b7a5e5-349f-11f1-0a80-1a0f000384c3 — Отменен

⚠ Manifest had В пути / Прибыл UUIDs SWAPPED — corrected here.
"""

import logging
from datetime import date, timedelta
from typing import Optional

import requests

from config import IN_TRANSIT_STATUS_ID, PURCHASE_ORDER_STATES
from helpers import now_utc_str, paginate_entity, parse_href

log = logging.getLogger(__name__)


def _parse_date_kgt(moment_str: str) -> Optional[str]:
    """
    Parse МойСклад moment string to DATE (KGT timezone).
    Input:  "2025-10-31 08:16:00.000"
    Output: "2025-10-31"
    МойСклад stores moments in KGT (UTC+6), so no timezone conversion needed.
    """
    if not moment_str:
        return None
    return moment_str[:10]


def fetch_purchase_positions(
    token: str,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    session: Optional[requests.Session] = None,
) -> list[dict]:
    """
    Fetch all purchaseorder positions.

    date_from / date_to: filter by order moment (inclusive).
    If both are None: fetch ALL orders (used for bootstrap and WRITE_TRUNCATE refresh).

    Returns flat list of position records, one row per (order × position).
    """
    if session is None:
        session = requests.Session()

    loaded_at = now_utc_str()

    # ── Step 1: fetch order headers
    params: dict = {}
    if date_from and date_to:
        moment_from = f"{date_from.isoformat()} 00:00:00"
        moment_to   = f"{date_to.isoformat()} 23:59:59"
        params["filter"] = f"moment>={moment_from};moment<={moment_to}"
        log.info("Fetching purchaseorders: %s → %s", moment_from, moment_to)
    else:
        log.info("Fetching ALL purchaseorders (bootstrap / full refresh)")

    orders = paginate_entity(token, "entity/purchaseorder", params=params, session=session)
    log.info("Found %d purchaseorders", len(orders))

    all_records: list[dict] = []
    skipped = 0

    for order in orders:
        order_id = order.get("id")
        if not order_id:
            skipped += 1
            continue

        # ── Header fields
        order_name   = order.get("name")
        moment_str   = order.get("moment", "")
        order_date   = _parse_date_kgt(moment_str)
        supplier_id  = parse_href(
            order.get("agent", {}).get("meta", {}).get("href", "")
        )
        currency_rate = order.get("rate", {}).get("value")  # KGS per unit

        # Planned delivery (optional field)
        delivery_str  = order.get("deliveryPlannedMoment")
        planned_delivery_date = _parse_date_kgt(delivery_str) if delivery_str else None

        # Status
        state_href   = order.get("state", {}).get("meta", {}).get("href", "")
        status_id    = parse_href(state_href)
        status_name  = PURCHASE_ORDER_STATES.get(status_id, "Неизвестен") if status_id else None

        # Order-level financial summary (тыйыны → KGS)
        order_sum_kgs = (order.get("sum") or 0) / 100.0

        # ── Step 2: fetch positions for this order
        positions = paginate_entity(
            token,
            f"entity/purchaseorder/{order_id}/positions",
            session=session,
        )

        if not positions:
            log.debug("Order %s has 0 positions — skipping", order_id)
            continue

        for pos in positions:
            pos_id = pos.get("id")
            if not pos_id:
                continue

            product_id = parse_href(
                pos.get("assortment", {}).get("meta", {}).get("href", "")
            )
            if not product_id:
                log.warning("Position %s in order %s has no product_id — skipping", pos_id, order_id)
                continue

            quantity_ordered   = pos.get("quantity", 0.0)
            quantity_shipped   = pos.get("shipped", 0.0)
            quantity_in_transit = pos.get("inTransit", 0.0)
            price_kgs          = (pos.get("price") or 0) / 100.0 * (currency_rate or 1.0)
            discount           = pos.get("discount", 0.0)

            # Sum for this position at ordered quantity
            sum_kgs = round(price_kgs * quantity_ordered * (1.0 - discount / 100.0), 4)
            # Sum of in-transit portion only
            in_transit_sum_kgs = round(price_kgs * quantity_in_transit * (1.0 - discount / 100.0), 4)

            all_records.append({
                "order_name":             order_name,
                "purchase_order_id":      order_id,
                "position_id":            pos_id,
                "order_date":             order_date,
                "planned_delivery_date":  planned_delivery_date,
                "product_id":             product_id,
                "supplier_id":            supplier_id,
                "quantity_ordered":       quantity_ordered,
                "quantity_shipped":       quantity_shipped,
                "quantity_in_transit":    quantity_in_transit,
                "price_kgs":              price_kgs,
                "discount":               discount,
                "sum_kgs":                sum_kgs,
                "in_transit_sum_kgs":     in_transit_sum_kgs,
                "currency_rate":          currency_rate,
                "status_id":              status_id,
                "status_name":            status_name,
                "is_in_transit":          (quantity_in_transit or 0) > 0,
                "_loaded_at":             loaded_at,
            })

    if skipped:
        log.warning("Skipped %d orders (missing id)", skipped)

    log.info(
        "Fetched %d position records from %d purchaseorders",
        len(all_records), len(orders) - skipped,
    )
    return all_records
