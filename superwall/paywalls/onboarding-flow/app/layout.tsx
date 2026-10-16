import { type PropsWithChildren } from "react";
import { useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ChevronLeft } from "../components/Icons";
import "./theme.css";

/**
 * Shared chrome for the whole flow: just back.
 *
 * There is deliberately no skip, on any screen. Onboarding gates the app and
 * the pet's name is required, so an exit here would move the dead end rather
 * than remove it. The problem the funnel actually showed is an input problem
 * — 15 users quit at the search step and *none* of them had ever completed a
 * search — and that is solved by giving the step three ways in, one of which
 * needs no input at all, not by letting people past it.
 *
 * Being a surface still matters: if the data later says otherwise, putting an
 * exit back is a config change rather than a submission.
 */
export default function Layout({ children }: PropsWithChildren) {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();

  return (
    <>
      <nav className="navbar">
        <div className="navbar__toolbar">
          {router.canGoBack() ? (
            <button
              type="button"
              className="navbar__button"
              aria-label={t("chrome.back")}
              onClick={() => {
                haptics.light();
                router.back();
              }}
            >
              <ChevronLeft />
            </button>
          ) : (
            // Holds the row height so the title doesn't shift between routes.
            <span className="navbar__button" aria-hidden="true" />
          )}
        </div>
      </nav>

      {children}
    </>
  );
}
