import { useMemo, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { SEARCH_INGREDIENTS } from "../lib/demoResults";
import { state } from "../lib/state";
import { SearchGlyph } from "./pet-setup";
import { tierColor } from "./ingredient";

/**
 * "Search for more..." — `IngredientSearchSheet`.
 *
 * Every ingredient the app knows (626, baked in with the demo results), in
 * the app's own order, filtered on common or scientific name. A pick is stored
 * as the lowercased common name, exactly as native stores it, so the app's
 * scorer reads the same profile from either path.
 *
 * A concerning ingredient (caution or toxic for this species) carries its
 * risk mark, as natively.
 */
export const transition = "sheet";

export default function AllergenSearch() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const [query, setQuery] = useState("");
  const [picked, setPicked] = useState<string[]>(state.allergens);
  const species = state.species ?? "dog";

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return SEARCH_INGREDIENTS;
    return SEARCH_INGREDIENTS.filter(
      (i) => i.name.toLowerCase().includes(q) || i.scientific.toLowerCase().includes(q),
    );
  }, [query]);

  const toggle = (id: string) => {
    haptics.selection();
    const next = picked.includes(id) ? picked.filter((a) => a !== id) : [...picked, id];
    setPicked(next);
    state.allergens = next;
  };

  return (
    <div className="page page--sheet">
      <div className="page__body search-sheet">
        <div className="search-sheet__bar">
          <label className="search-field">
            <SearchGlyph size={18} />
            <input
              className="search-field__input"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t("search.placeholder", { count: String(SEARCH_INGREDIENTS.length) })}
              aria-label={t("search.placeholder", { count: String(SEARCH_INGREDIENTS.length) })}
              autoComplete="off"
              autoCorrect="off"
              autoCapitalize="none"
              enterKeyHint="search"
            />
            {query ? (
              <button
                type="button"
                className="search-field__clear"
                aria-label={t("search.clear")}
                onClick={() => setQuery("")}
              >
                ×
              </button>
            ) : null}
          </label>
          {picked.length > 0 ? (
            <span className="search-sheet__count">
              ✓ {t(picked.length === 1 ? "search.selectedOne" : "search.selected", { count: String(picked.length) })}
            </span>
          ) : null}
        </div>

        <div className="search-list">
          {rows.map((ing) => {
            const on = picked.includes(ing.id);
            const tier = species === "cat" ? ing.catTier : ing.dogTier;
            const concerning = tier === "toxic" || tier === "caution";
            return (
              <button
                key={ing.key}
                type="button"
                className="search-row"
                aria-pressed={on}
                onClick={() => toggle(ing.id)}
              >
                <span className="search-row__text">
                  <span className="search-row__name">{ing.name}</span>
                  {ing.function ? <span className="search-row__fn">{ing.function}</span> : null}
                </span>
                {concerning ? (
                  <span className="search-row__risk" style={{ color: tierColor(tier) }} aria-hidden="true">
                    {tier === "toxic" ? "✕" : "!"}
                  </span>
                ) : null}
                <span className={`search-row__check${on ? " search-row__check--on" : ""}`} aria-hidden="true">
                  {on ? "✓" : ""}
                </span>
              </button>
            );
          })}
        </div>

        <div className="actions">
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={() => {
              haptics.light();
              router.back();
            }}
          >
            {picked.length ? t("search.doneCount", { count: String(picked.length) }) : t("chrome.done")}
          </button>
        </div>
      </div>
    </div>
  );
}
