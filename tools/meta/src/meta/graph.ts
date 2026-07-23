// Minimal Graph API constants, vendored from PickleGo's functions/src/meta/graph.ts so the
// standalone CLI (scripts/meta/env.ts) resolves the same import path without dragging in the
// Cloud Functions CAPI/webhook runtime. Keep GRAPH_VERSION in sync when Meta deprecates a version.
export const GRAPH_VERSION = 'v25.0';
export const GRAPH_HOST = 'https://graph.facebook.com';
