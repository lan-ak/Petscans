import { useEffect, useState } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { Camera, Search } from "../components/Icons";
import { SpeciesPicker } from "../components/SpeciesPicker";
import { type Species, useCallbacks } from "../lib/callbacks";
import { state } from "../lib/state";
import { useTrack } from "../lib/track";

/**
 * The replacement for native onboarding step 1.
 *
 * Three ways in on one screen, rather than a yes/no question screen in front
 * of them. A question costs a step and returns nothing; two buttons give the
 * same branch, the same signal about which path people take, and no extra
 * place to quit before any value has been delivered.
 *
 * Order is deliberate. Scan is primary because it is the product — only 5 of
 * 62 new users ever completed a scan in the 30 days to 2026-10-04, in an app
 * called PetScans. Search drops to secondary. The third line is the one that
 * matters most: someone without the bag in front of them reaches the payoff
 * with no input at all, which is what "I don't have it on me" should mean.
 * Routing them to type a brand name from memory — harder than searching with
 * the bag in hand — is the mistake the current step makes.
 */
export default function FoodCheck() {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const call = useCallbacks();
  const track = useTrack();
  const [species, setSpecies] = useState<Species | null>(state.species);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    track("step", { step: "food_check" });
  }, [track]);

  const chooseSpecies = (next: Species) => {
    haptics.selection();
    // Tapping the selected one again clears it. The native picker made this a
    // binding with a `.dog` default and the comment on `chosenSpecies`
    // records what that cost: the species every demo was scored against was
    // an assumption nobody had made. Unselected stays a real state.
    const value = species === next ? null : next;
    setSpecies(value);
    state.species = value;
  };

  const goSearch = () => {
    haptics.light();
    track("path_chosen", { path: "search" });
    router.push("search");
  };

  /**
   * Permission, then the native scanner. Both branches of the prompt are
   * real paths: a denial is an ordinary outcome, and it must not land on
   * search — that is the path 15 of 15 quitters already failed.
   */
  const goScan = async () => {
    if (busy) return;
    haptics.medium();
    track("path_chosen", { path: "scan" });
    setBusy(true);

    const permission = await call.requestPermission("camera");
    track("camera_permission", { granted: permission });

    if (permission !== "granted") {
      setBusy(false);
      router.push("no-camera");
      return;
    }

    const result = await call.scan(species);
    setBusy(false);

    if (!result.ok) {
      track("scan_abandoned");
      return; // Scanner dismissed. Stay put; the three options are still here.
    }

    if (!result.value.found || !result.value.food) {
      state.missedTerm = result.value.barcode ?? "";
      track("scan_not_found", { term: state.missedTerm });
      router.push("not-found");
      return;
    }

    state.food = result.value.food;
    state.isExample = false;
    track("result_shown", { path: "scan", score: result.value.food.score });
    router.push("result");
  };

  /** The zero-input path: a real, scored row from the bundled catalogue. */
  const goExample = async () => {
    if (busy) return;
    haptics.light();
    track("path_chosen", { path: "example" });
    setBusy(true);

    const result = await call.example(species);
    setBusy(false);
    if (!result.ok) return;

    state.food = result.value;
    state.isExample = true;
    track("result_shown", { path: "example", score: result.value.score });
    router.push("result");
  };

  return (
    <div className="page">
      <div className="page__head">
        <h1 className="page__title">{t("index.title")}</h1>
        <p className="page__sub">{t("index.subtitle")}</p>
      </div>

      <div className="page__body">
        {/*
          Asked out loud, as a heading rather than a bare control. The native
          screen learned this: users walked past the picker because the
          headline only talked about food.
        */}
        <div className="species-block">
            <p className="section-label">{t("index.species")}</p>
            <SpeciesPicker value={species} onPick={chooseSpecies} />
        </div>

        <div className="actions">
          <button type="button" className="btn btn--primary pressable" onClick={goScan} disabled={busy}>
            {busy ? <span className="btn__spinner" /> : <Camera />}
            {busy ? t("index.opening") : t("index.scan")}
          </button>

          <button type="button" className="btn btn--secondary pressable" onClick={goSearch}>
            <Search />
            {t("index.search")}
          </button>

          <button type="button" className="btn btn--tertiary" onClick={goExample} disabled={busy}>
            {t("index.example")}
          </button>
        </div>
      </div>
    </div>
  );
}
