---
name: mac-n-sleep
description: Use when the user asks to put their Mac/laptop to sleep — immediately, after a delay, or at a specific time — especially as the final step of an overnight task ("do the task and put the laptop to sleep", "goodnight", "sleep at 23:30"), in any language. Not for sleep() in code, display sleep, or keeping the Mac awake (that is caffeinate).
---

# mac-n-sleep — put a Mac to sleep on command or on schedule

Skill for the overnight pattern: "do the task, then put the laptop to sleep."
Works without sudo. Environment: macOS + shell access (Claude Code / Cowork).
On claude.ai without machine access this skill does not apply — say so.

## Core rule

**Never run `pmset sleepnow` as a foreground command.** The Mac sleeps within
seconds, before your final message is written — the turn's text comes AFTER
the last tool call, so the user wakes up to a frozen session and no summary.
Always go through `scripts/goodnight.sh`: it detaches and gives a 15-second
grace period by default.

## The "do the task, then sleep" pattern (main scenario)

1. Finish the main task COMPLETELY. Confirm results are saved (files written,
   commits made, background processes finished).
2. As the LAST tool call, start the sleep with the default 15 s delay:
   ```bash
   "<path-to-this-skill>/scripts/goodnight.sh"
   ```
3. Write the final reply IMMEDIATELY after — 15 seconds is enough to finish
   the text before the Mac sleeps. Add no further tool calls after the script.
4. In the final reply state: task done + Mac sleeps in ~15 seconds.

## Delayed or timed sleep

```bash
goodnight.sh 30m      # in 30 minutes (also 90s, 2h, bare number = seconds)
goodnight.sh 23:30    # today at 23:30; if already past — tomorrow
goodnight.sh cancel   # cancel
goodnight.sh status   # check
```

Re-scheduling replaces the previous schedule. The scheduler is a detached
userspace process (`nohup … sleep N; pmset sleepnow`), so it survives only
until reboot/logout; for a permanent nightly schedule see below.

## Mechanism and fallback

Primary command: `pmset sleepnow` — forced sleep, ignores idle-sleep
assertions, no sudo needed. If it unexpectedly errors, fall back to:

```bash
osascript -e 'tell application "System Events" to sleep'
```

(Requires the Automation permission for System Events; on the reference
machine it was already granted — verified 2026-08-26.)

## Nightly at a fixed time, without an agent

If the user wants a system-level schedule (always on, survives reboots), it
is a one-time command that NEEDS A PASSWORD — offer it for the user to run
themselves; never run it in an unattended session, the password prompt will
silently block everything:

```bash
sudo pmset repeat sleep MTWRFSU 23:30:00
```

Check: `pmset -g sched`. Cancel: `sudo pmset repeat cancel`.

## Why the laptop does not sleep on its own

The Claude app holds its own assertion against idle sleep (measured
2026-08-26: `pmset -g` → `sleep prevented by … Claude …`). An overnight
session really does keep the laptop on all night — an explicit sleep call is
required. For the same reason `caffeinate` is NOT needed for an overnight
task inside a Claude session.

## Examples

- "Refactor this and put the laptop to sleep" → task → `goodnight.sh` →
  final reply.
- "Make it sleep at 2:00" → `goodnight.sh 02:00`.
- "Cancel the sleep" → `goodnight.sh cancel`.
- "Make the Mac sleep every night at 11" → offer `sudo pmset repeat sleep
  MTWRFSU 23:00:00` for the user to run (don't run it yourself — password).

## Common mistakes

| Mistake | Reality |
|---|---|
| "I'll send the summary first, then run `pmset sleepnow` foreground" | There is no "first": the turn's final text comes after the last tool call. Foreground sleepnow freezes the session before any summary exists. Use goodnight.sh (detached + 15 s). |
| "Schedule with `sudo pmset schedule` at night" | Password prompt blocks silently with nobody at the keyboard. Use goodnight.sh timed mode instead. |
| Sleeping before results are saved | Verify files/commits/background jobs first; sleep is always the last step. |
| Treating "turn it off" as shutdown | Ask: sleep (instant wake, everything stays open) or full shutdown? |
| Triggering on sleep() in code, display sleep, or "keep my Mac awake" | Out of scope; the last one is `caffeinate -i`. |
