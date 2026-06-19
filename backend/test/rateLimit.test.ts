import { describe, it, expect } from "vitest";
import { allowDevice, spendBlocked, recordSpend } from "../src/rateLimit.js";
import { makeEnv } from "./helpers.js";

describe("rate limiting", () => {
  it("allows up to the per-device hourly cap then blocks", async () => {
    const env = makeEnv({ DEVICE_RATE_PER_HOUR: "3" });
    expect(await allowDevice(env, "dev1")).toBe(true);
    expect(await allowDevice(env, "dev1")).toBe(true);
    expect(await allowDevice(env, "dev1")).toBe(true);
    expect(await allowDevice(env, "dev1")).toBe(false);
  });

  it("tracks devices independently", async () => {
    const env = makeEnv({ DEVICE_RATE_PER_HOUR: "1" });
    expect(await allowDevice(env, "dev1")).toBe(true);
    expect(await allowDevice(env, "dev2")).toBe(true);
    expect(await allowDevice(env, "dev1")).toBe(false);
  });
});

describe("spend kill-switch", () => {
  it("blocks when the manual kill-switch is on", async () => {
    expect(await spendBlocked(makeEnv({ KILL_SWITCH: "on" }))).toBe(true);
  });

  it("blocks once the daily spend limit is reached", async () => {
    const env = makeEnv({ DAILY_SPEND_LIMIT_CENTS: "5" });
    expect(await spendBlocked(env)).toBe(false);
    await recordSpend(env, 3);
    expect(await spendBlocked(env)).toBe(false);
    await recordSpend(env, 2);
    expect(await spendBlocked(env)).toBe(true);
  });
});
