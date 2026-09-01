import { type PropsWithChildren, useState } from "react";
import { useActions, useHaptics } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ExitOfferDrawer } from "../components/ExitOfferDrawer";
import { ChevronLeft, X } from "../components/Icons";
import "./theme.css";

/**
 * Shared chrome: the navbar, the "Continue" footer that carries the first two
 * routes, and the exit-offer drawer. Routes are names on a stack, so the
 * cross-route state (has the exit offer been shown yet?) lives here.
 */
export default function Layout({ children }: PropsWithChildren) {
  const router = useRouter();
  const { close } = useActions();
  const haptics = useHaptics();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [offerSpent, setOfferSpent] = useState(false);

  const onPlans = router.name === "plans";

  const back = () => {
    haptics.light();
    router.back();
  };

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
            <button type="button" className="navbar__button" aria-label="Back" onClick={back}>
              <ChevronLeft />
            </button>
          ) : null}
          {onPlans ? (
            <button
              type="button"
              className="navbar__button navbar__button--right"
              aria-label="Close"
              onClick={dismiss}
            >
              <X />
            </button>
          ) : null}
        </div>
      </nav>

      {children}

      {onPlans ? null : (
        <div className="footer">
          <button
            type="button"
            className="cta pressable"
            onClick={() => {
              haptics.medium();
              router.push(router.name === "index" ? "stakes" : "plans");
            }}
          >
            Continue
          </button>
        </div>
      )}

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
