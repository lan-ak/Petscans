import { useEffect, useRef, useState } from "react";
import { useHaptics, useSuperwallSnapshot, useTranslation } from "superwall/hooks";
import { verdictTone } from "../lib/state";
import type { ScoreCardData } from "../lib/demoResults";

/**
 * `ScoreExplanationCard`: the axis title, the label it earns, an 8px bar, and
 * a tap that opens the summary and the factors behind it.
 *
 * The label and the bar width come from the app, not from `score` — a label
 * override (an unknown ingredient, say) pins Safety at "Caution" with the bar
 * at 35 even when the number is 98, and the card has to agree with the
 * verdict above it.
 */
export function ScoreCard({ title, data }: { title: string; data: ScoreCardData }) {
  const haptics = useHaptics();
  const snapshot = useSuperwallSnapshot();
  const [open, setOpen] = useState(false);
  const [filled, setFilled] = useState(false);
  const armed = useRef(false);
  const tone = verdictTone(data.label);

  // The fill keys off the surface being on screen, never mount — the SDK
  // preloads hidden — with a timer so it can't depend on an event arriving.
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

  return (
    <button
      type="button"
      className="axis axis--card"
      aria-expanded={open}
      onClick={() => {
        haptics.light();
        setOpen((v) => !v);
      }}
    >
      <span className="axis__head">
        <span className="axis__title">{title}</span>
        <span className="axis__label" style={{ color: `var(--score-${tone})` }}>
          {data.label}
        </span>
        <Chevron up={open} />
      </span>
      <span className="axis__track">
        <span
          className="axis__fill"
          style={{
            width: filled ? `${Math.max(0, Math.min(100, data.bar))}%` : "0%",
            background: `var(--score-${tone})`,
          }}
        />
      </span>

      {open ? (
        <span className="axis__more">
          <span className="axis__summary">{data.summary}</span>
          {data.factors.length > 0 ? (
            <span className="factors">
              {data.factors.map((f, i) => (
                <span className="factor" key={`${i}-${f.name}`}>
                  <ImpactMark impact={f.impact} />
                  <span className="factor__text">
                    {f.name ? <span className="factor__name">{f.name}</span> : null}
                    <span className="factor__desc">{f.text}</span>
                  </span>
                </span>
              ))}
            </span>
          ) : null}
        </span>
      ) : null}
    </button>
  );
}

function Chevron({ up }: { up: boolean }) {
  return (
    <svg className="axis__chev" width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d={up ? "M5 15l7-7 7 7" : "M5 9l7 7 7-7"}
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** `ExplanationFactor.Impact.icon` — plus, minus, dot — in the impact colour. */
function ImpactMark({ impact }: { impact: "positive" | "negative" | "neutral" }) {
  const { t } = useTranslation();
  const color =
    impact === "positive" ? "var(--success)" : impact === "negative" ? "var(--error)" : "var(--text-60)";
  return (
    <svg
      className="factor__mark"
      width="16"
      height="16"
      viewBox="0 0 24 24"
      role="img"
      aria-label={t(`result.impact.${impact}`)}
    >
      <circle cx="12" cy="12" r="10" fill={color} />
      {impact === "neutral" ? null : (
        <path d="M7.5 12h9" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" />
      )}
      {impact === "positive" ? (
        <path d="M12 7.5v9" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" />
      ) : null}
    </svg>
  );
}
