import { type PropsWithChildren, useState } from "react";
import { useActions, useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ExitOfferDrawer } from "../components/ExitOfferDrawer";
import { ChevronLeft } from "../components/Icons";
import { X } from "../components/PaywallIcons";
import "./theme.css";

/**
 * Shared chrome for the whole flow: back, and — on the plans step only —
 * close with its one-shot exit offer.
 *
 * (The opening splash is native — `ConfigReadyGate` — because it has to be
 * on screen before Superwall's config, and so this surface, can load.)
 *
 * Close exists on the plans step and nowhere else. Every step before it is
 * onboarding, which gates the app; the plans step is the paywall, and a
 * paywall must be leavable. The first close buys the exit offer, the second
 * closes for real — 276012's rule, carried over with its page.
 *
 * There is deliberately no skip before that. Onboarding gates the app and
 * the pet's name is required, so an exit here would move the dead end rather
 * than remove it. The problem the funnel actually showed is an input problem
 * — 15 users quit at the search step and *none* of them had ever completed a
 * search — and 1.4.8 solves it with a step that needs one tap and no input,
 * not by letting people past it.
 *
 * Being a surface still matters: if the data later says otherwise, putting an
 * exit back is a config change rather than a submission.
 */
export default function Layout({ children }: PropsWithChildren) {
  const router = useRouter();
  const { t } = useTranslation();
  const haptics = useHaptics();
  const { close: closeSurface } = useActions();

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [offerSpent, setOfferSpent] = useState(false);
  const onPlans = router.name === "plans";

  const close = () => {
    haptics.light();
    router.back();
  };

  const dismiss = () => {
    haptics.light();
    if (!offerSpent) {
      setOfferSpent(true);
      setDrawerOpen(true);
      return;
    }
    closeSurface();
  };

  return (
    <>
      <nav className="navbar">
        {router.name === "ingredient" ? (
          // `IngredientDetailSheet`'s bar: an inline title and Done.
          <div className="navbar__toolbar navbar__toolbar--sheet">
            <span className="navbar__spacer" aria-hidden="true" />
            <span className="navbar__title">{t("ingredient.navTitle")}</span>
            <button type="button" className="navbar__done" onClick={close}>
              {t("chrome.done")}
            </button>
          </div>
        ) : router.name === "allergen-search" ? (
          // `IngredientSearchSheet`'s bar: an X to cancel and an inline title.
          <div className="navbar__toolbar navbar__toolbar--sheet">
            <button type="button" className="navbar__button" aria-label={t("chrome.close")} onClick={close}>
              <CloseGlyph />
            </button>
            <span className="navbar__title">{t("search.navTitle")}</span>
            <span className="navbar__spacer" aria-hidden="true" />
          </div>
        ) : onPlans ? (
          // The paywall step: no back (the profile is already handed to the
          // app), only close at the trailing edge.
          <div className="navbar__toolbar">
            <span className="navbar__button" aria-hidden="true" />
            <button
              type="button"
              className="navbar__button navbar__button--close"
              aria-label={t("chrome.close")}
              onClick={dismiss}
            >
              <X size={22} />
            </button>
          </div>
        ) : (
          <div className="navbar__toolbar">
            {/* No back on the personalised result, as natively: the way on
                is Continue, to the plans. */}
            {router.canGoBack() && router.name !== "personalised" ? (
              <button type="button" className="navbar__button" aria-label={t("chrome.back")} onClick={close}>
                <ChevronLeft />
              </button>
            ) : (
              // Holds the row height so the title doesn't shift between routes.
              <span className="navbar__button" aria-hidden="true" />
            )}
          </div>
        )}
      </nav>

      {children}

      {drawerOpen ? (
        <ExitOfferDrawer
          onDismissOffer={() => setDrawerOpen(false)}
          onClosePaywall={() => {
            setDrawerOpen(false);
            closeSurface();
          }}
        />
      ) : null}
    </>
  );
}

/** `xmark` */
function CloseGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}
