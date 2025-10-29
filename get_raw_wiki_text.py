import os, time, requests, urllib.parse, json, re

API_URL = "https://en.wikipedia.org/w/api.php"
SAVE_DIR = "data/raw_articles_wikitext"
os.makedirs(SAVE_DIR, exist_ok=True)

# --- Load your Wikidata-derived JSON ---
with open("data/mushroom_data.json", "r", encoding="utf-8") as f:
    data = json.load(f)
print(f"Number of entries in JSON file: {len(data)}")

# Extract titles from article URLs
def extract_title(article_url):
    """Extract the Wikipedia page title from a full URL."""
    return urllib.parse.unquote(article_url.split("/")[-1])

titles = []
for entry in data:
    article_url = entry.get("article")
    if article_url and article_url.startswith("https://en.wikipedia.org/wiki/"):
        titles.append(extract_title(article_url))
    else:
        print(f"⚠️ Skipping invalid or missing article for: {entry.get('mushroom', 'Unknown')}")

# --- User-Agent (Wikipedia requirement) ---
session = requests.Session()
session.headers.update({
    "User-Agent": "DTU-MushroomGraph/1.0 (contact: your.email@example.com)"
})

def get_wikitext(title):
    """Fetch the full wikitext of a Wikipedia page."""
    params = {
        "action": "query",
        "format": "json",
        "formatversion": "2",
        "redirects": "1",
        "prop": "revisions",
        "rvprop": "content",
        "rvslots": "main",
        "titles": title
    }
    r = session.get(API_URL, params=params, timeout=30)
    if r.status_code != 200:
        return None
    js = r.json()
    pages = js.get("query", {}).get("pages", [])
    if not pages or "missing" in pages[0]:
        return None
    return pages[0]["revisions"][0]["slots"]["main"]["content"]

def save_wikitext(title):
    """Download and save the wikitext for a Wikipedia article title."""
    safe = urllib.parse.unquote(title).replace("/", "_")
    path = os.path.join(SAVE_DIR, f"{safe}.txt")

    # Skip if file already exists
    if os.path.exists(path):
        print(f"⏭️  Skipping {title} (already exists)")
        return True

    text = get_wikitext(title)
    if not text:
        print(f"❌ Failed to get {title}")
        return False

    # Remove embedded image/file references
    text = re.sub(r"\[\[(?:File|Image):[^\]]+\]\]", "", text)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

    time.sleep(0.5)  # be polite to the API
    return True

failed = []
for i, title in enumerate(titles, start=1):
    ok = save_wikitext(title)
    status = "Saved" if ok else "Failed"
    print(f"[{i}/{len(titles)}] {status} {title}")
    if not ok:
        failed.append(title)

if failed:
    os.makedirs("data", exist_ok=True)
    with open("data/failed_wikitext.json", "w", encoding="utf-8") as f:
        json.dump(failed, f, indent=2)
    print(f"Completed with {len(failed)} failures.")
else:
    print("Completed successfully.")