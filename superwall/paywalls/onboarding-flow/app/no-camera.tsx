import { useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { useCallbacks } from "../lib/callbacks";
import { state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * Camera permission denied.
 *
 * This state does not exist on 1.4.6 — a denial there leaves the mandatory
 * search step as the only way forward, which is the path we know 15 of 15
 * quitters failed. So the example is the *primary* action here and search is
 * secondary: the person who just declined the camera is not the person to
 * hand a keyboard to.
 */
export default function NoCamera() {
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
            <h1 className="page__title">{t("noCamera.title")}</h1>
            <p className="page__sub">{t("noCamera.body")}</p>
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
            {t("noCamera.example")}
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
            {t("noCamera.search")}
          </button>
        </div>
      </div>
    </div>
  );
}
