#!/usr/bin/env python3
"""Turns tools/out/fill_in.csv, once you have filled cells with REAL information,
into SQL updates. Only the cells you filled are written; nothing else changes.
Nothing touches your database until you paste the result yourself.

    python3 tools/fill_in_to_sql.py                       # tools/out/fill_in.csv -> tools/out/fill_in.sql

Columns: price_per_night (a number, euros per person per night), phone, website,
opening_hours (OpenStreetMap style, e.g. "Jun-Sep" or "Jul 1-Sep 10"; a season is
what the app can turn into "Open now" / "Closed until June"), facilities
(separated by ;  e.g. "Meals; Showers; Drinking water").
"""
import csv, re, sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "tools/out/fill_in.csv"
DST = sys.argv[2] if len(sys.argv) > 2 else "tools/out/fill_in.sql"


def sql(value):
    return "'" + re.sub(r"\s+", " ", value).strip().replace("'", "''") + "'"


statements = []
with open(SRC, newline="") as f:
    for row in csv.DictReader(f):
        sets = []
        price = row.get("price_per_night", "").strip().replace(",", ".")
        if price:
            float(price)  # fails loudly on a typo
            sets.append(f"price_per_night = {price}")
        for column in ("phone", "website", "opening_hours"):
            if row.get(column, "").strip():
                sets.append(f"{column} = {sql(row[column])}")
        facilities = [x.strip() for x in row.get("facilities (; separated)", "").split(";") if x.strip()]
        if facilities:
            sets.append("facilities = array[" + ", ".join(sql(x) for x in facilities) + "]::text[]")
        if sets:
            statements.append(f"update pods set {', '.join(sets)} where id = '{row['id']}';  -- {row['name']}")

with open(DST, "w") as f:
    f.write("begin;\n" + "\n".join(statements) + "\ncommit;\n")
print(f"{len(statements)} huts written to {DST}")
