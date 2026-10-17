import { useHaptics, useProducts, usePurchase, useTranslation } from "superwall/hooks";
import { has, offerKind, s } from "../lib/offer";

type Props = {
  /** Tapping the plan card or the scrim just puts the drawer away — the offer is spent. */
  onDismissOffer: () => void;
  /** "No thanks, close" dismisses the drawer and the surface with it. */
  onClosePaywall: () => void;
};

/**
 * The one-shot drawer shown the first time someone tries to leave the plans
 * step. Lifted from `onboarding-scan` (276012) unchanged in behaviour.
 *
 * It sells the **tertiary** slot and nothing else does: `annual_39.99`,
 * $39.99/year behind a 30-day $0.99 intro — cheaper than the primary on the
 * page and with a longer runway, so "special offer" is true.
 */
export function ExitOfferDrawer({ onDismissOffer, onClosePaywall }: Props) {
  const { getProduct } = useProducts();
  const { purchase } = usePurchase();
  const haptics = useHaptics();
  const { t } = useTranslation();

  const offer = getProduct("tertiary");
  const { price, period, periodly, trialPeriodDays, trialPeriodPrice } = offer?.variables ?? {};
  const kind = offerKind(offer);
  const priced = has(price, period);

  const description =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice) && priced
      ? t("exitOffer.descPaid", { days: s(trialPeriodDays), trialPrice: s(trialPeriodPrice), price: s(price), period: s(period) })
      : kind === "free" && has(trialPeriodDays) && priced
        ? t("exitOffer.descFree", { days: s(trialPeriodDays), price: s(price), period: s(period) })
        : priced
          ? t("exitOffer.descNone", { price: s(price), period: s(period) })
          : t("exitOffer.descBare");

  const planTitle =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? t("exitOffer.planPaid", { periodly: s(periodly), days: s(trialPeriodDays), trialPrice: s(trialPeriodPrice) })
      : kind === "free" && has(trialPeriodDays)
        ? t("exitOffer.planFree", { periodly: s(periodly), days: s(trialPeriodDays) })
        : has(price)
          ? t("exitOffer.planNone", { periodly: s(periodly), price: s(price) })
          : t("exitOffer.planBare", { periodly: s(periodly) });

  const planDetail = priced
    ? t("exitOffer.planDetail", { price: s(price), period: s(period) })
    : t("exitOffer.planDetailBare");

  const ctaLabel =
    kind === "paid" && has(trialPeriodDays, trialPeriodPrice)
      ? t("exitOffer.ctaPaid", { days: s(trialPeriodDays), trialPrice: s(trialPeriodPrice) })
      : kind === "free" && has(trialPeriodDays)
        ? t("exitOffer.ctaFree", { days: s(trialPeriodDays) })
        : priced
          ? t("exitOffer.ctaNone", { price: s(price), period: s(period) })
          : t("exitOffer.ctaBare");

  return (
    <div className="pw-drawer" role="dialog" aria-label={t("exitOffer.title")}>
      <button
        type="button"
        className="pw-drawer__scrim"
        aria-label={t("exitOffer.dismissAria")}
        onClick={onDismissOffer}
      />
      <div className="pw-drawer__sheet">
        <div className="pw-drawer__head">
          <h2 className="pw-drawer__title">{t("exitOffer.title")}</h2>
          <p className="pw-drawer__sub">{description}</p>
        </div>

        <button
          type="button"
          className="pw-drawer__plan"
          onClick={() => {
            haptics.light();
            onDismissOffer();
          }}
        >
          <span className="pw-drawer__plan-title">{planTitle}</span>
          <span className="pw-drawer__plan-detail">{planDetail}</span>
        </button>

        <button
          type="button"
          className="btn btn--primary pressable"
          onClick={async () => {
            haptics.medium();
            const result = await purchase("tertiary");
            if (result.status === "completed") haptics.success();
          }}
        >
          {ctaLabel}
        </button>

        <button
          type="button"
          className="pw-drawer__dismiss"
          onClick={() => {
            haptics.light();
            onClosePaywall();
          }}
        >
          {t("exitOffer.dismiss")}
        </button>
      </div>
    </div>
  );
}
