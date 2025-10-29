import os
import re
import json

INPUT_DIR = "data/raw_articles_wikitext"
OUTPUT_PATH = "data/parsed_wikitext_data.json"

# --- Regex patterns ---
LINK_PATTERN = re.compile(r"\[\[([^\]|#]+)(?:\|[^\]]+)?\]\]")   # [[Target|Label]] or [[Target]]
CATEGORY_PATTERN = re.compile(r"\[\[Category:([^\]|#]+)")       # [[Category:Something]]
SECTION_PATTERN = re.compile(r"^==+\s*(.*?)\s*==+", re.MULTILINE)

# --- Template patterns ---
SPECIESBOX_PATTERN = re.compile(r"\{\{[Ss]peciesbox\s*(.*?)\n\}\}", re.DOTALL)
MYCOMORPHBOX_PATTERN = re.compile(r"\{\{[Mm]ycomorphbox\s*(.*?)\n\}\}", re.DOTALL)
BOX_PARAM_PATTERN = re.compile(r"\|\s*([^=]+?)\s*=\s*(.+)")

def clean_wikimarkup(value):
    """Remove wiki markup, references, and other clutter."""
    # Remove [[links]] but keep display text
    value = re.sub(r"\[\[(?:[^\]|]+\|)?([^\]]+)\]\]", r"\1", value)
    # Remove <ref> tags and their contents
    value = re.sub(r"<ref[^>]*>.*?</ref>", "", value)
    # Remove HTML comments
    value = re.sub(r"<!--.*?-->", "", value)
    # Remove small/bold/italic markup
    value = re.sub(r"''+([^']+)''+", r"\1", value)
    value = re.sub(r"<small>(.*?)</small>", r"\1", value, flags=re.IGNORECASE)
    # Strip extra whitespace
    return value.strip()

def parse_template_block(pattern, text):
    """Extract key-value pairs from a given template pattern."""
    match = pattern.search(text)
    if not match:
        return None

    content = match.group(1)
    data = {}
    for line in content.split("\n"):
        param_match = BOX_PARAM_PATTERN.match(line)
        if param_match:
            key = param_match.group(1).strip()
            value = param_match.group(2).strip()
            value = clean_wikimarkup(value)
            data[key] = value
    return data if data else None

def parse_wikitext(title, text):
    """
    Parse a single wikitext article into structured fields:
    links, categories, section titles, full text, speciesbox, mycomorphbox.
    """

    # --- Extract categories ---
    categories = CATEGORY_PATTERN.findall(text)

    # --- Extract links ---
    links = LINK_PATTERN.findall(text)
    links = list({
        link.strip()
        for link in links
        if not link.lower().startswith(("file:", "image:", "category:"))
    })

    # --- Extract section titles ---
    sections = SECTION_PATTERN.findall(text)

    # --- Extract species and mycomorph boxes ---
    speciesbox = parse_template_block(SPECIESBOX_PATTERN, text)
    mycomorphbox = parse_template_block(MYCOMORPHBOX_PATTERN, text)

    # --- Clean categories and sections ---
    categories = [c.strip() for c in categories if c.strip()]
    sections = [s.strip() for s in sections if s.strip()]

    return {
        "title": title,
        "links": links,
        "categories": categories,
        "sections": sections,
        "text": text.strip(),
        "speciesbox": speciesbox,
        "mycomorphbox": mycomorphbox
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

if __name__ == "__main__":
    main()
