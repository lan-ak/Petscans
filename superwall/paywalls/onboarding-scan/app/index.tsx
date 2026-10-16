import { useHaptics, useTranslation, useVariables } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Companion } from "../components/Companion";
import { Check } from "../components/Icons";
import { int, petName, petSpecies, str } from "../lib/variables";

/**
 * The score bands the app colours a verdict with — the same thresholds as
 * `ScoreBand` natively, so a food that reads amber in the app reads amber here.
 */
type Band = "excellent" | "good" | "moderate" | "poor";

const bandFor = (score?: number): Band | undefined => {
  if (score === undefined) return undefined;
  if (score >= 80) return "excellent";
  if (score >= 60) return "good";
  if (score >= 40) return "moderate";
  return "poor";
};

/**
 * The payoff of the onboarding search: their pet, the food they just scored,
 * and the three meals they haven't.
 *
 * Three states, all live in this audience:
 *
 *   flagged     58% — "You caught 3 things in Gizmo's bowl."
 *   clean       42% — the scan came back with nothing to avoid. The page must
 *                     not argue with the evidence in their hand, so it keeps
 *                     the green verdict and pivots to the meals they haven't
 *                     checked. 245894's own "But that's just one meal." beat.
 *   no result    —   the audience is an OR and the placement counter can admit
 *                     a device with no `searched_food_*` attributes at all.
 */
export default function Index() {
  const { user } = useVariables();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const router = useRouter();

  const pet = petName(user);
  const species = petSpecies(user);
  const brand = str(user.searched_food_brand);
  const foodName = str(user.searched_food_name);
  const verdict = str(user.searched_food_verdict);
  const score = int(user.searched_food_score);
  const flagCount = int(user.searched_food_flag_count) ?? 0;

  const band = bandFor(score);

  /*
   * A missing result is not a clean one. Without this guard a device admitted
   * by the placement counter alone gets an empty card with a lone verdict dot,
   * and a `flagCount` defaulting to 0 tells them "nothing to avoid" about a
   * food we cannot name.
   */
  const hasResult = brand !== undefined || foodName !== undefined || verdict !== undefined;
  const clean = hasResult && flagCount === 0;

  /* No plural engine, so the count forks the key rather than suffixing it. */
  const headline = !hasResult
    ? t("result.headlineNoResult", { pet })
    : clean
      ? brand
        ? t("result.headlineCleanBranded", { brand })
        : t("result.headlineClean")
      : flagCount === 1
        ? t("result.headlineOne", { pet })
        : t("result.headlineMany", { pet, count: flagCount });

  const sub = !hasResult
    ? t("result.subNoResult")
    : clean
      ? t("result.subClean", { pet })
      : t("result.subFlagged", { pet });

  return (
    <main className="page">
      <div className="hero">
        <div className="eyebrow">
          <Check size={14} />
          {t("result.eyebrow")}
        </div>

        {/* Whose bowl this is, before what was in it. */}
        <Companion
          species={species}
          alt={species === "cat" ? t("result.companionCat") : t("result.companionDog")}
        />

        {hasResult ? (
          <div className="result-card">
            <div className="result-card__top">
              {/*
               * The ring is the one element on this screen that is purely
               * theirs, so it leads. Without a score it would be an empty
               * circle reading as a loading state, so the card falls back to
               * the text-only layout it had before.
               */}
              {score !== undefined && band ? (
                <span
                  className={`score-ring score-ring--${band}`}
                  style={{ ["--score" as string]: String(score) }}
                  aria-hidden="true"
                >
                  <span className="score-ring__value">{score}</span>
                </span>
              ) : null}

              <div className="result-card__food">
                {brand ? <span className="result-card__brand">{brand}</span> : null}
                {foodName ? <span className="result-card__name">{foodName}</span> : null}
              </div>
            </div>

            <div className="result-card__divider" />

            <div className="result-card__verdict">
              <span className={`score-dot${band ? ` score-dot--${band}` : ""}`} />
              <span>
                {verdict ? `${verdict} · ` : ""}
                {clean ? t("result.nothingToAvoid") : t("result.toAvoid", { count: flagCount })}
              </span>
            </div>
          </div>
        ) : null}

        <h1 className="hero__headline">{headline}</h1>
        <p className="hero__sub">{sub}</p>

        <div className="mystery-row">
          <MysteryCard emoji="🦴" label={t("result.mysteryTreats")} />
          <MysteryCard emoji="🛍️" label={t("result.mysteryNextBag")} />
          <MysteryCard emoji="🥫" label={t("result.mysteryWetFood")} />
        </div>
      </div>

      {/* Sticky, so the locked cards scroll under it on a short phone. */}
      <div className="footer">
        <button
          type="button"
          className="cta pressable"
          onClick={() => {
            haptics.medium();
            router.push("plans");
          }}
        >
          {t("result.cta")}
        </button>
      </div>
    </main>
  );
}

function MysteryCard({ emoji, label }: { emoji: string; label: string }) {
  return (
    <div className="mystery-card">
      <span className="mystery-card__emoji">{emoji}</span>
      <span className="mystery-card__badge">?</span>
      <span className="mystery-card__label">{label}</span>
    </div>
  );
}
