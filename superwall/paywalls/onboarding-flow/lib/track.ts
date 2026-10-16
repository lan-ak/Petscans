import { useActions } from "superwall/hooks";

/**
 * The instrumentation this flow has never had.
 *
 * `searched_food` is only written on success, so today "never typed a
 * character", "typed something the catalogue doesn't carry" and "the search
 * threw" all produce byte-identical telemetry — which is why the only thing
 * the funnel can say about the 15 users who quit here is that 0 of them
 * completed a search. These events separate those three.
 *
 * One placement name carrying an `event` param, not a placement per event.
 * That is the convention `OnboardingView.logStep` already set, for the reason
 * written there: registering a placement presents a paywall if one is ever
 * attached to that name on the dashboard, and a single name is far easier to
 * keep out of campaigns than eight.
 *
 * Query it the same way the step funnel is queried:
 *   JSONExtractString(props, 'event') FROM sw.events_rep
 *   WHERE name = 'onboarding_flow_event'
 */
export type FoodCheckEvent =
  /** A route rendered. `step` carries which. The funnel's denominators. */
  | "step"
  /** A route was completed and the user moved on. */
  | "step_done"
  /** A path was chosen: scan, search or example. */
  | "path_chosen"
  /** A query was actually submitted — the thing we currently cannot see. */
  | "search_attempted"
  /** Submitted, ran, returned nothing. Today indistinguishable from silence. */
  | "search_no_results"
  /** The catalogue read threw or the bridge failed. */
  | "search_failed"
  /** Camera prompt answered. `granted` carries the outcome. */
  | "camera_permission"
  /** A barcode read cleanly but isn't in the catalogue. The coverage signal. */
  | "scan_not_found"
  /** The scanner was opened and dismissed without a read. */
  | "scan_abandoned"
  /** A food was scored and shown. */
  | "result_shown"
  /** Reached the end and handed off to `onboarding_complete`. */
  | "completed";

export interface TrackParams {
  /** Which route. Query the funnel on this, not on route order. */
  step?: string;
  /** The query or barcode that missed. The catalogue backlog, one row at a time. */
  term?: string;
  path?: "scan" | "search" | "example";
  granted?: string;
  score?: number;
  results?: number;
  /** Allergens or avoidance groups picked, for the question pages. */
  count?: number;
  reason?: string;
}

export function useTrack() {
  const { customPlacement } = useActions();

  return (event: FoodCheckEvent, params: TrackParams = {}) => {
    // Undefined values would serialise as nulls the SQL has to special-case.
    const clean: Record<string, string | number> = { event };
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== "") clean[k] = v as string | number;
    }
    customPlacement("onboarding_flow_event", clean);
  };
}
