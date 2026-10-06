# mac-n-sleep

A Claude Code / agent skill that puts a Mac to sleep on command or on a
one-shot schedule — designed for the overnight pattern: *"do the task, then
put the laptop to sleep so it doesn't stay on all night."*

## Why it exists

An overnight agent session keeps the laptop awake: the Claude app holds its
own power assertion against idle sleep (measured 2026-08-26 on macOS,
Darwin 25.5.0: `pmset -g` reports `sleep prevented by … Claude …`). So after
a night task finishes, the machine stays on until morning unless something
explicitly puts it to sleep. This skill is that something.

## What it does

- `scripts/goodnight.sh` — sleep now (with a 15 s grace period), in `30m` /
  `2h` / `90s`, or at a given time (`23:30`); `cancel` and `status` included.
- `SKILL.md` — teaches an agent the safe pattern: finish the task, start the
  sleep **detached** as the last tool call, then write the final reply inside
  the grace period.

The grace period is the point. Without it, an agent runs `pmset sleepnow` in
the foreground, the Mac sleeps within seconds, and the user wakes up to a
frozen session with no summary — this exact failure was reproduced in
baseline tests of two independent agent runs (2026-08-26) before the skill
was written.

## How it differs from the obvious alternative

[scheduleoff](https://github.com/swpease/scheduleoff) is the closest existing
tool: a CLI wrapper for near-term sleep/shutdown scheduling. It builds on
`pmset schedule` (per its README, read 2026-08-26), which requires root —
verified locally the same day: `sudo -n true` → "a password is required", so
in an unattended overnight session the password prompt would silently block.
`goodnight.sh` instead uses a detached userspace timer plus `pmset sleepnow`,
which needs no sudo, and adds the agent-specific grace period that no
existing tool has (none of them is designed to be called by an agent).

## Install

```bash
git clone https://github.com/s1vanov/mac-n-sleep.git ~/.claude/skills/mac-n-sleep
```

Or clone anywhere and symlink into `~/.claude/skills/`. No dependencies
beyond stock macOS (`bash`, `pmset`, `nohup`, BSD `date`).

Manual use without an agent:

```bash
scripts/goodnight.sh 30m    # sleep in 30 minutes
scripts/goodnight.sh 23:30  # sleep at 23:30
scripts/goodnight.sh cancel
```

## Verified facts (2026-08-26, macOS Darwin 25.5.0)

| Fact | How it was established |
|---|---|
| Forced sleep needs no sudo | `pmset displaysleepnow` (same privileged path) exits 0 from a non-root sandboxed shell; full `pmset sleepnow` is confirmed by its first real run |
| A detached process survives the end of an agent tool call | `nohup bash -c 'sleep 8; touch marker' &` — marker appeared 8 s after the call closed |
| `cancel` really prevents firing | schedule 3 s → cancel → wait 5 s → marker never appeared (dry-run via `GOODNIGHT_CMD`) |
| The osascript fallback path is available | `osascript -e 'tell app "System Events" to …'` succeeded (Automation permission granted on the reference machine) |

## Limits

- The timed mode is a userspace process: it does not survive reboot or
  logout. For a permanent nightly schedule use the system facility, which
  needs a one-time password: `sudo pmset repeat sleep MTWRFSU 23:30:00`.
- Sleep fires regardless of what is running — downloads or builds still in
  progress at the scheduled time get suspended with the machine.
- macOS only (BSD `date`, `pmset`); tested on one machine (Darwin 25.5.0).
  Nobody else has installed it yet.
- `pmset sleepnow` itself has not been exercised in the test suite (running
  it would put the test machine to sleep mid-session); its sudo-free
  behavior is inferred from `displaysleepnow` on the same privileged path
  and will be confirmed by the first real use.

## Similar projects

- [scheduleoff](https://github.com/swpease/scheduleoff) — better if you want
  system-level `pmset schedule` semantics and don't mind sudo.
- [Sleep Utility](https://apps.apple.com/us/app/sleep-utility/id1206520984) —
  better for humans: a menu-bar sleep timer with a GUI.
- [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake),
  [Caffeinate](https://github.com/LennardKittner/Caffeinate) — the opposite
  job (keep the Mac awake); listed to save you the search.

Claims about these projects reflect their READMEs as read on 2026-08-26.

## Status

0.x — runs on one machine, driven by real overnight agent sessions. The
skill's agent-facing instructions were developed test-first: baseline agent
runs without the skill reproduced both failure modes (foreground sleep,
sudo scheduling), and the same scenarios pass with the skill loaded.

## Author & license

Serhii Ivanov. Feedback: GitHub issues. Licensed under [MIT](LICENSE).
