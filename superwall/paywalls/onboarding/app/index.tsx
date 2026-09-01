import { useUser } from "superwall/hooks";
import { Check } from "../components/Icons";
import { num } from "../lib/offer";

/** The score bands the dashboard paywall colours the verdict dot with. */
const scoreClass = (score?: number) => {
  if (score === undefined) return "";
  if (score >= 80) return " score-dot--excellent";
  if (score >= 60) return " score-dot--good";
  if (score >= 40) return " score-dot--moderate";
  return "";
};

const MYSTERIES = [
  { emoji: "🦴", label: "Treats" },
  { emoji: "🛍️", label: "The next bag" },
  { emoji: "🥫", label: "Wet food" },
];

/**
 * The payoff of the onboarding search: the food they just scored, then the
 * three meals they haven't.
 */
export default function Index() {
  const user = useUser();

  const petName = (user.pet_name as string | undefined) ?? "your pet";
  const brand = user.searched_food_brand as string | undefined;
  const foodName = user.searched_food_name as string | undefined;
  const verdict = user.searched_food_verdict as string | undefined;
  const score = num(user.searched_food_score as string | number | undefined);
  const flagCount = num(user.searched_food_flag_count as string | number | undefined) ?? 0;

  return (
    <main className="page">
      <div className="hero">
        <div className="eyebrow">
          <Check size={14} />
          SCAN COMPLETE
        </div>

        <h1 className="hero__headline">You just saw what's really in {petName}'s bowl.</h1>

        <div className="result-card">
          <div className="result-card__top">
            <div className="result-card__food">
              {brand ? <span className="result-card__brand">{brand}</span> : null}
              {foodName ? <span className="result-card__name">{foodName}</span> : null}
            </div>
          </div>
          <div className="result-card__divider" />
          <div className="result-card__verdict">
            <span className={`score-dot${scoreClass(score)}`} />
            <span>
              {verdict ? `${verdict} · ` : ""}
              {flagCount === 0 ? "nothing to avoid" : `${flagCount} to avoid`}
            </span>
          </div>
        </div>

        <h2 className="hero__kicker">
          {flagCount === 0 ? "But that's just one meal." : "And that's just the food you checked."}
        </h2>

        <p className="hero__sub">
          {petName} eats dozens of other things you've never scanned — and every label hides
          something.
        </p>

        <div className="mystery-row">
          {MYSTERIES.map((item) => (
            <div className="mystery-card" key={item.label}>
              <span className="mystery-card__emoji">{item.emoji}</span>
              <span className="mystery-card__badge">?</span>
              <span className="mystery-card__label">{item.label}</span>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
