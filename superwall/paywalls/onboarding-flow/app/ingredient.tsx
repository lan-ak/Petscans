import { useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import type { RiskTierToken } from "../lib/demoResults";
import { state } from "../lib/state";

/**
 * `IngredientDetailSheet`, opened from "What's inside" on the demo result.
 *
 * Native order and native conditions: the name with its risk badge, the
 * scientific name and function; About; Safety Information *only when the
 * tier isn't Safe*; symptoms; toxic dose; Notes *only when there's no
 * authored About* (About is written from the notes, so both would repeat
 * it); what the research says; Details; Sources. The History count and the
 * avoid-list button need a pet and a History, and onboarding has neither.
 *
 * A route rather than an overlay: routes are the only layer the framework
 * insets and scrolls. The `sheet` transition (theme.css) makes it rise and
 * fall like the native sheet; the layout gives it "Ingredient Details" and
 * Done. Closing is `router.back()`.
 */
export const transition = "sheet";

/** `RiskTier.color`. Moderation and mostly-safe are info blue, not amber. */
export function tierColor(tier: RiskTierToken): string {
  switch (tier) {
    case "toxic": return "var(--error)";
    case "caution": return "var(--warning)";
    case "moderation":
    case "mostlySafe": return "var(--info)";
    default: return "var(--success)";
  }
}

/** `RiskTier.icon`: xmark.circle, exclamationmark.triangle, checkmark.circle. */
function TierGlyph({ tier, size = 16 }: { tier: RiskTierToken; size?: number }) {
  if (tier === "caution") {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
        <path fill="currentColor" d="M12 2.9c.6 0 1.2.33 1.5.88l8 14.1A1.7 1.7 0 0 1 20 20.5H4a1.7 1.7 0 0 1-1.5-2.6l8-14.1c.3-.55.9-.88 1.5-.88z" />
        <path d="M12 9v4.6" stroke="var(--tier-ink, #fff)" strokeWidth="2.2" strokeLinecap="round" />
        <circle cx="12" cy="17" r="1.25" fill="var(--tier-ink, #fff)" />
      </svg>
    );
  }
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="10" fill="currentColor" />
      {tier === "toxic" ? (
        <path d="M8.5 8.5l7 7M15.5 8.5l-7 7" stroke="var(--tier-ink, #fff)" strokeWidth="2.2" strokeLinecap="round" />
      ) : (
        <path d="M7.5 12.3l3 3 6-6.3" fill="none" stroke="var(--tier-ink, #fff)" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      )}
    </svg>
  );
}

export default function Ingredient() {
  const router = useRouter();
  const { t } = useTranslation();
  const d = state.ingredient;
  const animal = t(state.species === "cat" ? "ingredient.cats" : "ingredient.dogs");

  if (!d) {
    return (
      <div className="page">
        <div className="page__body">
          <button type="button" className="btn btn--secondary" onClick={() => router.back()}>
            {t("chrome.back")}
          </button>
        </div>
      </div>
    );
  }

  const color = tierColor(d.tier);

  return (
    <div className="page page--sheet">
      <div className="page__body">
        <div className="scroller scroller--sheet">
          <div className="ing-head">
            <div className="ing-head__row">
              <h1 className="ing-head__name">{d.name}</h1>
              <span className="tier-badge" style={{ background: color, color: "#fff" }}>
                <TierGlyph tier={d.tier} size={14} />
                {d.tierName}
              </span>
            </div>
            {d.scientific ? <p className="ing-head__sci">{d.scientific}</p> : null}
            {d.function ? <p className="ing-head__fn">{d.function}</p> : null}
          </div>

          {d.about ? (
            <section className="card">
              <p className="card__lead">{d.about.whatItIs}</p>
              {d.about.whyItsHere ? <p className="card__body">{d.about.whyItsHere}</p> : null}
              {d.about.watch ? (
                <div className="card__sub">
                  <h3 className="card__subhead">{t("ingredient.watch")}</h3>
                  <p className="card__body card__body--strong">{d.about.watch}</p>
                </div>
              ) : null}
            </section>
          ) : d.composed ? (
            <section className="card">
              <p className="card__body">{d.composed}</p>
            </section>
          ) : null}

          {d.tier !== "safe" ? (
            <section
              className="card card--flat"
              style={{ background: `color-mix(in srgb, ${color} 10%, var(--bg))` }}
            >
              <h2 className="card__title">
                <span style={{ color }}>
                  <TierGlyph tier={d.tier} size={18} />
                </span>
                {t("ingredient.safety")}
              </h2>
              <p className="card__body">{t(`ingredient.risk.${d.tier}`, { animal })}</p>
              {d.perSpecies ? (
                <div className="card__sub">
                  <p className="card__caption">{t("ingredient.perSpecies")}</p>
                  <p className="per-species">
                    <span style={{ color: tierColor(d.perSpecies.dogTier) }}>
                      {t("index.dog")} · {d.perSpecies.dog}
                    </span>
                    <span style={{ color: tierColor(d.perSpecies.catTier) }}>
                      {t("index.cat")} · {d.perSpecies.cat}
                    </span>
                  </p>
                </div>
              ) : null}
            </section>
          ) : null}

          {d.symptoms.length > 0 ? (
            <section className="card">
              <h2 className="card__title">{t("ingredient.symptoms")}</h2>
              <div className="symptoms">
                {d.symptoms.map((s) => (
                  <span className="symptom" key={s}>{s}</span>
                ))}
              </div>
            </section>
          ) : null}

          {d.dose ? (
            <section className="card card--flat" style={{ background: "color-mix(in srgb, var(--warning) 10%, var(--bg))" }}>
              <h2 className="card__title">{t("ingredient.dose")}</h2>
              <p className="card__body card__body--strong">{d.dose}</p>
            </section>
          ) : null}

          {!d.about && d.notes ? (
            <section className="card">
              <h2 className="card__title">{t("ingredient.notes")}</h2>
              <p className="card__body card__body--strong">{d.notes}</p>
            </section>
          ) : null}

          {d.rules.length > 0 ? (
            <section className="card">
              <h2 className="card__title">{t("ingredient.research")}</h2>
              {d.rules.map((r, i) => (
                <div className="rule" key={i}>
                  <p className="rule__head">
                    <span className={`rule__sev rule__sev--${r.severity}`}>{r.severityName}</span>
                    {evidenceKey(r.evidence) ? (
                      <span className="rule__ev">· {t(evidenceKey(r.evidence)!)}</span>
                    ) : r.evidence ? (
                      <span className="rule__ev">· {r.evidence}</span>
                    ) : null}
                  </p>
                  <p className="card__body card__body--strong">{r.explain}</p>
                  {r.source ? <p className="card__caption">{r.source}</p> : null}
                </div>
              ))}
            </section>
          ) : null}

          <section className="card">
            <h2 className="card__title">{t("ingredient.details")}</h2>
            <div className="details">
              <div className="details__item">
                <span className="details__label">{t("ingredient.origin")}</span>
                <span className="details__value">{d.origin}</span>
              </div>
              {d.processing ? (
                <div className="details__item">
                  <span className="details__label">{t("ingredient.processing")}</span>
                  <span className="proc-badge" style={{ background: `var(--score-${d.processing.tone})` }}>
                    {d.processing.name}
                  </span>
                </div>
              ) : null}
              {d.allergenRisk ? (
                <div className="details__item">
                  <span className="details__label">{t("ingredient.allergenRisk")}</span>
                  <span className="details__value">{d.allergenRisk}</span>
                </div>
              ) : null}
              <div className="details__item">
                <span className="details__label">{t("ingredient.suitableFor")}</span>
                <span className="details__value details__species">
                  {d.suitableFor.map((s) => (
                    <span key={s}>{t(`index.${s}`)}</span>
                  ))}
                </span>
              </div>
            </div>
          </section>

          {d.sources.length > 0 ? (
            <div className="sources">
              <p className="sources__label">{t("ingredient.sources")}</p>
              {d.sources.map((s) => (
                <p key={s} className="sources__item">• {s}</p>
              ))}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  );
}

/** `IngredientDetailSheet.evidenceLabel`; an unknown value prints as-is. */
function evidenceKey(evidence: string): string | null {
  switch (evidence.toLowerCase()) {
    case "strong": return "ingredient.evidence.strong";
    case "medium":
    case "moderate": return "ingredient.evidence.moderate";
    case "limited":
    case "weak": return "ingredient.evidence.limited";
    case "debated":
    case "mixed": return "ingredient.evidence.debated";
    default: return null;
  }
}
