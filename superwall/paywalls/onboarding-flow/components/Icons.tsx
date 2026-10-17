/**
 * SF Symbol equivalents for the glyphs the native onboarding uses, drawn as
 * inline SVG at the same optical weight (2px strokes on a 24 box reads as
 * SF Symbols' `.medium`). Inline rather than an icon font: the CSP permits no
 * external image or stylesheet host, and two glyphs do not earn a payload.
 */

interface IconProps {
  size?: number;
}

/** `chevron.left` */
export function ChevronLeft({ size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M15 5 8 12l7 7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** `chevron.right` — the affordance on every brand tile and result row. */
export function ChevronRight({ size = 14 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="m9 5 7 7-7 7"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
