/// Cost controls: a per-device hourly request cap and a global daily spend
/// kill-switch. Both are backed by KV counters with TTLs so they self-expire.
///
/// Caching means repeat scans of the same product cost nothing, so spend
/// tracking only counts real upstream calls (recorded by the router on a miss).

import { Env, intVar, boolVar } from "./types.js";

function hourBucket(now = new Date()): string {
  return now.toISOString().slice(0, 13).replace(/[-T:]/g, ""); // YYYYMMDDHH
}

function dayBucket(now = new Date()): string {
  return now.toISOString().slice(0, 10).replace(/-/g, ""); // YYYYMMDD
}

/// Increment + check the per-device hourly counter. Returns false when over cap.
export async function allowDevice(env: Env, deviceId: string): Promise<boolean> {
  const cap = intVar(env.DEVICE_RATE_PER_HOUR, 60);
  const key = `rl:${deviceId}:${hourBucket()}`;
  const current = intVar((await env.RATE.get(key)) ?? "0", 0);
  if (current >= cap) return false;
  // TTL just past the hour so the bucket disappears on its own.
  await env.RATE.put(key, String(current + 1), { expirationTtl: 3700 });
  return true;
}

/// Returns true when the service should refuse upstream calls — either the
/// manual KILL_SWITCH is on, or today's estimated spend exceeds the limit.
export async function spendBlocked(env: Env): Promise<boolean> {
  if (boolVar(env.KILL_SWITCH)) return true;
  const limit = intVar(env.DAILY_SPEND_LIMIT_CENTS, 2000);
  const key = `spend:${dayBucket()}`;
  const spent = intVar((await env.RATE.get(key)) ?? "0", 0);
  return spent >= limit;
}

/// Record the estimated cost (in cents) of an upstream call against today's
/// budget. Called only on cache misses that actually hit a provider.
export async function recordSpend(env: Env, cents: number): Promise<void> {
  const key = `spend:${dayBucket()}`;
  const spent = intVar((await env.RATE.get(key)) ?? "0", 0);
  await env.RATE.put(key, String(spent + cents), { expirationTtl: 172800 });
}
