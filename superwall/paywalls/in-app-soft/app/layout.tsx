import type { PropsWithChildren } from "react";
import { useActions, useHaptics, useTranslation } from "superwall/hooks";
import { XCircle } from "../components/Icons";
import { DISMISSIBLE } from "../lib/variant";
import "./theme.css";

/**
 * Shared chrome: the close button, which is absolute over the page so the
 * headline doesn't move between the soft and hard variants. The hard variant
 * renders no chrome at all.
 */
export default function Layout({ children }: PropsWithChildren) {
  const { close } = useActions();
  const haptics = useHaptics();
  const { t } = useTranslation();

  return (
    <>
      {DISMISSIBLE ? (
        <button
          type="button"
          className="close pressable"
          aria-label={t("chrome.close")}
          onClick={() => {
            haptics.light();
            close();
          }}
        >
          <XCircle />
        </button>
      ) : null}
      {children}
    </>
  );
}
