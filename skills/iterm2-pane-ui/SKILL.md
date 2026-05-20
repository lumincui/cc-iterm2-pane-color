---
name: iterm2-pane-ui
description: Configure iTerm2 UI to complement per-pane workflows — show OSC-set pane titles via status bar (since the native pane title bar is not customizable), hide the macOS window title bar, and stop dimming inactive split panes. Use this skill whenever the user asks about iTerm2 status bar, displaying pane titles, window/title bar removal, OSC title escape sequences, or appearance tweaks. Triggers include English and Chinese phrasings like "iterm2 pane title", "iterm2 status bar OSC", "no title bar", "minimal theme", "dim inactive split panes", "pane 字号", "状态栏显示 pane 标题", "iterm2 隐藏标题栏", "去掉 window title", "iTerm2 顶部多余一条"; trigger even when the user mentions only one piece, because the three topics are usually configured together.
---

# iTerm2 pane UI configuration

iTerm2's native per-pane title bar (the thin strip above each split) has **no exposed font size or height** in preferences or hidden defaults. The supported workaround is the **status bar**, which is fully configurable per-pane and can read OSC-set title variables. This skill covers that, plus the two adjacent settings users almost always ask about in the same breath: removing the macOS window title bar, and turning off the gray dimming on inactive splits.

When invoked, identify which of the three the user wants (often more than one) and walk through the relevant section. Prefer GUI steps with `defaults write` shown alongside — users frequently want to script their setup.

## Quickstart: one-shot automation

If the user wants the full setup applied at once, run `scripts/apply.sh` (in this skill directory). It:

- Installs a `ClaudeCode` Dynamic Profile (`assets/ClaudeCode.json`) with `Window Type = 12` (Compact, no native title bar) and a status bar containing three components — `\(session.name)` (OSC pane title), Working Directory, and Git State (branch + dirty marker); takes effect live, no restart. The Working Directory and Git State components require iTerm2 **Shell Integration** to be installed in the user's shell — otherwise they show the launch directory only and never update on `cd`
- Writes global defaults (`DimInactiveSplitPanes=false`, `SeparateStatusBarsPerPane=true`, `ShowPaneTitles=false`, `Default Bookmark Guid=claude-code-pane-ui`) — but **only if iTerm2 is not running** (in-memory cache will otherwise overwrite the file)
- If iTerm2 is running, prints the `defaults write` commands for the user to run later. Pass `--with-quit` to opt into a macOS confirmation dialog that quits iTerm2 first; the script refuses to do this when invoked from inside iTerm2 itself

Use the manual sections below when the user only wants part of the setup, asks how something works, or is troubleshooting.

## A. Show OSC pane title via status bar

Replaces the unmodifiable native pane title.

1. Preferences → Profiles → Session → check **Status bar enabled** → **Configure Status Bar**
2. Drag **Interpolated String** from the left panel into the right (Active) panel
3. Double-click it; in the expression box use one of:
   - `\(terminalIconName)` — set by `OSC 1` (and `OSC 0`); cleanest per-pane
   - `\(session.name)` — iTerm2's computed session name; follows profile title rules
   - `\(user.<key>)` — for any custom user var set via `OSC 1337;SetUserVar`
4. Click **Advanced Configuration** on that component for font size, color, min/max width
5. Preferences → Profiles → Session → enable **Separate status bars per pane** so each split has its own
6. (Optional) Preferences → Profiles → Session → uncheck **Show per-pane title bar with split panes** since the status bar replaces it

Equivalent `defaults` keys (restart iTerm2 to take effect):

```bash
defaults write com.googlecode.iterm2 SeparateStatusBarsPerPane -bool true
defaults write com.googlecode.iterm2 ShowPaneTitles -bool false
```

Verify by writing OSC sequences directly to the pane:

```bash
printf '\e]1;hello-pane\a'      # OSC 1 → terminalIconName (per-pane)
printf '\e]0;hello-pane\a'      # OSC 0 → terminalIconName + terminalWindowName
# iTerm2 user var (base64-encoded value):
printf '\e]1337;SetUserVar=mytitle=%s\a' "$(printf 'pane-1' | base64)"
# then in status bar: \(user.mytitle)
```

Note: if the profile has **General → Title → "Allow terminal-generated titles to override profile name"** unchecked, `session.name` will not follow OSC; `terminalIconName` / `terminalWindowName` still update independently. Prefer **OSC 1** for per-pane titles — `OSC 0` also affects the window-level title, which is visually shared with tabs.

## B. Remove the macOS window title bar

Two approaches, pick one based on scope:

**Per-profile (recommended).** Preferences → Profiles → Window → **Style: No Title Bar** (or **Compact**, which gives a similar look while keeping window-move handles). Per-profile is preferred over the global Theme=Minimal/Compact route because it doesn't change the appearance of profiles you haven't opted in.

**Runtime toggle.** Menu **View → Toggle Window Title Bar**, or bind a shortcut in Preferences → Keys.

## C. Stop dimming inactive split panes

By default iTerm2 grays out non-focused splits — distracting in multi-pane workflows like this repo's status-bg hook.

```bash
defaults write com.googlecode.iterm2 DimInactiveSplitPanes -bool false
# If dimming still appears, also disable:
defaults write com.googlecode.iterm2 DimBackgroundWindows -bool false
defaults write com.googlecode.iterm2 DimOnlyText -bool false
```

Restart iTerm2. GUI equivalent: Preferences → Appearance → Dimming.

## OSC quick reference

| Sequence | Effect | iTerm2 variable |
|---|---|---|
| `\e]0;TITLE\a` | window title + icon name | `terminalWindowName` + `terminalIconName` |
| `\e]1;TITLE\a` | icon (tab) name | `terminalIconName` |
| `\e]2;TITLE\a` | window title | `terminalWindowName` |
| `\e]1337;SetUserVar=KEY=BASE64\a` | iTerm2 user variable | `user.KEY` |

`\e` is ESC (`\033`); `\a` is BEL (`\007`). String terminator `\e\\` (ST) also works in place of `\a`.

## Why these three together

A user setting up the [`cc-status-bg`](../../README.md) hook typically wants every pane to be self-identifying: the background tinted by Claude Code state, a label up top showing what each pane is doing, and no surrounding chrome stealing vertical space. The native pane title bar is the obvious place to put a label but cannot be styled — so the status bar takes over, the window title bar comes off, and inactive dimming is disabled so all panes stay equally readable.
