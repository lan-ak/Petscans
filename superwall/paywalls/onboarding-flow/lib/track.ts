import { useCallback, useEffect, useRef } from "react";
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
  /** A route was first shown. `step` carries which. The funnel's denominators. */
  | "step"
  /** A food was picked and its result shown. `term` is the GTIN. */
  | "result_shown"
  /** Reached the end and handed off to `onboarding_complete`. */
  | "completed";

/*
 * Eight events for a full run: six `step`s, one `result_shown`, one
 * `completed`. Each is a `register` on the device, so this is kept to what
 * the funnel query reads. Gone, because another event already said it:
 * `step_done` (the next `step`), `path_chosen` (there is one path, and
 * `result_shown` fires on the same tap), and a `step` per ingredient sheet,
 * which counted a glance at "Biotin" as a funnel step.
 */

export interface TrackParams {
  /** Which route. Query the funnel on this, not on route order. */
  step?: string;
  /** The query or barcode that missed. The catalogue backlog, one row at a time. */
  term?: string;
  path?: "sample";
  score?: number;
}

/**
 * Stable for the life of the page. It used to be a new function on every
 * render, and each page logs its `step` in an effect keyed on it — so every
 * re-render re-fired the step: each keystroke in the name field, and every
 * page still mounted under the top of the stack. One run sent 70 placements,
 * `food_check` alone 25 times.
 */
export function useTrack() {
  const { customPlacement } = useActions();
  const send = useRef(customPlacement);
  send.current = customPlacement;

  return useCallback((event: FoodCheckEvent, params: TrackParams = {}) => {
    // Undefined values would serialise as nulls the SQL has to special-case.
    const clean: Record<string, string | number> = { event };
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== "") clean[k] = v as string | number;
    }
    send.current("onboarding_flow_event", clean);
  }, []);
}

/** Logs `step` once, the first time the page is shown — never per render. */
export function useStep(step: string, params: Omit<TrackParams, "step"> = {}) {
  const track = useTrack();
  const sent = useRef(false);
  const latest = useRef(params);
  latest.current = params;
  useEffect(() => {
    if (sent.current) return;
    sent.current = true;
    track("step", { step, ...latest.current });
  }, [step, track]);
}
