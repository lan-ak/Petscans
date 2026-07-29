#!/usr/bin/env python3
"""Generate PetScans/Data/avoidance-groups.json — a curated map of ingredient id
-> the AvoidanceGroup(s) it belongs to, consumed by ScoreCalculator.

Deterministic and reviewable on purpose: scoring-critical data should not depend
on an opaque model pass. The precise groups (colours, preservatives, sugars, gums,
ultraProcessed) use explicit id lists; the broad protein/grain groups use
token-boundary matching over commonName with explicit trap/exclusion sets so a
substring like "acorn" can't match "corn".

Run from repo root:  python3 tools/gen-avoidance-groups.py
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ING = ROOT / "PetScans" / "Data" / "ingredients.json"
OUT = ROOT / "PetScans" / "Data" / "avoidance-groups.json"

items = json.load(open(ING))
by_id = {i["id"]: i for i in items}
ids = set(by_id)

# ---- Explicit curated id lists (precise groups) -----------------------------
ARTIFICIAL_COLOURS = {
    "ing_artificial_colors", "ing_blue_1", "ing_blue_2", "ing_red_40",
    "ing_yellow_5", "ing_yellow_6", "ing_titanium_dioxide", "ing_caramel_color",
    "ing_iron_oxide", "ing_iron_oxide_black", "ing_iron_oxide_red", "ing_iron_oxide_yellow",
}
# Excludes natural colorants (beet/paprika/turmeric/riboflavin) by omission.

ARTIFICIAL_PRESERVATIVES = {
    "ing_bha", "ing_bht", "ing_ethoxyquin", "ing_tbhq", "ing_propyl_gallate",
    "ing_calcium_propionate", "ing_sodium_benzoate", "ing_sodium_bisulfite",
    "ing_sodium_nitrite", "ing_sorbic_acid", "ing_propylene_glycol",
}
# Excludes natural (tocopherols, rosemary, citric/ascorbic/lactic/acetic acid,
# green tea) and cosmetic-only preservatives (parabens, DMDM, phenoxyethanol).

ADDED_SUGARS = {"ing_erythritol", "ing_sorbitol", "ing_xylitol"}

ULTRA_PROCESSED = {
    "ing_artificial_flavor", "ing_msg",
    "ing_hydrolyzed_chicken", "ing_hydrolyzed_fish_protein", "ing_hydrolyzed_meat_protein",
    "ing_hydrolyzed_poultry_protein", "ing_hydrolyzed_protein", "ing_hydrolyzed_salmon",
    "ing_hydrolyzed_soy", "ing_hydrolyzed_vegetable_protein",
    "ing_sodium_tripolyphosphate", "ing_sodium_hexametaphosphate",
}
# Level-4 required nutrients (vitamins/amino acids/minerals/enzymes) and protein
# isolates are intentionally excluded — including them would flag every complete food.

GUMS_THICKENERS = {
    "ing_acacia_gum", "ing_agar_agar", "ing_carboxymethylcellulose", "ing_carob_bean_gum",
    "ing_carrageenan", "ing_cassia_gum", "ing_cellulose", "ing_cellulose_gum",
    "ing_guar_gum", "ing_gum_arabic", "ing_konjac", "ing_locust_bean_gum",
    "ing_methylcellulose", "ing_modified_food_starch", "ing_mono_diglycerides",
    "ing_pectin", "ing_polysorbate_80", "ing_powdered_cellulose", "ing_tara_gum",
    "ing_xanthan_gum",
}
# Excludes plain single-source starches (grain-free staples), lecithins, gelatin.

MEAT_BYPRODUCTS = {
    "ing_animal_digest", "ing_animal_fat", "ing_beef_by_products", "ing_bone_meal",
    "ing_chicken_by_product_meal", "ing_chicken_by_products", "ing_meat_and_bone_meal",
    "ing_meat_by_products", "ing_meat_meal", "ing_poultry_by_product_meal",
    "ing_poultry_by_products", "ing_poultry_meal",
}

# ---- Token-boundary rules (broad protein/grain groups) ----------------------
def tokens(i):
    return set(re.split(r"[^a-z0-9]+", by_id[i]["commonName"].lower()))

# commonAllergens: the base protein/grain sources behind most pet sensitivities.
ALLERGEN_TOKENS = {
    "chicken", "beef", "lamb", "pork", "egg", "eggs",
    "milk", "dairy", "cheese", "whey", "casein", "lactose", "buttermilk",
    "soy", "soybean", "soybeans", "corn", "wheat",
    "salmon", "fish",  # fish as a class + salmon; named single-species handled below
}
# Carry little/no allergenic protein, or are hypoallergenic / novel proteins.
ALLERGEN_EXCLUDE_IDS = {
    "ing_soy_lecithin", "ing_soy_hulls", "ing_soybean_oil", "ing_corn_oil",
    "ing_corn_starch", "ing_cornstarch", "ing_salmon_oil", "ing_fish_oil",
    "ing_eggshell_calcium", "ing_beef_fat", "ing_beef_tallow", "ing_chicken_fat",
    "ing_lamb_fat", "ing_pork_fat",
    # Named single-species fish: deliberately-chosen / novel proteins, not the
    # generic "fish" allergen class — flagging them would penalise novel-protein diets.
    "ing_catfish", "ing_menhaden", "ing_menhaden_fish_meal",
    "ing_whitefish", "ing_whitefish_fresh", "ing_whitefish_meal",
}
# Hydrolyzed proteins are engineered to be hypoallergenic — never allergen-tag them.
def is_hydrolyzed(i):
    return "hydrolyzed" in by_id[i]["commonName"].lower()

# grainFillers: cheap cereal/legume carbohydrate bulk.
GRAIN_TOKENS = {"corn", "wheat", "soy", "soybean", "soybeans", "sorghum", "millet"}
GRAIN_EXTRA_IDS = {  # rice-family fillers that don't share a clean token
    "ing_brewers_rice", "ing_rice_bran", "ing_rice_hulls", "ing_corn_gluten_meal",
    "ing_corn_germ_meal", "ing_corn_bran", "ing_wheat_middlings", "ing_wheat_bran",
}
GRAIN_EXCLUDE_IDS = {
    "ing_soy_lecithin", "ing_soybean_oil", "ing_corn_oil", "ing_hydrolyzed_soy",
    "ing_soy_protein_isolate", "ing_soy_protein_concentrate",
}

def classify():
    m = {i: set() for i in ids}
    for i in ARTIFICIAL_COLOURS: m[i].add("artificialColours")
    for i in ARTIFICIAL_PRESERVATIVES: m[i].add("artificialPreservatives")
    for i in ADDED_SUGARS: m[i].add("addedSugars")
    for i in ULTRA_PROCESSED: m[i].add("ultraProcessed")
    for i in GUMS_THICKENERS: m[i].add("gumsThickeners")
    for i in MEAT_BYPRODUCTS: m[i].add("meatByproducts")
    for i in ids:
        if is_hydrolyzed(i):
            continue
        tk = tokens(i)
        if tk & ALLERGEN_TOKENS and i not in ALLERGEN_EXCLUDE_IDS:
            m[i].add("commonAllergens")
        if (tk & GRAIN_TOKENS or i in GRAIN_EXTRA_IDS) and i not in GRAIN_EXCLUDE_IDS:
            m[i].add("grainFillers")
    # Validate curated ids exist
    curated = (ARTIFICIAL_COLOURS | ARTIFICIAL_PRESERVATIVES | ADDED_SUGARS
               | ULTRA_PROCESSED | GUMS_THICKENERS | MEAT_BYPRODUCTS
               | GRAIN_EXTRA_IDS | ALLERGEN_EXCLUDE_IDS | GRAIN_EXCLUDE_IDS)
    missing = sorted(x for x in curated if x not in ids)
    if missing:
        print("ERROR: curated ids not in ingredients.json:", missing, file=sys.stderr)
        sys.exit(1)
    return {k: sorted(v) for k, v in m.items() if v}

result = classify()
OUT.write_text(json.dumps(dict(sorted(result.items())), indent=1) + "\n")

# ---- Review output ----------------------------------------------------------
from collections import Counter
c = Counter(g for v in result.values() for g in v)
GROUPS = ["ultraProcessed", "artificialColours", "artificialPreservatives",
          "commonAllergens", "addedSugars", "meatByproducts", "grainFillers", "gumsThickeners"]
print(f"wrote {OUT} — {len(result)} ingredients mapped")
for g in GROUPS:
    members = sorted(by_id[i]["commonName"] for i, v in result.items() if g in v)
    print(f"\n{g} ({c[g]}):")
    print("  " + ", ".join(members))
