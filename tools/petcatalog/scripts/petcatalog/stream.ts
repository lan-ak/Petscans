/**
 * Incremental reader for a single-file JSON array.
 *
 * The vendor delivers one 823 MB array on one line, so JSON.parse would need the whole
 * thing (plus the object graph) resident at once. This walks the buffer with a sliding
 * window instead, yielding one object at a time and holding only the tail.
 */

import { createReadStream } from 'node:fs';

/** Find the end of the JSON value starting at `start`, or -1 if it isn't complete yet. */
function endOfValue(buf: string, start: number): number {
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = start; i < buf.length; i++) {
    const c = buf[i];

    if (inString) {
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === '"') inString = false;
      continue;
    }

    if (c === '"') inString = true;
    else if (c === '{' || c === '[') depth++;
    else if (c === '}' || c === ']') {
      depth--;
      if (depth === 0) return i + 1;
    }
  }
  return -1;
}

export async function* streamJsonArray<T = Record<string, unknown>>(
  path: string,
): AsyncGenerator<T> {
  const stream = createReadStream(path, { encoding: 'utf8', highWaterMark: 8 << 20 });
  let buf = '';
  let started = false;

  for await (const chunk of stream) {
    buf += chunk;

    if (!started) {
      const open = buf.indexOf('[');
      if (open < 0) continue;
      buf = buf.slice(open + 1);
      started = true;
    }

    for (;;) {
      let i = 0;
      while (i < buf.length && (buf[i] === ',' || buf[i] === ' ' || buf[i] === '\n' || buf[i] === '\r' || buf[i] === '\t')) i++;
      if (i >= buf.length || buf[i] === ']') {
        buf = buf.slice(i);
        break;
      }
      const end = endOfValue(buf, i);
      if (end < 0) {
        // Value straddles the chunk boundary; keep it and read more.
        buf = buf.slice(i);
        break;
      }
      yield JSON.parse(buf.slice(i, end)) as T;
      buf = buf.slice(end);
    }
  }
}
