import type { PropsWithChildren } from "react";
import { useActions, useHaptics, useTranslation } from "superwall/hooks";
import { useRouter } from "superwall/navigation";
import { ChevronLeft, X } from "./Icons";
import "../app/theme.css";

/**
 * `dismissible={false}` is the hard variant (`onboarding-scan-hard`): no close on the
 * plans step, so the only ways out are buying or restoring.
 *
 * Shared chrome: the navbar and the exit-offer drawer. Routes are names on a
 * stack, so the cross-route state (has the exit offer been shown yet?) lives
 * here.
 *
 * The CTA lives in each page rather than here. `position: sticky` only resolves
 * against a scroll container, and the scroll container is `[data-sw-route]` —
 * one per page. A footer in the layout sits outside every route, so it cannot
 * stick, and it would need its own side padding to line up with page content
 * that already has some. One `.footer`, used in one kind of place.
 *
 * The stack is two pages now — result, then plans. It used to be three, with a
 * "stakes" page in between; see `index.tsx` for why that went.
 */
export function Chrome({
  children,
  dismissible = true,
}: PropsWithChildren<{ dismissible?: boolean }>) {
  const router = useRouter();
  const { close } = useActions();
  const haptics = useHaptics();
  const { t } = useTranslation();

  const onPlans = router.name === "plans";

  const back = () => {
    haptics.light();
    router.back();
  };

  const dismiss = () => {
    haptics.light();
    close();
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
              onClick={back}
            >
              <ChevronLeft />
            </button>
          ) : null}
          {onPlans && dismissible ? (
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

    </>
  );
}
