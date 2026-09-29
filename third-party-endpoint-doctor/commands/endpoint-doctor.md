---
description: Diagnose stalled tool calls on a non-Anthropic endpoint
allowed-tools: Read, Edit, Bash, PowerShell
---

Diagnose why tool calls stall on this machine, and offer the fix.

Work through these checks, reporting each finding as you go. Do not edit any file
until the user confirms.

**1. Endpoint.** Read `ANTHROPIC_BASE_URL` from the environment and from the `env`
block of `~/.claude/settings.json`. Report the host. If it is `api.anthropic.com`,
stop — this command does not apply.

**2. Classifier pin.** Check `env.CLAUDE_CODE_AUTO_MODE_SERVER` in the same file.
Absent or `"1"` = the server-side classifier may be in use on a host that cannot
serve it. `"0"` = already pinned to the local classifier.

**3. Permission mode.** Check `permissions.defaultMode`. If unset, interactive
sessions on builds 2.1.283+ start in auto mode, which is what engages the
classifier in the first place.

**4. Running build.** Verify what is *actually* executing, not what the config
claims: find the live `claude` process, then read that executable's
`VersionInfo.FileVersion`. Report it. Flag it if the config says one version and
the binary is another — a pin can silently fail to reach the active binary.

**5. Corroboration.** Scan recent transcripts for `doesn't want to proceed` and
`denied by the Claude Code auto mode classifier`. Report counts. Note that these
denials are what Esc-to-unstick looks like in a log, so they corroborate a stall
rather than contradict it.

**6. Report.** Summarise: is this machine exposed, and to what degree?

Then offer the fix — adding `"CLAUDE_CODE_AUTO_MODE_SERVER": "0"` to the `env` block
of `~/.claude/settings.json` — and apply it only on an explicit yes. Show the exact
edit first. Mention that a restart is required and that classifier requests will
continue to be billed as before.

Close by stating plainly that the mechanism is inferred from changelog entries and
correlation, not reproduced under controlled conditions, and that the decisive test
is removing the setting again to confirm the stall returns.
