#!/bin/bash
# fix-variants-and-assign.sh
# 1. Creates a variant for every product that has none
# 2. Assigns products to their collections
# Run: bash fix-variants-and-assign.sh

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

# ── 1. Get all products ────────────────────────────────────────────────────
print("📦 Fetching all products...")
prod_data = gql("{ products(options:{take:200}) { items { id name slug variants { id } } } }")
all_products = prod_data["products"]["items"]
print(f"  Total products: {len(all_products)}")

no_variants = [p for p in all_products if len(p["variants"]) == 0]
print(f"  Products missing variants: {len(no_variants)}")

# ── 2. Price map by slug keyword ───────────────────────────────────────────
PRICES = {
    "sony": 29999, "samsung": 89999, "apple": 109900, "jbl": 14999,
    "levis": 6999, "nike": 15000, "adidas": 18000, "zara": 8999,
    "yamaha": 24999, "roland": 89999, "fender": 149999,
    "photography": 4999, "web-dev": 8999, "digital-marketing": 6999,
    "ceramic": 3499, "moroccan": 2999, "minimalist": 4999,
    "egyptian": 12999, "memory-foam": 4999, "bamboo": 6999,
    "ethiopian": 1899, "nespresso": 19999, "cold-brew": 3499,
    "le-creuset": 34999, "cuisinart": 24999, "cast-iron": 8999,
    "smeg": 12999, "delonghi": 8999,
    "diamond": 149999, "pearl": 8999, "gold-vermeil": 5999,
    "italian-leather": 24999, "leather-crossbody": 12999,
    "braun": 39999, "dyson": 49999,
    "wilson": 19999, "spalding": 15999, "adidas-running": 5999,
    "bugaboo": 99999, "graco": 34999,
    "lego": 44999, "barbie": 19999, "hot-wheels": 4999,
    "quaker": 2499, "kelloggs": 999, "organic-muesli": 1799,
    "modular": 1500000, "garden-cabin": 850000,
    "lifepo4": 89999, "agm": 24999, "solar-panel": 34999,
    "bodaboda": 150000, "tuk": 200000,
}

def get_price(slug):
    slug_lower = slug.lower()
    for key, price in PRICES.items():
        if key in slug_lower:
            return price
    return 9999  # default

# ── 3. Create missing variants ─────────────────────────────────────────────
print("\n🔧 Creating missing variants...")
created = 0
for p in no_variants:
    pid = p["id"]
    name = p["name"]
    slug = p["slug"]
    base_slug = re.sub(r"-\d+$", "", slug)
    price = get_price(base_slug)
    sku = f"SKU-{base_slug.upper()[:20]}"

    try:
        r = gql(f'''mutation {{
          createProductVariants(input: [{{
            productId: "{pid}"
            sku: "{sku}"
            price: {price}
            stockOnHand: 50
            trackInventory: FALSE
            translations: [{{ languageCode: en, name: "{name}" }}]
          }}]) {{ id name price }}
        }}''')
        variant = r["createProductVariants"][0]
        print(f"  ✅ {name[:45]:<45} → variant id:{variant['id']} price:{variant['price']}")
        created += 1
    except Exception as e:
        print(f"  ❌ {name}: {e}")

print(f"\n  Created {created} variants")

# ── 4. Re-fetch products with variant IDs ─────────────────────────────────
print("\n📦 Re-fetching products with variants...")
prod_data = gql("{ products(options:{take:200}) { items { id name slug variants { id } } } }")
all_products = prod_data["products"]["items"]

# Build base-slug → product id map (pick lowest id for duplicates)
products = {}
for p in all_products:
    if not p["variants"]:
        continue  # skip still-broken ones
    base = re.sub(r"-\d+$", "", p["slug"])
    pid = int(p["id"])
    if base not in products or pid < int(products[base]["id"]):
        products[base] = {"id": p["id"], "variantId": p["variants"][0]["id"]}

print(f"  Products with variants: {len(products)}")

# ── 5. Collection mapping ──────────────────────────────────────────────────
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

# ── 6. Fetch collections ───────────────────────────────────────────────────
col_data = gql("{ collections(options:{take:100}) { items { id name slug } } }")
collections = {c["slug"]: c["id"] for c in col_data["collections"]["items"]}

# ── 7. Assign via variant-id-filter (most reliable) ───────────────────────
print("\n🔗 Assigning to collections via variant-id-filter...")
ok = 0
warn = 0

for col_slug, prod_slugs in MAPPING.items():
    col_id = collections.get(col_slug)
    if not col_id:
        print(f"  ⚠️  Collection not found: {col_slug}")
        warn += 1
        continue

    variant_ids = []
    for slug in prod_slugs:
        p = products.get(slug)
        if p:
            variant_ids.append(p["variantId"])
        else:
            # fuzzy match
            match = next((v for k, v in products.items() if slug in k or k in slug), None)
            if match:
                variant_ids.append(match["variantId"])
            else:
                print(f"  ⚠️  Not found: {slug}")
                warn += 1

    if not variant_ids:
        continue

    ids_value = json.dumps([str(i) for i in variant_ids])

    try:
        r = gql(f'''mutation {{
          updateCollection(input: {{
            id: "{col_id}"
            filters: [{{
              code: "variant-id-filter"
              arguments: [
                {{ name: "variantIds",     value: {json.dumps(ids_value)} }}
                {{ name: "combineWithAnd", value: "false" }}
              ]
            }}]
          }}) {{
            id name
            productVariants {{ totalItems }}
          }}
        }}''')
        count = r["updateCollection"]["productVariants"]["totalItems"]
        print(f"  ✅ {col_slug:<22} — {count} variants")
        ok += 1
    except Exception as e:
        print(f"  ❌ {col_slug}: {e}")
        warn += 1

print(f"\n{'='*50}")
print(f"✅ {ok} collections updated, ⚠️  {warn} issues")
print("\n🎉 Done! Refresh http://localhost:3001")
PYEOF
