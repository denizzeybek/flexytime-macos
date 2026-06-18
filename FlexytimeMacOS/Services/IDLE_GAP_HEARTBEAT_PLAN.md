# Idle-Gap Heartbeat Plan

> **TL;DR.** The agent only emits a new `ViewEvent` on **ProcessName / URL change**. When the user reads a long passage in the same app (e.g. iTerm, VSCode) without keyboard input for 60s+, `onInputTimedEvent` closes the active view at the last-input timestamp and sets `activeView = nil`. From the backend's perspective this looks like a **gap** between two views of the same app. Backend's `interpolateGap` credits up to `ALWAYS_ON_EXECUTABLE_THRESHOLD_SECONDS = 10 min` of that gap to the AlwaysOn allocation, then **dumps the rest into the `Idle` / `Logout` sentinels** (`Domain = None`). Those sentinels are excluded from "Work", so a 4-hour reading-heavy iTerm session shows up as ~2h Work on the panel.
>
> The fix lives in **both** the agent (emit periodic heartbeat views while a foreground app stays active) **and** the backend (treat heartbeat-tagged views as continuation of the prior allocation, suppress `interpolateGap` for them). Wire format is additive — old clients are unaffected.

Last hit: **2026-06-15** (Deniz). Diagnosed against company `c4d59ed6-…`, user `6a20c191…`. Today's 7,238s Work / 12,841s `Idle+Logout` split made the problem reproducible.

---

## Current behavior (read these before changing anything)

### Agent — `Services/ActivityCollector.swift`

The polling timer fires every `pollingInterval = 1s` and runs `onTimerTick()`:

- **Every 1s** → `activityEvent()`
  - Reads foreground window via `WindowTracker.getCurrentWindow()`.
  - If `activeView == nil` and `secondsSinceLastInput < idleThreshold` → opens a new view.
  - If `activeView.processName != window.appName` → closes the active view + opens a new one.
  - If browser and URL changed → close + reopen.
  - **Otherwise: NO-OP.** The active view sits with its original `time`; no progress signal is sent.
- **Every 15s** → `onInputTimedEvent()`
  - If `secondsSinceLastInput >= idleThreshold (60s)` → closes the active view at `Date() - idleSeconds` and clears `activeView = nil`. That trims the silent tail off the view's `expireTime`.
- **Every 60s** → `onWindowTimedEvent()` flushes accumulated views to the API.
- **Every 900s** → calendar sync (irrelevant here).

`IdleDetector.secondsSinceLastInput()` reads `CGEventSource.secondsSinceLastEventType(.hidSystemState, …)`.

### Backend — `apps/scheduler/src/modules/perform/perform.job.ts`

For each `view` in `usage.Views`:

1. If there's a stored `lastClockEnd` from the previous view, `interpolateGap(lastClockEnd → view.Time)` runs first. That helper:
   - If `lastAllocation.AlwaysOn`: credit `min(gapSeconds, ALWAYS_ON_EXECUTABLE_THRESHOLD_SECONDS - lastSpent)` of the gap to that allocation. **Threshold = 10 min (600s)**.
   - Whatever remains → `idleSentinel` if remaining ≤ `LOGOUT_THRESHOLD_SECONDS (15 min)` else `logoutSentinel`. **Both sentinels have `Domain = PerformAllocationDomain.None (0)`.**
2. Classify `view` against existing `TraceAllocation`s.
3. If no match and `BusinessWorkHours.Unclassified !== false`: auto-create `TraceAllocation { Feature=Executable|Web, Name=ProcessName|host, Query=ProcessName|host, Domain=Unclassified, AlwaysOn=false }` (see also `TryCreateExecutableAllocation` parity work) and reuse it for the rest of the trace.
4. Write `TraceClock` + aggregate row.

### Panel — what shows up

`TraceDailyGraph` rows for 2026-06-15, this user:

| Domain enum (`libs/data/src/enums/perform-allocation-domain.enum.ts`) | Value | Seconds | h:m:s | Notes |
|---|---|---|---|---|
| `None` | 0 | 17,582 | 4h 53m | Idle + Logout sentinels |
| `Unclassified` | 1 | 17 | 17s | FaceTime |
| `Work` | 4 | 7,838 | **2h 10m 38s** | What the panel shows |

`TraceClock` breakdown for the same range (allocation-grouped):

| Allocation | Domain | AlwaysOn | Total | Views |
|---|---|---|---|---|
| Logout (sentinel) | None | — | 8,988s = 2h 30m | 3 |
| iTerm2 | Work | ✅ | 5,755s = 1h 36m | 55 |
| Idle (sentinel) | None | — | 3,853s = 1h 04m | 16 |
| Code | Work | ✅ | 1,078s = 18m | 18 |
| localhost | Work | — | 402s = 6m | 38 |
| FaceTime | Unclassified | ✅ | 17s | 3 |
| www.google.com | Work | — | 3s | 1 |

**The 16 Idle stretches and 3 Logout stretches are all "user reading a long passage in iTerm without keystrokes" episodes.** They are real (the agent never lied), but they cap at the 10-min budget per gap so any long reading episode partially leaks into `Idle` / `Logout`.

---

## What we want

When the foreground app stays the same AND the user hasn't moved into **deep idle** (away-from-keyboard threshold, suggest 10 min), the agent should emit a periodic "still here" view so the backend never sees a multi-minute gap. The backend should classify these heartbeat views with the same allocation as the prior view; the existing `interpolateGap` budget cap stops being relevant.

When the user goes deep idle (no input for ≥ deep-idle threshold), the agent **stops** heartbeating. The backend then sees a real gap and falls through to `Idle` / `Logout` sentinels — which is correct: the user genuinely left.

### Who actually changes behavior

**Only `AlwaysOn=true` allocations gain new time.** Everyone else is left at today's behavior:

| Allocation type | Today | After this plan |
|---|---|---|
| `AlwaysOn=true` (iTerm, VSCode marked as such) | First 10 min of any input-silent gap counted as Work; remainder spills to `Idle`/`Logout` sentinels | Heartbeat fills the silence → entire silent stretch (up to `deepIdleThreshold`) counted as Work. **Gain: the multi-hour reading sessions.** |
| `AlwaysOn=false` (Reddit, Twitter, any auto-Unclassified app) | View closes at 60s of silence; gap → `Idle` sentinel | Same end state — heartbeat with `idleAge ≥ 60s` is dropped by BE drop guard, the gap is filled by `interpolateGap` → `Idle` sentinel. **Bit-for-bit parity** with today. |
| Newly auto-created (`Unclassified`, `AlwaysOn=false`) | Auto-created on first miss; counted while user types | Same. First view counts; subsequent silent heartbeats dropped. |
| Mac sleep / agent crash | Long gap → `Logout` sentinel | Same — no heartbeats during sleep, the existing `LOGOUT_THRESHOLD_SECONDS` path handles it. |
| Old Windows agent (no `Heartbeat` property) | Today's `interpolateGap` budget path | Identical — BE drop guard checks `Heartbeat === '1'`, missing property means it doesn't trigger. |

So practically: **the only number that changes on the panel is the Work bucket for users who marked their development apps `AlwaysOn=true`** — and it goes up because long reading/thinking stretches inside those apps stop leaking to `Idle`/`Logout`.

---

## Design — Agent

### Config (`Models/Configuration.swift`)

Two new constants:

```swift
let heartbeatInterval: TimeInterval = 30  // emit a fresh view this often while foreground stays put
let deepIdleThreshold: TimeInterval = 600 // 10 min: stop heartbeating, mark AFK, fall back to v1 behavior
```

(Both must be configurable from the same source the rest of the config reads — `Configuration.json` if that's where defaults live; otherwise hard-coded here is fine for now.)

### `ActivityCollector.activityEvent()` — heartbeat branch

Add a new `else if` to the existing chain (after the URL-changed branch):

```swift
else if activeView?.processName == window.appName {
    let now = Date()
    let inSession = now.timeIntervalSince(activeView!.time)
    let idleAge = idleDetector.secondsSinceLastInput()
    let shouldHeartbeat = inSession >= configuration.heartbeatInterval
                       && idleAge < configuration.deepIdleThreshold
    if shouldHeartbeat {
        closeActiveView(at: now)
        createView(window: window)
        activeView?.properties["Heartbeat"] = "1"
        activeView?.properties["IdleAgeSec"] = String(Int(idleAge))
    }
}
```

- Closes the active view (which captures the previous heartbeat-interval as a complete view) and opens a new one starting at `now`.
- Tags it with `Heartbeat = "1"` so the backend can distinguish a "still here" view from a normal user-input-driven view.
- Records the current `IdleAgeSec` — the backend uses this to decide whether to drop the view for non-AlwaysOn allocations.

### `ActivityCollector.onInputTimedEvent()` — relax the AFK close

Today: idle ≥ 60s → close + clear `activeView = nil`. Change to:

```swift
private func onInputTimedEvent() {
    let seconds = idleDetector.secondsSinceLastInput()
    guard seconds >= configuration.deepIdleThreshold else { return }  // was: configuration.idleThreshold
    guard activeView != nil else { return }

    FlexLog.info("Deep AFK detected (\(Int(seconds))s idle)", category: .services)
    let lastInput = Date().addingTimeInterval(-seconds)
    closeActiveView(at: lastInput)
    currentURL = nil
}
```

Why: the heartbeat path is now responsible for surfacing "user idle but app open" to the backend (via `IdleAgeSec`). Closing the view at 60s is no longer needed; we only close on **deep** idle, which signals real AFK. After deep-idle close, no more heartbeats fire until the user types again.

### `ViewEvent.properties`

Already a `[String: String]`. **No schema change required.** Backend ignores unknown properties today; the new keys are additive.

### Agent tests

`Tests/ActivityCollectorTests.swift` (sketch):

- **`testHeartbeatOpensFreshViewEveryN`**: simulate foreground iTerm for 90s with sub-deepIdle silence, assert `views` array contains 3 entries (`30s`, `30s`, `30s`) all with `Heartbeat = "1"`.
- **`testHeartbeatStopsAtDeepIdle`**: simulate idle = 700s; assert last view closed at `t - 700`, no further heartbeats fire until the next input.
- **`testFirstHeartbeatCarriesIdleAge`**: assert `properties["IdleAgeSec"]` reflects the actual silence at heartbeat time.
- **`testProcessChangeStillClosesAndReopensInsteadOfHeartbeating`**: regression — when the foreground app changes, the existing branch wins (not the heartbeat branch).

---

## Design — Backend

`apps/scheduler/src/modules/perform/perform.job.ts`, in the view-processing loop (around the existing `classifier.classify`):

```ts
const isHeartbeat = view.Properties['Heartbeat'] === '1';
const idleAgeSec = Number(view.Properties['IdleAgeSec'] ?? '0');

let allocation = this.classifier.classify(view, allocations);
if (allocation) {
  if (isHeartbeat && !allocation.AlwaysOn && idleAgeSec >= LEGACY_IDLE_THRESHOLD) {
    // Non-AlwaysOn app + user is silent. Drop the view but DON'T touch
    // lastClockEnd / lastAllocation / lastSpent — let the next non-dropped
    // view trigger interpolateGap, which will fill the dropped span with
    // the Idle sentinel (matching today's legacy behavior bit-for-bit).
    continue;
  }
} else {
  // existing miss path — Unclassified allowed → create allocation; otherwise drop.
}
// Write clock + aggregate as before.
```

`LEGACY_IDLE_THRESHOLD` = `60` (the same constant Mac's old `idleThreshold` enforced — keep it as a backend constant so the BE policy is independent of any single client's setting).

### Why this preserves non-AlwaysOn parity

Worked example for `Reddit` (AlwaysOn=false), user types at `t=0` then goes silent:

| Time | What agent sends | What BE does | Stored |
|---|---|---|---|
| 0–30s | View {Reddit, Heartbeat=1, IdleAgeSec=30} | idle < 60 → keep | 30s Reddit |
| 30–60s | View {Reddit, Heartbeat=1, IdleAgeSec=60} | idle = 60 → **drop**, state preserved | — |
| 60–90s | View {Reddit, Heartbeat=1, IdleAgeSec=90} | drop, state preserved | — |
| 90s–300s | (no views — agent stopped at deep-idle threshold) | — | — |
| 300–330s | User types again. View {Reddit, Heartbeat=1, IdleAgeSec=0} | idle < 60 → keep. `interpolateGap(30s → 300s)` = 270s, lastAllocation=Reddit !AlwaysOn → 270s `Idle` sentinel. Then write Reddit 300–330. | 270s Idle, 30s Reddit |

Total: 60s Reddit + 270s Idle = 330s tracked. That's exactly what today's legacy code produces for the same scenario (view-close-at-60s-silence + interpolateGap fills the rest with Idle sentinel). The only difference is granularity: today writes one 60s Reddit clock; we write two 30s ones.

### Why `interpolateGap` doesn't need to change

- Old clients (no heartbeat) still produce gaps → `interpolateGap` still runs with its 10-min budget.
- New clients (heartbeat) produce no gap (or ≤ 30s gap during network jitter) → `interpolateGap` is a no-op.
- Real deep-idle scenarios (agent crashed, machine slept) produce a long gap and the existing `LOGOUT_THRESHOLD_SECONDS` sentinel handling kicks in. Correct.

### Backend tests (`apps/scheduler/src/modules/perform/perform.job.spec.ts`)

- **`emits Work for AlwaysOn allocation under heartbeat`**: feed two heartbeat views back-to-back for iTerm; assert `TraceDailyGraph` row gains seconds at `Domain = Work`, no Idle sentinel writes.
- **`drops heartbeat view for non-AlwaysOn allocation past LEGACY_IDLE_THRESHOLD`**: feed a heartbeat view tagged `IdleAgeSec = 90` against a non-AlwaysOn `Reddit` allocation; assert the next gap is filled by Idle sentinel as before.
- **`accepts old client without Heartbeat property`**: feed an unflagged view; assert behaviour identical to today's code path (regression guard).

---

## Phasing

| Phase | Scope | Owner | Est. |
|---|---|---|---|
| 1 | Agent: heartbeat in `ActivityCollector`, idle-threshold relaxation, properties addition + tests | Mac | 0.5–1 day |
| 2 | Backend: heartbeat-aware drop guard in `perform.job.ts` + spec | Web (`flexyweb-nest`) | 0.5 day |
| 3 | Sign + ship a Mac DMG (notarization) | Mac | 0.5 day |
| 4 | 24h soak on **one** tenant: compare `TraceDailyGraph` baseline vs new agent | Web | 1 day |
| 5 | Wider rollout | Mac | — |

**No DB migration. No wire schema change.** The hook in `flexyweb-nest/.claude/rules/15-agent-wire-compat.md` still applies — we ship a `[contract-change]` tag on the PR even though it's additive, so the golden fixtures get re-captured and locked.

---

## Risks / gotchas

- **AlwaysOn=true on a leisure-y app**: if a user marks Twitter as AlwaysOn=true, heartbeat will count silent staring as Work. Mitigation: AlwaysOn is intentional — they asked for it. The deep-idle cutoff still kicks in after 10 min.
- **Battery / wakeup**: 1s polling already exists. Adding a 30s "close + reopen" doesn't change the timer load. The view-buffer flush is still 60s.
- **Storage growth**: ~120 extra views/h/user during heartbeat-active stretches. JSON view ≈ 100 bytes → ~100 KB/day/user. Trivial against existing trace upload.
- **Windows agent (`flexyweb/source`, frozen)**: not patched in this plan. Until it ships the same heartbeat, Mac users will show higher Work numbers than Windows users for the same behavior — flag this in the rollout note.
- **Mac sleep**: agent timer pauses → no heartbeat. Next wake's first view creates a multi-minute gap → backend's existing `LOGOUT_THRESHOLD_SECONDS` sentinel handling fills it. Correct behavior.
- **Network outage**: views buffer locally and flush on next `onWindowTimedEvent`. Heartbeat sequence stays intact. No extra handling needed.

---

## Quick verification commands

After deploying the patched agent for 24h, compare the data:

```bash
# In a flexyweb-nest checkout, with mongo MCP attached or via mongosh:
# Today's domain split for the user:
db.TraceDailyGraph.find({
  CompanyId: "<companyId>",
  UserId: "<userId>",
  RecordDate: { $gte: ISODate("YYYY-MM-DD") }
}, { Domain: 1, Spent: 1, _id: 0 })

# Today's allocation breakdown:
db.TraceClock.aggregate([
  { $match: { CompanyId: "<companyId>", UserId: "<userId>", StartDate: { $gte: ISODate("YYYY-MM-DDT00:00:00Z") } } },
  { $lookup: { from: "TraceAllocation", localField: "AllocationId", foreignField: "_id", as: "a" } },
  { $unwind: "$a" },
  { $group: { _id: "$a.Name", total: { $sum: "$Spent" }, domain: { $first: "$a.Domain" }, alwaysOn: { $first: "$a.AlwaysOn" } } },
  { $sort: { total: -1 } }
])
```

Baseline ratio today: `Work / (Work + Idle + Logout) = 7,838 / 20,420 ≈ 38%`. After the patch with similar reading-heavy work, we expect that ratio to climb meaningfully (target: > 80% for a session of mostly reading inside AlwaysOn apps).
