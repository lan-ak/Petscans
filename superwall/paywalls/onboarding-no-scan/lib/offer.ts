import type { SuperwallProduct } from "superwall";

/**
 * The three states every price string on this paywall forks on, mirroring the
 * dashboard paywall's `trialPeriodText` / `rawTrialPeriodPrice` conditions:
 *
 * - `none` — no introductory offer at all
 * - `free` — a free trial
 * - `paid` — a paid intro period (e.g. 7 days for $0.99)
 */
export type OfferKind = "none" | "free" | "paid";

export const offerKind = (product?: SuperwallProduct): OfferKind => {
  const trialText = product?.variables.trialPeriodText;
  if (!trialText) return "none";
  // Numeric-looking variables arrive as strings on device.
  return Number(product?.variables.rawTrialPeriodPrice ?? 0) !== 0 ? "paid" : "free";
};

/** `undefined` until the SDK delivers store data — never render a raw blank. */
export const num = (value?: string | number): number | undefined => {
  if (value === undefined || value === "") return undefined;
  const parsed = Number(value);
  return Number.isNaN(parsed) ? undefined : parsed;
};

/**
 * Product data is SDK-owned and simply absent until the store answers — in the
 * studio it is absent for good. Any string that interpolates a variable must
 * render nothing rather than the word "undefined".
 */
export const has = (...values: (string | number | undefined)[]): boolean =>
  values.every((value) => value !== undefined && value !== "");

/**
 * Coerce a store variable for interpolation into `t()`.
 *
 * Every call site is already inside a `has(...)` guard, so the fallback is
 * unreachable — but `has` narrows at runtime and not in the type system, and
 * the compiler is right that a bare `string | undefined` must never reach a
 * message. Spelling the empty string out keeps "undefined" off the screen even
 * if a guard is ever edited away.
 */
export const s = (value?: string | number): string | number => value ?? "";
