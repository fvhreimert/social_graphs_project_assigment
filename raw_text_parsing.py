import os
import re
import json

INPUT_DIR = "data/raw_articles_wikitext"
OUTPUT_PATH = "data/parsed_wikitext_data.json"

# --- Regex patterns ---
LINK_PATTERN = re.compile(r"\[\[([^\]|#]+)(?:\|[^\]]+)?\]\]")   # [[Target|Label]] or [[Target]]
CATEGORY_PATTERN = re.compile(r"\[\[Category:([^\]|#]+)")       # [[Category:Something]]
SECTION_PATTERN = re.compile(r"^==+\s*(.*?)\s*==+", re.MULTILINE)

def parse_wikitext(title, text):
    """
    Parse a single wikitext article into structured fields:
    links, categories, section titles, full text.
    """

    # --- Extract categories ---
    categories = CATEGORY_PATTERN.findall(text)

    # --- Extract links ---
    links = LINK_PATTERN.findall(text)
    # Remove duplicates, ignore File/Image prefixes
    links = list({
        link.strip()
        for link in links
        if not link.lower().startswith(("file:", "image:", "category:"))
    })

    # --- Extract section titles ---
    sections = SECTION_PATTERN.findall(text)

    # --- Clean categories and sections ---
    categories = [c.strip() for c in categories if c.strip()]
    sections = [s.strip() for s in sections if s.strip()]

    return {
        "title": title,
        "links": links,
        "categories": categories,
        "sections": sections,
        "text": text.strip()
    }


def main():
    parsed_data = []

    files = [f for f in os.listdir(INPUT_DIR) if f.endswith(".txt")]
    total = len(files)
    print(f"Parsing {total} wikitext files...")

    for i, filename in enumerate(files, start=1):
        path = os.path.join(INPUT_DIR, filename)
        with open(path, encoding="utf-8") as f:
            text = f.read()

        title = filename.replace(".txt", "")
        parsed = parse_wikitext(title, text)
        parsed_data.append(parsed)

        if i % 50 == 0 or i == total:
            print(f"[{i}/{total}] Processed {filename}")

    # --- Save consolidated JSON ---
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(parsed_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Done. Saved parsed data to: {OUTPUT_PATH}")
    print(f"Entries parsed: {len(parsed_data)}")

main()