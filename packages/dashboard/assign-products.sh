#!/bin/bash
# assign-products.sh — creates all collections + assigns products
# Run: bash assign-products.sh

API="http://localhost:3000/admin-api"
COOKIES="/tmp/vendure-session.txt"

echo "🔐 Logging in..."
curl -s -X POST "$API" \
  -H "Content-Type: application/json" \
  -c "$COOKIES" \
  -d '{"query":"mutation { login(username: \"superadmin\", password: \"superadmin\") { ... on CurrentUser { id } } }"}' > /dev/null
echo "✅ Logged in"

python3 - << 'PYEOF'
import subprocess, json, re

API = "http://localhost:3000/admin-api"
COOKIES = "/tmp/vendure-session.txt"

def gql(query):
    result = subprocess.run([
        "curl", "-s", "-X", "POST", API,
        "-H", "Content-Type: application/json",
        "-b", COOKIES,
        "-d", json.dumps({"query": query})
    ], capture_output=True, text=True)
    data = json.loads(result.stdout)
    if data.get("errors"):
        raise Exception(data["errors"][0]["message"])
    return data["data"]

# ── 1. Fetch existing collections ──────────────────────────────────────────
col_data = gql("{ collections(options:{take:100}) { items { id name slug } } }")
collections = {c["slug"]: c["id"] for c in col_data["collections"]["items"]}
print(f"Existing collections ({len(collections)}): {list(collections.keys())}")

# ── 2. Create all missing collections ─────────────────────────────────────
NEEDED = [
    ("Electronics",     "electronics"),
    ("Clothing",        "clothing"),
    ("Music",           "music"),
    ("Courses",         "courses"),
    ("Decor",           "decor"),
    ("Bedding & Bath",  "bedding-bath"),
    ("Coffee",          "coffee"),
    ("Pots & Pans",     "pots-pans"),
    ("Kettles",         "kettles"),
    ("Jewelry",         "jewelry"),
    ("Handbags",        "handbags"),
    ("Grooming",        "grooming"),
    ("Sports",          "sports"),
    ("Strollers",       "strollers"),
    ("Toys",            "toys"),
    ("Cereals",         "cereals"),
    ("Prefab Houses",   "prefab-houses"),
    ("Solar Batteries", "solar-batteries"),
]

print("\n📂 Creating missing collections...")
for name, slug in NEEDED:
    if slug in collections:
        print(f"  ✓  {slug}")
        continue
    try:
        r = gql(f'''mutation {{
          createCollection(input: {{
            isPrivate: false
            filters: []
            translations: [{{
              languageCode: en
              name: "{name}"
              slug: "{slug}"
              description: ""
            }}]
          }}) {{ id slug }}
        }}''')
        new_id = r["createCollection"]["id"]
        collections[slug] = new_id
        print(f"  ✅ Created: {name} (id:{new_id})")
    except Exception as e:
        print(f"  ❌ Failed {slug}: {e}")

# ── 3. Fetch all products ──────────────────────────────────────────────────
prod_data = gql("{ products(options:{take:200}) { items { id name slug } } }")
products_raw = prod_data["products"]["items"]

# Strip trailing -2, -3 suffixes (duplicates from multiple populate runs)
# Keep the one with the LOWEST numeric id
products = {}
for p in products_raw:
    base = re.sub(r"-\d+$", "", p["slug"])
    pid = int(p["id"])
    if base not in products or pid < int(products[base]):
        products[base] = p["id"]

print(f"\nProducts mapped: {len(products)}")

# ── 4. Mapping: collection slug → product base slugs ──────────────────────
MAPPING = {
    "electronics":     ["sony-wh-1000xm5", "samsung-65-qled-tv", "apple-ipad-pro-129", "jbl-bluetooth-speaker"],
    "clothing":        ["levis-501-jeans", "nike-air-max-270", "adidas-ultraboost-22", "zara-linen-blazer"],
    "music":           ["yamaha-acoustic-guitar", "roland-electronic-drum-kit", "fender-stratocaster"],
    "courses":         ["photography-course", "web-dev-bootcamp", "digital-marketing-course"],
    "decor":           ["ceramic-vase", "moroccan-pillows", "minimalist-wall-clock"],
    "bedding-bath":    ["egyptian-cotton-duvet", "memory-foam-pillow", "bamboo-bath-towels"],
    "coffee":          ["ethiopian-coffee", "nespresso-vertuo", "cold-brew-kit"],
    "pots-pans":       ["le-creuset-dutch-oven", "cuisinart-cookware-set", "cast-iron-skillet"],
    "kettles":         ["smeg-retro-kettle", "delonghi-scultura-kettle"],
    "jewelry":         ["diamond-tennis-bracelet", "pearl-drop-earrings", "gold-vermeil-necklace"],
    "handbags":        ["italian-leather-tote", "leather-crossbody-bag"],
    "grooming":        ["braun-series-9", "dyson-supersonic"],
    "sports":          ["wilson-tennis-racket", "spalding-nba-basketball", "adidas-running-backpack"],
    "strollers":       ["bugaboo-fox-3", "graco-modes-stroller"],
    "toys":            ["lego-bugatti-chiron", "barbie-dreamhouse", "hot-wheels-50-pack"],
    "cereals":         ["quaker-oats-granola", "kelloggs-corn-flakes", "organic-muesli"],
    "prefab-houses":   ["modular-studio-unit", "garden-cabin-pod"],
    "solar-batteries": ["lifepo4-200ah", "agm-deep-cycle-100ah", "solar-panel-300w"],
}

# ── 5. Assign via product-id-filter ───────────────────────────────────────
# Vendure expects: value = JSON string of array of ID strings e.g. "[\"1\",\"2\"]"
print("\n🔗 Assigning products to collections...")
ok = 0
warn = 0

for col_slug, prod_slugs in MAPPING.items():
    col_id = collections.get(col_slug)
    if not col_id:
        print(f"  ⚠️  Collection missing: {col_slug}")
        warn += 1
        continue

    resolved = []
    for slug in prod_slugs:
        pid = products.get(slug)
        if pid:
            resolved.append(pid)
        else:
            print(f"  ⚠️  Product not found: {slug}")
            warn += 1

    if not resolved:
        continue

    # Value must be a JSON string of an array of string IDs
    ids_value = json.dumps([str(i) for i in resolved])  # e.g. '["1","2","3"]'

    try:
        r = gql(f'''mutation {{
          updateCollection(input: {{
            id: "{col_id}"
            filters: [{{
              code: "product-id-filter"
              arguments: [
                {{ name: "productIds",     value: {json.dumps(ids_value)} }}
                {{ name: "combineWithAnd", value: "false" }}
              ]
            }}]
          }}) {{
            id
            name
            productVariants {{ totalItems }}
          }}
        }}''')
        count = r["updateCollection"]["productVariants"]["totalItems"]
        print(f"  ✅ {col_slug:20s} — {len(resolved)} products → {count} variants")
        ok += 1
    except Exception as e:
        print(f"  ❌ {col_slug}: {e}")
        warn += 1

print(f"\n{'='*50}")
print(f"✅ {ok} collections updated, ⚠️  {warn} issues")
print("\nRefresh http://localhost:3001 to see products in collections!")
PYEOF
