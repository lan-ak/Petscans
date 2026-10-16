import { useEffect, useRef, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Bag, ChevronRight, ClearMark, Search as SearchIcon } from "../components/Icons";
import { type CatalogRow, useCallbacks } from "../lib/callbacks";
import { state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Search, demoted from the only door to one of three.
 *
 * The brand grid is carried over from `ProductCatalogSearchView` unchanged in
 * substance — it is the one part of the native step that measurably worked
 * (17 of 21 users had been leaving in a median of 12 seconds without typing a
 * character). What is new is that nothing here is terminal: a miss, a failure
 * and an empty catalogue all keep a way forward.
 */
export default function SearchPage() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const call = useCallbacks();
  const track = useTrack();

  const [query, setQuery] = useState("");
  const [rows, setRows] = useState<CatalogRow[]>([]);
  const [status, setStatus] = useState<"idle" | "searching" | "done" | "failed">("idle");
  const [scoring, setScoring] = useState(false);
  // Guards a late response from a cancelled query overwriting a newer one.
  const runId = useRef(0);

  const trimmed = query.trim();

  useEffect(() => {
    if (trimmed.length < 2) {
      setRows([]);
      setStatus("idle");
      return;
    }

    const id = ++runId.current;
    setStatus("searching");

    // 220ms, the same debounce `ProductCatalogSearchView.runSearch` uses, so
    // typing feels identical either side of the swap.
    const timer = setTimeout(async () => {
      const result = await call.search(trimmed, state.species);
      if (id !== runId.current) return;

      if (!result.ok) {
        // The third failure mode, visible for the first time. Today a search
        // that throws is indistinguishable from a user who typed nothing.
        track("search_failed", { term: trimmed });
        setStatus("failed");
        return;
      }

      track("search_attempted", { term: trimmed, results: result.value.length });
      if (result.value.length === 0) {
        track("search_no_results", { term: trimmed });
      }
      setRows(result.value);
      setStatus("done");
    }, 220);

    return () => clearTimeout(timer);
  }, [trimmed, call, track]);

  const pick = async (row: CatalogRow) => {
    if (scoring) return;
    haptics.selection();
    setScoring(true);

    const scored = await call.score(row.gtin, state.species);
    setScoring(false);
    if (!scored.ok) {
      setStatus("failed");
      return;
    }

    state.food = scored.value;
    state.isExample = false;
    track("result_shown", { path: "search", score: scored.value.score });
    router.push("result");
  };

  const useExample = async () => {
    haptics.light();
    const result = await call.example(state.species);
    if (!result.ok) return;
    state.food = result.value;
    state.isExample = true;
    track("result_shown", { path: "example", score: result.value.score });
    router.push("result");
  };

  /**
   * The brand lists from `ProductCatalogSearchView.popularBrandNames`, kept to
   * the recognisable brand token rather than the full line name — a tile has
   * one line, and "Purina" matches more of the catalogue than "Purina Pro
   * Plan" does.
   */
  const brands =
    state.species === "cat"
      ? ["Fancy Feast", "Friskies", "Blue Buffalo", "Temptations", "Purina", "Hill's", "Wellness", "Royal Canin"]
      : state.species === "dog"
        ? ["Blue Buffalo", "Purina", "Pedigree", "Hill's", "Royal Canin", "Merrick", "Wellness", "IAMS"]
        : ["Blue Buffalo", "Purina", "Hill's", "Royal Canin", "Fancy Feast", "Pedigree", "Wellness", "IAMS"];

  const showBrands = trimmed.length < 2;
  const empty = status === "done" && rows.length === 0;

  return (
    <div className="page">
      <div className="page__head">
        <h1 className="page__title">{t("search.title")}</h1>
      </div>

      <div className="page__body">
        <div className="field field--search">
          <SearchIcon />
          <input
            id="food-check-query"
            className="field__input"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t("search.placeholder")}
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="words"
            enterKeyHint="search"
          />
          {query ? (
            <button type="button" aria-label={t("search.clear")} onClick={() => { haptics.light(); setQuery(""); }}>
              <ClearMark />
            </button>
          ) : null}
        </div>

        {showBrands ? (
          <div className="scroller">
            <p className="rail-label">{t("search.popular")}</p>
            <div className="brand-grid">
              {brands.map((brand) => (
                <button
                  key={brand}
                  type="button"
                  className="brand pressable"
                  onClick={() => {
                    haptics.selection();
                    setQuery(brand);
                  }}
                >
                  {brand}
                  <span className="brand__chevron">
                    <ChevronRight />
                  </span>
                </button>
              ))}
            </div>
          </div>
        ) : status === "failed" ? (
          <div className="state">
            <p className="state__title">{t("search.failedTitle")}</p>
            <p className="state__body">{t("search.failedBody")}</p>
            <button
              type="button"
              className="btn btn--tertiary"
              onClick={() => { haptics.light(); setQuery(query); }}
            >
              {t("search.retry")}
            </button>
            <button type="button" className="btn btn--tertiary" onClick={useExample}>
              {t("search.emptyExample")}
            </button>
          </div>
        ) : empty ? (
          /*
            A miss must never be terminal. The native empty state could only
            send the user back to the grid; this also offers the zero-input
            path, because someone whose food genuinely isn't in the catalogue
            cannot type their way out of that.
          */
          <div className="state">
            <span className="state__icon">
              <SearchIcon size={34} />
            </span>
            <p className="state__title">{t("search.emptyTitle", { term: trimmed })}</p>
            <p className="state__body">{t("search.emptyBody")}</p>
            <button
              type="button"
              className="btn btn--tertiary"
              onClick={() => { haptics.light(); setQuery(""); }}
            >
              {t("search.emptyBrowse")}
            </button>
            <button type="button" className="btn btn--tertiary" onClick={useExample}>
              {t("search.emptyExample")}
            </button>
          </div>
        ) : status === "searching" && rows.length === 0 ? (
          <div className="state">
            <span className="btn__spinner" style={{ color: "var(--text-40)" }} />
            <p className="state__body">{t("search.searching")}</p>
          </div>
        ) : (
          <div className="results">
            {rows.map((row) => (
              <button
                key={row.gtin}
                type="button"
                className="result-row pressable"
                onClick={() => pick(row)}
                disabled={scoring}
              >
                <span className="state__icon">
                  <Bag />
                </span>
                <span className="result-row__text">
                  <span className="result-row__name">{row.name}</span>
                  <span className="result-row__brand">
                    {row.brand}
                    {row.variants > 1
                      ? `${row.brand ? " · " : ""}${t("search.variants", { count: String(row.variants) })}`
                      : ""}
                  </span>
                </span>
                <span className="brand__chevron">
                  <ChevronRight />
                </span>
              </button>
            ))}
          </div>
        )}

        <div className="page__spacer" />

        <div className="actions">
          <button type="button" className="btn btn--tertiary" onClick={() => { haptics.light(); router.back(); }}>
            {t("search.scanInstead")}
          </button>
        </div>
      </div>
    </div>
  );
}
