"""
step3_match_oracle.py — SALES-JULY-K2K3-DISCRIMINATE, шаг (3) приёмки (ADR-141 §5).

Сопоставляет 69 документов из живого GET (шаг 1) с построчным эталоном (PDF,
243 отгрузки, reference/_scratch_SALES-JULY-DAILY-RECON_2026-08-08/pdf_pages_1-7.txt,
разбор уже лежит там, ADR-043 — не переснимать). Печатает документы, которые есть
у нас (живой GET) и отсутствуют в эталоне (сопоставление по номеру документа).
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PDF_TXT = os.path.join(
    os.path.dirname(HERE),
    "_scratch_SALES-JULY-DAILY-RECON_2026-08-08",
    "pdf_pages_1-7.txt",
)

DATES = ["2026-07-20", "2026-07-21", "2026-07-27", "2026-07-29", "2026-07-30"]

row_re = re.compile(
    r'^(?P<name>.+?)\s{2,}(?P<doctype>Отгрузка|Возврат покупателя)\s+(?P<num>\S+)\s+'
    r'(?P<date>\d{2}\.\d{2}\.\d{4})\s+(?P<time>\d{2}:\d{2}:\d{2})\s+(?P<sum>[\d\s]+,\d{2})\s*$'
)


def load_pdf_doc_numbers() -> set[str]:
    lines = open(PDF_TXT, encoding="utf-8").read().splitlines()
    nums = set()
    for ln in lines:
        m = row_re.match(ln)
        if m and m.group("doctype") == "Отгрузка":
            nums.add(m.group("num"))
    return nums


def main() -> None:
    pdf_nums = load_pdf_doc_numbers()
    print(f"Эталон: {len(pdf_nums)} уникальных номеров отгрузок (доктайп Отгрузка)")

    missing_by_date = {}
    for d_str in DATES:
        raw_path = os.path.join(HERE, f"raw_{d_str}.json")
        with open(raw_path, encoding="utf-8") as f:
            records = json.load(f)

        missing = [r for r in records if r["name"] not in pdf_nums]
        missing_by_date[d_str] = missing

        print(f"\n=== {d_str}: {len(records)} документов, {len(missing)} отсутствуют в эталоне ===")
        for r in missing:
            print(
                f"  id={r['id']} name={r['name']} moment={r['moment']} "
                f"applicable={r['applicable']} sum={r['sum']} agent={r['agent_name']}"
            )

    out_path = os.path.join(HERE, "step3_missing_from_oracle.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(missing_by_date, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
