#!/usr/bin/env python3
"""How well documented are the huts the app shows, and which ones are worth
filling in by hand first? It only READS Supabase (the public anon key the app
already uses) and WRITES files in tools/out/:

  content_report.txt   coverage numbers for the active huts
  featured_huts.sql    the best documented huts as a ready "featured" update
                       (review it, then paste it in the Supabase SQL editor)
  fill_in.csv          the best candidates that are still missing price, hours,
                       phone, website or facilities: fill the empty cells with
                       REAL information (the hut's own site or phone call), then
                       run tools/fill_in_to_sql.py on it

    python3 tools/content_report.py                  # France
    python3 tools/content_report.py --country Italy
    python3 tools/content_report.py --top 100
"""
import argparse, csv, json, os, re, urllib.parse, urllib.request

SUPABASE = "https://uusmhcptszjqgmeaoocl.supabase.co/rest/v1"
FIELDS = "id,name,region,country,altitude_m,beds_total,description,phone,email,website,booking_url,opening_hours,facilities,listing_status,price_per_night,featured"


def anon_key():
    swift = os.path.join(os.path.dirname(__file__), "..", "Podz", "Auth", "SupabaseClient.swift")
    return re.search(r'anonKey = "([^"]+)"', open(swift).read()).group(1)


def get(path):
    key, out, offset = anon_key(), [], 0
    while True:
        req = urllib.request.Request(f"{SUPABASE}/{path}&limit=1000&offset={offset}",
                                     headers={"apikey": key, "Authorization": f"Bearer {key}"})
        page = json.load(urllib.request.urlopen(req))
        out += page
        offset += 1000
        if len(page) < 1000:
            return out


def score(p, has_photo):
    s = 0
    s += 3 if has_photo else 0
    s += 2 if any(p.get(k) for k in ("phone", "email", "website", "booking_url")) else 0
    s += 1 if p.get("altitude_m") else 0
    s += 1 if p.get("beds_total") else 0
    s += 1 if p.get("facilities") else 0
    s += 1 if (p.get("description") or "").strip() else 0
    s += 1 if (p.get("opening_hours") or p.get("price_per_night")) else 0
    return s


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--country", default="France")
    ap.add_argument("--top", type=int, default=100)
    args = ap.parse_args()

    country = urllib.parse.quote(args.country)
    try:
        pods = get(f"pods?select={FIELDS}&is_active=eq.true&country=eq.{country}&order=id")
    except urllib.error.HTTPError:
        # SQL/featured_huts.sql hasn't been run yet: no "featured" column.
        pods = get(f"pods?select={FIELDS.replace(',featured', '')}&is_active=eq.true&country=eq.{country}&order=id")
    photos = {r["pod_id"] for r in get("pod_photos?select=pod_id,pods!inner(is_active,country)&pods.is_active=eq.true"
                                       f"&pods.country=eq.{country}&position=eq.0&order=pod_id")}
    os.makedirs("tools/out", exist_ok=True)

    def count(label, fn):
        n = sum(1 for p in pods if fn(p))
        return f"{label:<28}{n:>5}  ({100 * n // max(len(pods), 1)}%)"

    lines = [f"{len(pods)} active huts in {args.country}", "",
             count("with a photo", lambda p: p["id"] in photos),
             count("with a phone", lambda p: p.get("phone")),
             count("with a website", lambda p: p.get("website") or p.get("booking_url")),
             count("with any contact", lambda p: any(p.get(k) for k in ("phone", "email", "website", "booking_url"))),
             count("with opening hours", lambda p: p.get("opening_hours")),
             count("with facilities", lambda p: p.get("facilities")),
             count("with a price", lambda p: p.get("price_per_night")),
             count("with altitude", lambda p: p.get("altitude_m")),
             count("with beds", lambda p: p.get("beds_total")),
             count("with a description", lambda p: (p.get("description") or "").strip()),
             count("hand-picked (featured)", lambda p: p.get("featured")),
             count("shelf-worthy (score >= 5)", lambda p: score(p, p["id"] in photos) >= 5)]
    open("tools/out/content_report.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))

    ranked = sorted(pods, key=lambda p: (-score(p, p["id"] in photos), p["name"]))
    top = [p for p in ranked if not p.get("featured")][: args.top]
    with open("tools/out/featured_huts.sql", "w") as f:
        f.write(f"-- The {len(top)} best documented huts in {args.country}. Review, then run.\n")
        f.write("update pods set featured = true where id in (\n")
        rows = [f"    '{p['id']}'{',' if i < len(top) - 1 else ' '}  -- {p['name']}" for i, p in enumerate(top)]
        f.write("\n".join(rows) + "\n);\n")
    wanted = ("price_per_night", "opening_hours", "phone", "website", "facilities")
    todo = [p for p in ranked if any(not p.get(k) for k in wanted)][: args.top + 50]
    with open("tools/out/fill_in.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "name", "region", "missing", "price_per_night", "phone", "website", "opening_hours", "facilities (; separated)"])
        for p in todo:
            missing = ", ".join(k for k in wanted if not p.get(k))
            w.writerow([p["id"], p["name"], p.get("region") or "", missing, "", "", "", "", ""])
    print(f"\nwritten: tools/out/content_report.txt, featured_huts.sql ({len(top)} huts), fill_in.csv ({len(todo)} huts)")


if __name__ == "__main__":
    main()
