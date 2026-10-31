#!/usr/bin/env python3
"""Builds a SQL file that loads the huts of OpenStreetMap as *listed* pods
(information only: "book through the hut"). It only READS OpenStreetMap and
WRITES a file; nothing touches your database until you run that file yourself.

    python3 tools/import_osm_huts.py                    # the Alps and friends
    python3 tools/import_osm_huts.py --country FR IT    # only some countries
    python3 tools/import_osm_huts.py --bbox 45.7,6.7,46.0,7.1   # a test box

Then paste tools/out/listed_huts.sql into the Supabase SQL editor (after
SQL/listed_huts.sql). Running it again is safe: rows are keyed by (source,
source_id), so existing ones are updated, not duplicated.

Data: (c) OpenStreetMap contributors, ODbL. The app shows the credit.
Only objects tagged tourism=alpine_hut or tourism=wilderness_hut are taken.
"""
import argparse, json, os, re, sys, urllib.parse, urllib.request

ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
COUNTRIES = {
    "FR": "France", "IT": "Italy", "CH": "Switzerland", "AT": "Austria",
    "DE": "Germany", "SI": "Slovenia", "ES": "Spain", "AD": "Andorra",
    "LI": "Liechtenstein", "NO": "Norway", "SE": "Sweden",
}


def query(area_filter: str) -> str:
    return f"""[out:json][timeout:180];
(
  node["tourism"~"^(alpine_hut|wilderness_hut)$"]{area_filter};
  way["tourism"~"^(alpine_hut|wilderness_hut)$"]{area_filter};
);
out center tags;"""


def fetch(q: str) -> list:
    """Asks the public Overpass servers in turn (they are often busy), twice each."""
    import time
    data = urllib.parse.urlencode({"data": q}).encode()
    last = None
    for attempt in range(2):
        for endpoint in ENDPOINTS:
            try:
                req = urllib.request.Request(endpoint, data=data, headers={"User-Agent": "podz-import/1.0"})
                with urllib.request.urlopen(req, timeout=240) as response:
                    return json.load(response)["elements"]
            except Exception as error:  # busy server, timeout: try the next one
                last = error
                print(f"  {endpoint}: {error}", file=sys.stderr)
        time.sleep(8)
    raise SystemExit(f"Overpass isn't answering: {last}")


def sql(value):
    if value is None or value == "":
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def number(value):
    m = re.match(r"\s*(-?\d+(?:[.,]\d+)?)", value or "")
    return float(m.group(1).replace(",", ".")) if m else None


def row(element, country):
    tags = element.get("tags", {})
    name = tags.get("name") or tags.get("name:en")
    if not name:
        return None
    lat = element.get("lat") or element.get("center", {}).get("lat")
    lon = element.get("lon") or element.get("center", {}).get("lon")
    if lat is None or lon is None:
        return None
    ele = number(tags.get("ele"))
    altitude = int(ele) if ele and 0 < ele < 6000 else None   # a hut above 6,000 m is a typo
    beds = number(tags.get("beds") or tags.get("capacity"))
    beds = int(beds) if beds and 0 < beds < 500 else None
    street = " ".join(filter(None, [tags.get("addr:housenumber"), tags.get("addr:street")]))
    address = ", ".join(filter(None, [street, tags.get("addr:postcode"), tags.get("addr:city")])) or None
    phone = tags.get("phone") or tags.get("contact:phone")
    email = tags.get("email") or tags.get("contact:email")
    website = tags.get("website") or tags.get("contact:website") or tags.get("url")
    kind = "Bivouac" if tags.get("tourism") == "wilderness_hut" else "Refuge"
    return {
        "name": name, "pod_type": kind, "country": country,
        "region": tags.get("is_in") or tags.get("addr:state") or None,
        "address": address, "latitude": lat, "longitude": lon,
        "altitude_m": altitude, "beds_total": beds,
        "description": tags.get("description:en") or tags.get("description"),
        "phone": phone, "email": email, "website": website,
        "booking_url": tags.get("reservation:website") or tags.get("website:booking"),
        "opening_hours": tags.get("opening_hours") or tags.get("seasonal"),
        "source": "osm", "source_id": f"{element['type']}/{element['id']}",
    }


COLUMNS = ["name", "pod_type", "country", "region", "address", "latitude", "longitude",
           "altitude_m", "beds_total", "description", "phone", "email", "website",
           "booking_url", "opening_hours", "source", "source_id"]


def statement(r):
    values = ", ".join(sql(r[c]) if isinstance(r[c], str) or r[c] is None else str(r[c]) for c in COLUMNS)
    updates = ", ".join(f"{c} = excluded.{c}" for c in COLUMNS if c not in ("source", "source_id"))
    return (f"insert into pods ({', '.join(COLUMNS)}, listing_status) values ({values}, 'listed') "
            f"on conflict (source, source_id) where source is not null do update set {updates};")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--country", nargs="*", help="ISO codes, e.g. FR IT CH (default: the Alps)")
    ap.add_argument("--bbox", help="south,west,north,east: a test box instead of countries")
    ap.add_argument("--out", default="tools/out/listed_huts.sql")
    args = ap.parse_args()

    jobs = []
    if args.bbox:
        jobs.append(("Test box", f"({args.bbox})"))
    else:
        for code in args.country or ["FR", "IT", "CH", "AT", "DE", "SI"]:
            jobs.append((COUNTRIES[code], None))

    rows, seen = [], set()
    for country, bbox in jobs:
        if bbox:
            area, label = bbox, "Europe"
            elements = fetch(query(area))
        else:
            code = next(k for k, v in COUNTRIES.items() if v == country)
            elements = fetch(f'[out:json][timeout:180];area["ISO3166-1"="{code}"]->.a;(node["tourism"~"^(alpine_hut|wilderness_hut)$"](area.a);way["tourism"~"^(alpine_hut|wilderness_hut)$"](area.a););out center tags;')
            label = country
        kept = 0
        for element in elements:
            r = row(element, label)
            if r and r["source_id"] not in seen:
                seen.add(r["source_id"]); rows.append(r); kept += 1
        print(f"{label}: {len(elements)} objects, {kept} kept", file=sys.stderr)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        f.write("-- Listed huts from OpenStreetMap (c) contributors, ODbL. Run after SQL/listed_huts.sql.\n")
        f.write("begin;\n")
        for r in rows:
            f.write(statement(r) + "\n")
        f.write("commit;\n")
    contactable = sum(1 for r in rows if r["phone"] or r["email"] or r["website"])
    print(f"{len(rows)} huts written to {args.out} ({contactable} with a phone, email or website)", file=sys.stderr)


if __name__ == "__main__":
    main()
