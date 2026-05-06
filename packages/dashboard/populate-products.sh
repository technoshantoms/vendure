#!/bin/bash
#--- bash populate-products.sh 
# populate-products.sh
# Run from your Mac terminal: bash populate-products.sh
# Make sure Vendure is running on port 3000 first

API="http://localhost:3000/admin-api"
COOKIES="/tmp/vendure-session.txt"

echo "🔐 Logging in..."
curl -s -X POST "$API" \
  -H "Content-Type: application/json" \
  -c "$COOKIES" \
  -d '{"query":"mutation { login(username: \"superadmin\", password: \"superadmin\") { ... on CurrentUser { id } } }"}' > /dev/null
echo "✅ Logged in"

create_product() {
  local NAME="$1"
  local SLUG="$2"
  local DESC="$3"
  local PRICE="$4"   # in cents

  RESULT=$(curl -s -X POST "$API" \
    -H "Content-Type: application/json" \
    -b "$COOKIES" \
    -d "{\"query\":\"mutation { createProduct(input: { translations: [{ languageCode: en, name: \\\"$NAME\\\", slug: \\\"$SLUG\\\", description: \\\"$DESC\\\" }] }) { id name } }\"}")

  PRODUCT_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['createProduct']['id'])" 2>/dev/null)

  if [ -z "$PRODUCT_ID" ]; then
    echo "❌ Failed to create: $NAME"
    echo "$RESULT"
    return
  fi

  # Create variant
  curl -s -X POST "$API" \
    -H "Content-Type: application/json" \
    -b "$COOKIES" \
    -d "{\"query\":\"mutation { createProductVariants(input: [{ productId: \\\"$PRODUCT_ID\\\", translations: [{ languageCode: en, name: \\\"$NAME\\\" }], sku: \\\"$SLUG\\\", price: $PRICE, stockOnHand: 50, trackInventory: false }]) { id name price } }\"}" > /dev/null

  echo "✅ Created: $NAME (id: $PRODUCT_ID)"
}

echo ""
echo "📦 Creating products..."

# Electronics
create_product "Sony WH-1000XM5 Headphones" "sony-wh-1000xm5" "Industry-leading noise cancellation with 30-hour battery life. Premium wireless headphones." "29999"
create_product "Samsung 65in 4K QLED TV" "samsung-65-qled-tv" "Quantum Dot technology for brilliant color. 4K UHD smart TV with built-in voice assistant." "89999"
create_product "Apple iPad Pro 12.9in" "apple-ipad-pro-129" "The ultimate iPad with M2 chip and Liquid Retina XDR display with ProMotion technology." "109900"
create_product "JBL Bluetooth Speaker" "jbl-bluetooth-speaker" "360-degree sound with powerful bass. Waterproof IPX7 rating. 24-hour battery life." "14999"

# Clothing
create_product "Levis 501 Original Jeans" "levis-501-jeans" "The original blue jean since 1873. Straight fit with button fly. Premium denim fabric." "6999"
create_product "Nike Air Max 270" "nike-air-max-270" "Large Air unit with lightweight foam for all-day comfort. Fresh modern design." "15000"
create_product "Adidas Ultraboost 22" "adidas-ultraboost-22" "Responsive Boost cushioning. Primeknit upper for a snug fit. Ideal for running." "18000"
create_product "Zara Linen Blazer" "zara-linen-blazer" "Relaxed fit linen blazer. Breathable summer fabric. Notch lapel with two front pockets." "8999"

# Music
create_product "Yamaha Acoustic Guitar" "yamaha-acoustic-guitar" "Perfect for beginners and intermediate players. Spruce top with nato back and sides." "24999"
create_product "Roland Electronic Drum Kit" "roland-electronic-drum-kit" "Professional-grade electronic drums with mesh heads for realistic feel." "89999"
create_product "Fender Stratocaster" "fender-stratocaster" "American Performer Series. Alder body with maple neck. Vintage-style tuning machines." "149999"

# Courses
create_product "Online Photography Course" "photography-course" "Master DSLR and mirrorless photography. 12 hours of HD video covering composition and lighting." "4999"
create_product "Web Development Bootcamp" "web-dev-bootcamp" "Full-stack web development. HTML, CSS, JavaScript, React, Node.js. Lifetime access." "8999"
create_product "Digital Marketing Masterclass" "digital-marketing-course" "SEO, social media, email marketing and paid ads. Practical projects included." "6999"

# Décor
create_product "Handcrafted Ceramic Vase" "ceramic-vase" "Artisan-made ceramic vase with matte finish. Each piece is unique. Perfect for flowers." "3499"
create_product "Moroccan Throw Pillow Set" "moroccan-pillows" "Set of 2 hand-embroidered throw pillows. Vibrant geometric patterns. 45x45cm cotton." "2999"
create_product "Minimalist Wall Clock" "minimalist-wall-clock" "Silent quartz movement. 30cm diameter. Matte black frame with white dial." "4999"

# Bedding & Bath
create_product "Egyptian Cotton Duvet Set" "egyptian-cotton-duvet" "1000 thread count Egyptian cotton. King size duvet cover with 2 pillowcases. Hypoallergenic." "12999"
create_product "Memory Foam Pillow" "memory-foam-pillow" "Ergonomic design adapting to neck and head. Cooling gel layer for temperature regulation." "4999"
create_product "Bamboo Bath Towel Set" "bamboo-bath-towels" "Set of 4 ultra-soft bamboo towels. Antibacterial and hypoallergenic. 600gsm weight." "6999"

# Coffee
create_product "Ethiopian Single Origin Coffee" "ethiopian-coffee" "Light roast with notes of blueberry and jasmine. Sourced from Yirgacheffe region. 250g." "1899"
create_product "Nespresso Vertuo Coffee Machine" "nespresso-vertuo" "Centrifusion technology for perfect extraction. 5 cup sizes. Fast 30 second heat up." "19999"
create_product "Cold Brew Coffee Kit" "cold-brew-kit" "Everything needed for smooth cold brew at home. 1L mason jar with stainless steel filter." "3499"

# Pots & Pans
create_product "Le Creuset Dutch Oven 28cm" "le-creuset-dutch-oven" "Enameled cast iron for superior heat retention. Suitable for all heat sources including induction." "34999"
create_product "Cuisinart 12-Piece Cookware Set" "cuisinart-cookware-set" "Hard-anodized aluminum with stainless steel handles. Oven safe to 350F." "24999"
create_product "Cast Iron Skillet 30cm" "cast-iron-skillet" "Pre-seasoned cast iron. Works on all hobs and open fire. Naturally non-stick with use." "8999"

# Kettles
create_product "Smeg Retro Kettle" "smeg-retro-kettle" "Iconic 50s retro style. 1.7L capacity. Rapid boil technology. Keep warm function." "12999"
create_product "DeLonghi Scultura Kettle" "delonghi-scultura-kettle" "Brushed stainless steel. 1.7L capacity. 360 cordless base. Boil-dry protection." "8999"

# Jewelry
create_product "Diamond Tennis Bracelet" "diamond-tennis-bracelet" "18k white gold with 2.5ct total diamond weight. Classic prong setting. Lobster clasp." "149999"
create_product "Pearl Drop Earrings" "pearl-drop-earrings" "Freshwater cultured pearls. 925 sterling silver. AAA grade 8-9mm pearls. Gift box included." "8999"
create_product "Gold Vermeil Necklace" "gold-vermeil-necklace" "18k gold over sterling silver. 18 inch chain with 2 inch extender. Pendant diameter 12mm." "5999"

# Handbags
create_product "Italian Leather Tote Bag" "italian-leather-tote" "Full grain Italian leather. Reinforced base. Interior zip pocket. 40x30x15cm." "24999"
create_product "Leather Crossbody Bag" "leather-crossbody-bag" "Full grain Italian leather. Adjustable strap. Multiple interior compartments." "12999"

# Grooming
create_product "Braun Series 9 Electric Shaver" "braun-series-9" "5 shaving elements for the closest shave. 60 min runtime. 5-in-1 SmartCare Center." "39999"
create_product "Dyson Supersonic Hair Dryer" "dyson-supersonic" "Fast drying with intelligent heat control. Prevents extreme heat damage. 5 attachments." "49999"

# Sports
create_product "Wilson Pro Staff Tennis Racket" "wilson-tennis-racket" "97 sq inch head. 340g strung weight. 16x19 string pattern. Professional grade." "19999"
create_product "Spalding NBA Basketball" "spalding-nba-basketball" "Official NBA game ball. Full-grain leather. 29.5in circumference. Indoor use." "15999"
create_product "Adidas Running Backpack" "adidas-running-backpack" "20L capacity. Hydration compatible. Reflective details. Mesh back panel for ventilation." "5999"

# Strollers
create_product "Bugaboo Fox 3 Pram" "bugaboo-fox-3" "All-terrain stroller with one-hand fold. Reversible seat. Compatible with all Bugaboo bassinets." "99999"
create_product "Graco Modes Stroller" "graco-modes-stroller" "10 riding modes. One-hand fold. Infant car seat compatible. Extra-large storage basket." "34999"

# Toys
create_product "LEGO Technic Bugatti Chiron" "lego-bugatti-chiron" "3599 pieces. Fully detailed W16 engine. Working 8-speed gearbox. Ages 16 and up." "44999"
create_product "Barbie Dreamhouse" "barbie-dreamhouse" "3-story 8-room dollhouse. 70 accessories included. Working elevator and slide. Ages 3 and up." "19999"
create_product "Hot Wheels 50-Car Gift Pack" "hot-wheels-50-pack" "50 1:64 scale die-cast cars. Assorted styles. Great for collectors and kids ages 3 and up." "4999"

# Cereals
create_product "Quaker Oats and Granola Bundle" "quaker-oats-granola" "Variety pack: Classic Oats 1kg, Honey Granola 500g, Berry Granola 500g. No artificial additives." "2499"
create_product "Kelloggs Corn Flakes 1kg" "kelloggs-corn-flakes" "Classic corn flakes. Fortified with vitamins and minerals. Low in fat." "999"
create_product "Organic Muesli Mix" "organic-muesli" "Certified organic. Rolled oats, nuts, dried fruits and seeds. No added sugar. 500g." "1799"

# Prefab Houses
create_product "Modular Studio Unit 30sqm" "modular-studio-unit" "Compact prefab studio. Insulated panels. Includes kitchenette and bathroom. 4-week delivery." "1500000"
create_product "Garden Cabin Office Pod" "garden-cabin-pod" "12sqm garden office. Double-glazed windows. Ethernet and power included. Delivered assembled." "850000"

# Solar Batteries
create_product "200Ah LiFePO4 Battery" "lifepo4-200ah" "Grade A lithium iron phosphate cells. 6000 cycle life. Built-in BMS. For solar systems." "89999"
create_product "AGM Deep Cycle Battery 100Ah" "agm-deep-cycle-100ah" "Sealed AGM technology. Maintenance-free. Suitable for solar, marine and RV use." "24999"
create_product "12V 300W Solar Panel" "solar-panel-300w" "Monocrystalline silicon. 21.5 percent efficiency. IP68 junction box. 25-year power warranty." "34999"

echo ""
echo "🎉 Done! All products created."
echo "Now assign them to collections in the Vendure admin dashboard at http://localhost:5173"
