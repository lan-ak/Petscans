/**
 * `AvoidanceGroup.icon`, drawn as SVG — SF Symbols don't exist in a webview.
 * Filled, in `currentColor`, at `PetIconSize.small`.
 *
 * sparkles · paintpalette.fill · flask.fill · exclamationmark.triangle.fill ·
 * cube.fill · fork.knife · leaf.fill · drop.fill
 */
export function GroupIcon({ id, size = 24 }: { id: string; size?: number }) {
  const p = { width: size, height: size, viewBox: "0 0 24 24", "aria-hidden": true as const };
  switch (id) {
    case "ultraProcessed":
      return (
        <svg {...p} fill="currentColor">
          <path d="M10 3l1.6 5.4L17 10l-5.4 1.6L10 17l-1.6-5.4L3 10l5.4-1.6z" />
          <path d="M18 14l.8 2.2L21 17l-2.2.8L18 20l-.8-2.2L15 17l2.2-.8z" />
          <path d="M17.5 2.5l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z" />
        </svg>
      );
    case "artificialColours":
      return (
        <svg {...p}>
          <path
            fill="currentColor"
            fillRule="evenodd"
            d="M12 3C6.5 3 2.5 6.9 2.5 11.6c0 4.1 3.3 7.4 7.4 7.4h1.3c1 0 1.6-1.1 1.1-2a1.5 1.5 0 0 1 1.3-2.3h2.2c3 0 5.7-2.3 5.7-5.6C21.5 5.8 17.3 3 12 3zM7 12.2a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2zm3-4a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2zm5 0a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2zm2.6 3.6a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2z"
          />
        </svg>
      );
    case "artificialPreservatives":
      return (
        <svg {...p} fill="currentColor">
          <path d="M9 2.5h6v1.8h-1v4.9l5.6 9.4A2 2 0 0 1 17.9 21.5H6.1a2 2 0 0 1-1.7-2.9L10 9.2V4.3H9z" />
        </svg>
      );
    case "commonAllergens":
      return (
        <svg {...p}>
          <path fill="currentColor" d="M12 2.9c.6 0 1.2.33 1.5.88l8 14.1A1.7 1.7 0 0 1 20 20.5H4a1.7 1.7 0 0 1-1.5-2.6l8-14.1c.3-.55.9-.88 1.5-.88z" />
          <path d="M12 9v4.6" stroke="var(--group-ink, #fff)" strokeWidth="2.2" strokeLinecap="round" />
          <circle cx="12" cy="17" r="1.25" fill="var(--group-ink, #fff)" />
        </svg>
      );
    case "addedSugars":
      return (
        <svg {...p} fill="currentColor">
          <path d="M12 2.5l8.5 4.6v9.8L12 21.5l-8.5-4.6V7.1z" opacity="0.85" />
          <path d="M12 2.5l8.5 4.6L12 11.7 3.5 7.1z" />
        </svg>
      );
    case "meatByproducts":
      return (
        <svg {...p} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
          <path d="M6 3v6M9 3v6M6 9a1.5 1.5 0 0 0 3 0M7.5 9v12" />
          <path d="M17 21V3c-2.2 1.3-3.5 4-3.5 7.5V13H17" fill="currentColor" stroke="none" />
          <path d="M17 13v8" />
        </svg>
      );
    case "grainFillers":
      return (
        <svg {...p} fill="currentColor">
          <path d="M20.5 3.5C10 3.5 4 8.5 4 15.5c0 1.4.3 2.6.8 3.6L3 21l1.4 1.4 1.9-1.9c1 .5 2.2.8 3.6.8 7 0 11.6-6.5 10.6-17.8zM8 18.5c2-4.5 5-7.5 9-9.5-3.2 2.6-5.6 5.8-7.3 10z" />
        </svg>
      );
    case "gumsThickeners":
      return (
        <svg {...p} fill="currentColor">
          <path d="M12 2.5c3.6 4.6 6.5 8.3 6.5 12a6.5 6.5 0 0 1-13 0c0-3.7 2.9-7.4 6.5-12z" />
        </svg>
      );
    default:
      return null;
  }
}
