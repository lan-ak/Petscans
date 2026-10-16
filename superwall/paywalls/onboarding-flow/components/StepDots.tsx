import { useTranslation } from "superwall/hooks";

/**
 * The question-block progress dots.
 *
 * They sit directly above the CTA, not in the top bar — that is where
 * `OnboardingView.standardChrome` puts them, and it is the better place: the
 * dots answer "how much more of this?", which is a question the user asks
 * with their thumb on the button, not while reading the heading.
 *
 * Two steps only (pet-setup → watch-list). The promise, the food check and
 * its payoff are discovery rather than a form, and a tracker over those reads
 * as paperwork — a bounded "2 steps" after the payoff is a promise that can
 * actually be kept.
 */
export function StepDots({ index, total = 2 }: { index: number; total?: number }) {
  const { t } = useTranslation();
  return (
    <span
      className="dots"
      role="img"
      aria-label={t("chrome.stepOf", { n: String(index + 1), total: String(total) })}
    >
      {Array.from({ length: total }, (_, i) => (
        <span key={i} className={`dot${i === index ? " dot--on" : ""}`} />
      ))}
    </span>
  );
}
