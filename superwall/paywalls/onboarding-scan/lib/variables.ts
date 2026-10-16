/**
 * Guarded reads of the host-owned variable records.
 *
 * `device`, `user` and `params` are filled in by the SDK and by whatever the
 * app last passed to `setUserAttributes` — the paywall owns none of them, and
 * the host controls the *type* as well as the value. An attribute the app sets
 * as a number today can arrive as a string tomorrow (that is exactly what
 * happens to `searched_food_score` on device), so every read is checked rather
 * than cast.
 *
 * The point of doing this properly: every guarded read is a knob the dashboard
 * can turn without a rebuild, and the studio's Variables panel can drive all of
 * them live while previewing.
 */

/** A non-empty string, or `undefined` — never the literal "undefined". */
export const str = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim() !== "" ? value : undefined;

/** A finite number from either a number or a numeric-looking string. */
export const int = (value: unknown): number | undefined => {
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? undefined : parsed;
  }
  return undefined;
};

/** Booleans cross the bridge as either real booleans or the strings. */
export const bool = (value: unknown): boolean => value === true || value === "true";

/**
 * The pet's name, or a phrase that reads correctly in its place.
 *
 * 146 of the 272 users who reach these paywalls have never set `pet_name`, so
 * the fallback is not an edge case — it is the majority path, and the reason
 * the live dashboard paywall renders "really in 's bowl."
 */
export const petName = (user: Record<string, unknown>): string =>
  str(user.pet_name) ?? "your pet";

/** `"dog" | "cat"`, normalised. 265 of 272 users have it; dogs are 81%. */
export type Species = "dog" | "cat";

export const petSpecies = (user: Record<string, unknown>): Species =>
  str(user.pet_species)?.toLowerCase() === "cat" ? "cat" : "dog";
