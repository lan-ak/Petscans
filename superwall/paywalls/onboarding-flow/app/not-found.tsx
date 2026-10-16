import { useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { useCallbacks } from "../lib/callbacks";
import { state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * A barcode that read cleanly but isn't in the catalogue.
 *
 * This is the state that decides whether the whole redesign works. If
 * coverage is the real problem rather than input friction, scanning fails
 * exactly where typing does — so the miss is echoed back (the moment reads
 * as handled, not broken) and logged with the barcode, which turns every
 * failure into a row of the catalogue backlog.
 *
 * Two lines of copy top-aligned on a phone screen reads as an error page
 * with the bottom fallen out, so the block is centred and the actions stay
 * anchored. Same reasoning as `standardChrome`.
 */
export default function NotFound() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const call = useCallbacks();
  const track = useTrack();
  const [busy, setBusy] = useState(false);

  const useExample = async () => {
    if (busy) return;
    haptics.light();
    setBusy(true);
    const result = await call.example(state.species);
    setBusy(false);
    if (!result.ok) return;

    state.food = result.value;
    state.isExample = true;
    track("result_shown", { path: "example", score: result.value.score });
    router.push("result");
  };

  return (
    <div className="page">
      <div className="page__body">
        <div className="centre-wrap">
          <div className="recover">
            <h1 className="page__title">{t("notFound.title")}</h1>

            {state.missedTerm ? (
              <div className="echo">
                <span className="echo__key">{t("notFound.barcodeKey")}</span>
                <span className="echo__value">{state.missedTerm}</span>
              </div>
            ) : null}

            <p className="page__sub">{t("notFound.body")}</p>
          </div>
        </div>

        <div className="actions">
          <button
            type="button"
            className="btn btn--primary"
            onClick={useExample}
            disabled={busy}
          >
            {busy ? <span className="btn__spinner" /> : null}
            {t("notFound.similar")}
          </button>
          <button
            type="button"
            className="btn btn--secondary"
            onClick={() => {
              haptics.light();
              track("path_chosen", { path: "search" });
              router.push("search");
            }}
          >
            {t("notFound.search")}
          </button>
        </div>
      </div>
    </div>
  );
}
