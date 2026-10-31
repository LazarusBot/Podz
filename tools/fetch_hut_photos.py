#!/usr/bin/env python3
"""Finds one photo for each listed hut on Wikimedia Commons and writes SQL that
attaches it. It only READS (your pods through the public API, and Wikimedia)
and WRITES files; nothing touches your database until you run them yourself.

    python3 tools/fetch_hut_photos.py --country Slovenia      # a first try
    python3 tools/fetch_hut_photos.py                         # every listed hut without a photo

Then run SQL/pod_photo_credits.sql once, and paste the files of
tools/out/photos/ (400 huts each) into the Supabase SQL editor.

How a photo is chosen: Commons images geotagged within 800 m of the hut, or
found by searching the hut's name (within 5 km when they are geotagged), whose
file name shares a distinctive word with the hut's name; JPEG,
at least 600 px wide, under a free licence (CC BY, CC BY-SA, CC0, public
domain); maps, logos and diagrams are skipped. The app shows the credit with
the photo. Huts with no match keep the placeholder.
"""
import argparse, html, json, os, re, sys, threading, time, unicodedata, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "podz-photos/1.0 (https://github.com/LazarusBot/Podz; hut photo lookup)"}
SUPABASE = "https://uusmhcptszjqgmeaoocl.supabase.co/rest/v1"
SKIP = re.compile(r"\b(map|karte|carte|mappa|logo|plan|diagram|flag|coat|wappen|emblem|schild|sign|poster|panel|screenshot|chart|route|track|gpx|profile|church|chapel|kirche|kapelle|cerkev|chiesa|eglise|cross|kreuz|grave|monument|memorial|bust|cemetery|friedhof|sunset|sunrise)\b", re.I)
FREE = re.compile(r"^(CC[ -]BY(-SA)?|CC0|Public domain|PD)", re.I)
lock = threading.Lock()


def get(url, params=None, headers=None, retries=4):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers or UA), timeout=40) as r:
                return json.load(r)
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return None


def anon_key():
    path = os.path.join(os.path.dirname(__file__), "..", "Podz", "Auth", "SupabaseClient.swift")
    return re.search(r'eyJ[\w.-]+', open(path).read()).group(0)


def listed_pods_without_photo(country):
    key = anon_key()
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}
    pods, offset = [], 0
    while True:
        q = {"select": "id,name,country,latitude,longitude,source_id", "listing_status": "eq.listed",
             "order": "id", "limit": 1000, "offset": offset}
        if country:
            q["country"] = f"eq.{country}"
        page = get(f"{SUPABASE}/pods", q, headers) or []
        pods += page
        if len(page) < 1000:
            break
        offset += 1000
    have = set()
    offset = 0
    while True:
        page = get(f"{SUPABASE}/pod_photos", {"select": "pod_id", "limit": 1000, "offset": offset}, headers) or []
        have |= {p["pod_id"] for p in page}
        if len(page) < 1000:
            break
        offset += 1000
    return [p for p in pods if p["id"] not in have and p["latitude"] is not None and p["source_id"]]


def words(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    stop = {"rifugio", "refuge", "hutte", "huette", "cabane", "capanna", "bivacco", "bivouac", "koca", "alpine", "hut", "haus", "berghaus", "chalet", "schutzhutte",
            "dom", "planina", "planinski", "brunarica", "planinska", "alm", "alpe", "hotel", "gasthof", "berggasthof", "malga", "baita", "bivak", "cabana", "gite", "auberge", "sektion", "alpenverein", "section", "club", "alpino", "italiano", "pod"}
    return {w for w in re.findall(r"[a-z]{4,}", text) if w not in stop}


def candidates(pod):
    """Commons files near the hut, best first: [(title, distance)]."""
    data = get(API, {"action": "query", "list": "geosearch", "gscoord": f"{pod['latitude']}|{pod['longitude']}",
                     "gsradius": 800, "gslimit": 30, "gsnamespace": 6, "format": "json"})
    found = (data or {}).get("query", {}).get("geosearch", [])
    mine = words(pod["name"])
    scored = []
    for f in found:
        title = f["title"]
        if not re.search(r"\.jpe?g$", title, re.I) or SKIP.search(title):
            continue
        # The file's name must share a distinctive word with the hut's: a photo
        # that merely lies nearby is as often a church or a view.
        if mine & words(title):
            scored.append((0, f["dist"], title))
    return [(t, d) for _, d, t in sorted(scored)][:3]


def by_name(pod):
    """Files whose name mentions the hut, for photos nobody geotagged. Needs a
    word of the hut's name in the title and, when the file has coordinates, to
    be within 5 km of the hut."""
    mine = words(pod["name"])
    if not mine:
        return []
    data = get(API, {"action": "query", "generator": "search", "gsrsearch": f'{pod["name"]}', "gsrnamespace": 6,
                     "gsrlimit": 8, "prop": "coordinates", "format": "json"})
    out = []
    for page in ((data or {}).get("query", {}).get("pages", {})).values():
        title = page["title"]
        if not re.search(r"\.jpe?g$", title, re.I) or SKIP.search(title):
            continue
        if not (mine & words(title)):
            continue
        coord = (page.get("coordinates") or [None])[0]
        if coord and distance_km(pod["latitude"], pod["longitude"], coord["lat"], coord["lon"]) > 5:
            continue
        out.append((title, 9999))
    return out[:3]


def distance_km(lat1, lon1, lat2, lon2):
    import math
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    return 6371 * 2 * math.asin(math.sqrt(a))


def info(titles):
    out = {}
    for i in range(0, len(titles), 40):
        data = get(API, {"action": "query", "titles": "|".join(titles[i:i + 40]), "prop": "imageinfo",
                         "iiprop": "url|size|extmetadata", "iiurlwidth": 1200, "format": "json"})
        for page in (data or {}).get("query", {}).get("pages", {}).values():
            ii = (page.get("imageinfo") or [None])[0]
            if ii:
                out[page["title"]] = ii
    return out


def credit(ii):
    meta = ii.get("extmetadata", {})
    licence = (meta.get("LicenseShortName") or {}).get("value", "")
    if not FREE.match(licence):
        return None
    artist = re.sub(r"<[^>]+>", "", html.unescape((meta.get("Artist") or {}).get("value", ""))).strip()
    artist = re.sub(r"\s+", " ", artist)[:80] or "Unknown author"
    return f"{artist}, {licence}, Wikimedia Commons"


def sql(value):
    return "'" + re.sub(r"\s+", " ", str(value)).replace("'", "''") + "'"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--country", help="only this country, as written in the database (e.g. Slovenia)")
    ap.add_argument("--limit", type=int, help="only the first N huts (a quick try)")
    ap.add_argument("--out", default="tools/out/photos")
    args = ap.parse_args()

    pods = listed_pods_without_photo(args.country)
    if args.limit:
        pods = pods[:args.limit]
    print(f"{len(pods)} listed huts without a photo", file=sys.stderr)

    done = [0]
    def work(pod):
        result = candidates(pod) or by_name(pod)
        with lock:
            done[0] += 1
            if done[0] % 200 == 0:
                print(f"  {done[0]}/{len(pods)}", file=sys.stderr)
        return pod, result

    with ThreadPoolExecutor(max_workers=4) as pool:
        looked = list(pool.map(work, pods))

    titles = sorted({t for _, c in looked for t, _ in c})
    infos = info(titles)
    rows = []
    for pod, cands in looked:
        for title, _ in cands:
            ii = infos.get(title)
            if not ii or ii.get("width", 0) < 600:
                continue
            text = credit(ii)
            if text:
                rows.append((pod["source_id"], ii.get("thumburl") or ii["url"], text, ii.get("descriptionurl", "")))
                break

    os.makedirs(args.out, exist_ok=True)
    for old in os.listdir(args.out):
        os.remove(os.path.join(args.out, old))
    for n, i in enumerate(range(0, len(rows), 400), 1):
        with open(os.path.join(args.out, f"photos_{n:02d}.sql"), "w") as f:
            f.write("-- Hut photos from Wikimedia Commons, credited. Run after SQL/pod_photo_credits.sql.\nbegin;\n")
            for source_id, url, text, page in rows[i:i + 400]:
                f.write(f"insert into pod_photos (pod_id, url, position, credit, source_url) select id, {sql(url)}, 0, {sql(text)}, {sql(page)} "
                        f"from pods where source = 'osm' and source_id = {sql(source_id)} "
                        f"and not exists (select 1 from pod_photos p where p.pod_id = pods.id);\n")
            f.write("commit;\n")
    print(f"{len(rows)} of {len(pods)} huts have a photo ({100 * len(rows) // max(len(pods), 1)} %), written to {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
