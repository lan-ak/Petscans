import { type PropsWithChildren, useState } from "react";
import { useActions, useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ExitOfferDrawer } from "../components/ExitOfferDrawer";
import { ChevronLeft, X } from "../components/Icons";
import "./theme.css";

/**
 * Shared chrome: the navbar and the exit-offer drawer. Routes are names on a
 * stack, so the cross-route state (has the exit offer been shown yet?) lives
 * here.
 *
 * The CTA lives in each page rather than here. `position: sticky` only resolves
 * against a scroll container, and the scroll container is `[data-sw-route]` —
 * one per page. A footer in the layout sits outside every route, so it cannot
 * stick, and it would need its own side padding to line up with page content
 * that already has some. One `.footer`, used in one kind of place.
 */
export default function Layout({ children }: PropsWithChildren) {
  const router = useRouter();
  const { close } = useActions();
  const haptics = useHaptics();
  const { t } = useTranslation();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [offerSpent, setOfferSpent] = useState(false);

  const onPlans = router.name === "plans";

  /**
   * The first dismissal from the plans page buys one exit offer; every
   * dismissal after that closes the paywall for real.
   */
  const dismiss = () => {
    haptics.light();
    if (!offerSpent) {
      setOfferSpent(true);
      setDrawerOpen(true);
      return;
    }
    close();
  };

  const spendOffer = () => {
    setDrawerOpen(false);
    setOfferSpent(true);
  };

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
          ) : null}
          {onPlans ? (
            <button
              type="button"
              className="navbar__button navbar__button--right"
              aria-label={t("chrome.close")}
              onClick={dismiss}
            >
              <X />
            </button>
          ) : null}
        </div>
      </nav>

      {children}

      {drawerOpen ? (
        <ExitOfferDrawer
          onDismissOffer={spendOffer}
          onClosePaywall={() => {
            spendOffer();
            close();
          }}
        />
      ) : null}
    </>
  );
}
