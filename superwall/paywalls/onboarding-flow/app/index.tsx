import { useEffect, useRef } from "react";
import { useHaptics, useSuperwallSnapshot, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { CompanionPair } from "../components/Companions";
import { reset } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Step 0 — the promise.
 *
 * Both animals, deliberately: the species question belongs on the food-check
 * screen where it costs no extra step, and asking it here would put a
 * decision ahead of the demo, which is the ordering the funnel rebuild
 * removed. The headline is the one the Meta concept test won on (6.26% CTR,
 * best of five), so the app opens on the same promise the ad made.
 */
export default function Index() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const track = useTrack();
  const snapshot = useSuperwallSnapshot();
  const shown = useRef(false);

  /**
   * Gate the impression on the surface actually being open, not on mount:
   * the SDK preloads surfaces hidden, so a mount-keyed event would count
   * every preload and make the denominator meaningless.
   */
  useEffect(() => {
    if (shown.current || snapshot.paywall === undefined) return;
    shown.current = true;
    // A fresh presentation is a fresh run. Without this, a user who backs out
    // and is re-presented would inherit the previous answers.
    reset();
    track("step", { step: "promise" });
  }, [snapshot.paywall, track]);

  return (
    <div className="page">
      <div className="page__body page__body--hero">
        {/* Its own flex child so the hero centres in the space left over
            after the CTA, rather than a spacer shoving it to the top. */}
        <div className="hero-wrap">
          <div className="hero">
            <CompanionPair />
            <div className="hero__copy">
              <h1 className="page__title page__title--center">{t("promise.title")}</h1>
              <p className="page__sub page__sub--lg page__sub--center">{t("promise.body")}</p>
            </div>
          </div>
        </div>

        <div className="actions">
          <button
            type="button"
            className="btn btn--primary pressable"
            onClick={() => {
              haptics.medium();
              router.push("food-check");
            }}
          >
            {t("promise.cta")}
          </button>
        </div>
      </div>
    </div>
  );
}
