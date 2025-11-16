import requests
import json
import time

# SPARQL endpoint
ENDPOINT = "https://query.wikidata.org/sparql"

# Base SPARQL query template
SPARQL_QUERY = """
SELECT ?mushroom ?mushroomLabel ?mushroomDescription ?article ?image ?taxonName
       ?hymeniumTypeLabel ?capShapeLabel ?hymeniumAttachmentLabel ?stipeCharacterLabel
       ?sporePrintColorLabel ?ecologicalTypeLabel ?edibilityLabel
       ?taxonRankLabel ?instanceOfLabel ?parentTaxonLabel ?taxonAuthorLabel
WHERE {
  ?mushroom wdt:P31 wd:Q764.  # instance of mushroom

  OPTIONAL { ?mushroom wdt:P18 ?image. }
  OPTIONAL { ?mushroom wdt:P225 ?taxonName. }
  OPTIONAL { ?mushroom wdt:P7963 ?hymeniumType. }
  OPTIONAL { ?mushroom wdt:P7870 ?capShape. }
  OPTIONAL { ?mushroom wdt:P7871 ?hymeniumAttachment. }
  OPTIONAL { ?mushroom wdt:P7872 ?stipeCharacter. }
  OPTIONAL { ?mushroom wdt:P7873 ?sporePrintColor. }
  OPTIONAL { ?mushroom wdt:P7874 ?ecologicalType. }
  OPTIONAL { ?mushroom wdt:P6621 ?edibility. }
  OPTIONAL { ?mushroom wdt:P105 ?taxonRank. }
  OPTIONAL { ?mushroom wdt:P31 ?instanceOf. }
  OPTIONAL { ?mushroom wdt:P171 ?parentTaxon. }
  OPTIONAL { ?mushroom wdt:P405 ?taxonAuthor. }

  OPTIONAL {
    ?article schema:about ?mushroom ;
             schema:isPartOf <https://en.wikipedia.org/> .
  }

  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT {limit}
OFFSET {offset}
"""

# Parameters
LIMIT = 5          # max rows per query
MAX_ATTEMPTS = 2     # retry attempts for failed requests
OUTPUT_FILE = "mushrooms.json"


def run_query(offset):
    """Run one SPARQL query batch."""
    query = SPARQL_QUERY.format(limit=LIMIT, offset=offset)
    headers = {"Accept": "application/sparql-results+json"}
    for attempt in range(MAX_ATTEMPTS):
        try:
            resp = requests.get(ENDPOINT, params={"query": query}, headers=headers, timeout=60)
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            print(f"Error on offset {offset}, attempt {attempt+1}: {e}")
            time.sleep(3)
    print(f"Failed permanently at offset {offset}")
    return None


def main():
    all_data = []
    offset = 0

    print("Fetching mushroom data from Wikidata...")
    while True:
        print(f"→ Querying batch starting at offset {offset}...")
        data = run_query(offset)
        if not data:
            break

        bindings = data.get("results", {}).get("bindings", [])
        if not bindings:
            print("No more results.")
            break

        # Convert to simple dicts
        for row in bindings:
            item = {k: v["value"] for k, v in row.items()}
            all_data.append(item)

        print(f"   Retrieved {len(bindings)} rows (total {len(all_data)})")

        # Stop if less than limit — end of dataset
        if len(bindings) < LIMIT:
            break

        offset += LIMIT
        time.sleep(1)  # be polite to the API

    # Save JSON
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Done! Saved {len(all_data)} mushroom entries to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
