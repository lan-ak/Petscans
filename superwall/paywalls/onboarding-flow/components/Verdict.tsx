import { useEffect, useRef, useState } from "react";
import { useSuperwallSnapshot, useTranslation } from "superwall/hooks";
import { scoreTone, verdictTone } from "../lib/state";

/**
 * The payoff screen's verdict and axis bars, ported from `RatingLabelView`
 * and `ScoreExplanationCard`.
 *
 * The native demo result leads with the *word* — Excellent / Good / Caution /
 * Avoid — on a tinted card, not with a 0-100 dial. That is the right call and
 * worth keeping: a verdict is an answer, a number is homework. The axes sit
 * underneath as bars, which is where the number actually belongs.
 */

/** `RatingLabel.icon`, as SVG — SF Symbols don't exist in a webview. */
function VerdictMark({ verdict, size = 60 }: { verdict: string; size?: number }) {
  const common = { width: size, height: size, viewBox: "0 0 24 24", "aria-hidden": true as const };

  switch (verdict.toLowerCase()) {
    case "excellent":
      // checkmark.seal.fill — a scalloped seal. 12 lobes on a circle, which
      // is what gives the badge its stamped look rather than a plain disc.
      return (
        <svg {...common}>
          <path d={sealPath()} fill="currentColor" />
          <path
            d="M8.2 12.3l2.6 2.6 5-5.2"
            fill="none"
            stroke="var(--on-primary)"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      );
    case "good":
      // hand.thumbsup.fill
      return (
        <svg {...common}>
          <path
            d="M7 10.5h2.2l2.9-6a1.8 1.8 0 0 1 3.4 1.1L14.8 9h3.6a2 2 0 0 1 2 2.4l-1.3 6A2 2 0 0 1 17.1 19H7z"
            fill="currentColor"
          />
          <rect x="3" y="10" width="3.4" height="9" rx="1.1" fill="currentColor" />
        </svg>
      );
    case "avoid":
      // xmark.octagon.fill
      return (
        <svg {...common}>
          <path
            d="M8.2 2.4h7.6L21.6 8.2v7.6L15.8 21.6H8.2L2.4 15.8V8.2z"
            fill="currentColor"
          />
          <path
            d="M9 9l6 6M15 9l-6 6"
            stroke="var(--on-primary)"
            strokeWidth="2.2"
            strokeLinecap="round"
          />
        </svg>
      );
    default:
      // exclamationmark.triangle.fill — "Caution"
      return (
        <svg {...common}>
          <path
            d="M12 2.9c.6 0 1.2.33 1.5.88l8 14.1A1.7 1.7 0 0 1 20 20.5H4a1.7 1.7 0 0 1-1.5-2.6l8-14.1c.3-.55.9-.88 1.5-.88z"
            fill="currentColor"
          />
          <path
            d="M12 9v4.6"
            stroke="var(--on-primary)"
            strokeWidth="2.2"
            strokeLinecap="round"
          />
          <circle cx="12" cy="17" r="1.25" fill="var(--on-primary)" />
        </svg>
      );
  }
}

/** A 12-lobed scalloped circle, the seal silhouette. */
function sealPath(): string {
  const cx = 12;
  const cy = 12;
  const lobes = 12;
  const outer = 10.4;
  const inner = 8.9;
  const pts: string[] = [];
  for (let i = 0; i < lobes * 2; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = (Math.PI / lobes) * i - Math.PI / 2;
    pts.push(`${(cx + r * Math.cos(a)).toFixed(2)},${(cy + r * Math.sin(a)).toFixed(2)}`);
  }
  return `M${pts.join("L")}Z`;
}

/**
 * The verdict card. Tinted in the score's own hue with a hairline ring and a
 * shadow in that hue rather than neutral grey — the depth language every
 * other surface in the app uses.
 */
export function VerdictCard({ verdict }: { verdict: string }) {
  const snapshot = useSuperwallSnapshot();
  const [shown, setShown] = useState(false);
  const armed = useRef(false);
  // The verdict's own colour, not the score's. See `verdictTone`.
  const tone = verdictTone(verdict);

  useEffect(() => {
    if (armed.current) return;
    const go = () => {
      armed.current = true;
      setShown(true);
    };
    if (snapshot.paywall !== undefined) {
      const f = requestAnimationFrame(() => requestAnimationFrame(go));
      return () => cancelAnimationFrame(f);
    }
    // Never let the verdict depend on an event arriving — it is the answer
    // the whole screen exists to deliver.
    const t = setTimeout(go, 600);
    return () => clearTimeout(t);
  }, [snapshot.paywall]);

  return (
    <div
      className={`verdict${shown ? " verdict--in" : ""}`}
      style={{ color: `var(--score-${tone})` }}
    >
      <VerdictMark verdict={verdict} />
      <span className="verdict__word">{verdict}</span>
    </div>
  );
}

/**
 * One axis — Safety, Processing, Suitability — as a labelled 8px bar, the
 * height `ScoreExplanationCard` uses. Returns nothing for an axis the app
 * marked inapplicable (`-1`), rather than drawing an empty bar that reads
 * as a score of zero.
 */
export function ScoreBar({ titleKey, score }: { titleKey: string; score: number }) {
  const { t } = useTranslation();
  const snapshot = useSuperwallSnapshot();
  const [filled, setFilled] = useState(false);
  const armed = useRef(false);

  useEffect(() => {
    if (armed.current) return;
    const go = () => {
      armed.current = true;
      setFilled(true);
    };
    if (snapshot.paywall !== undefined) {
      const f = requestAnimationFrame(() => requestAnimationFrame(go));
      return () => cancelAnimationFrame(f);
    }
    const timer = setTimeout(go, 600);
    return () => clearTimeout(timer);
  }, [snapshot.paywall]);

  if (score < 0) return null;
  const pct = Math.max(0, Math.min(100, Math.round(score)));
  const tone = scoreTone(pct);

  return (
    <div className="axis">
      <div className="axis__head">
        <span className="axis__title">{t(titleKey)}</span>
        <span className="axis__value" style={{ color: `var(--score-${tone})` }}>
          {pct}
        </span>
      </div>
      <div className="axis__track">
        <div
          className="axis__fill"
          style={{
            width: filled ? `${pct}%` : "0%",
            background: `var(--score-${tone})`,
          }}
        />
      </div>
    </div>
  );
}
