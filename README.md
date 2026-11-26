# claude-profiles

Run a second Claude desktop app on macOS, signed in to another account, next to the default one.

`make-claude-home.sh` builds a small launcher app (default `~/Applications/Claude Home.app`).
It starts the regular `/Applications/Claude.app` as a separate instance with its own data.

## Quick start

```bash
./make-claude-home.sh
```

Then open **Claude Home** from Spotlight or `~/Applications`, and sign in with the other account.

## What gets isolated

| What | Default instance | Profile instance |
|---|---|---|
| App data: sign-in, cookies, settings, MCP config, sessions | `~/Library/Application Support/Claude` | `~/Library/Application Support/Claude-<Profile>` |
| Claude Code config: settings, CLAUDE.md, skills, hooks, history | `~/.claude` | `~/.claude-<profile>` |

How it works:
- `--user-data-dir` moves the app data. It also gives the instance its own single-instance lock, so both can run at the same time.
  The app's `CLAUDE_USER_DATA_DIR` env var does not work here: signed builds ignore it.
- `CLAUDE_CONFIG_DIR` moves the Claude Code config.
- `HOME` stays the same, so git, ssh and your shell config are shared.

## Options

```bash
./make-claude-home.sh --profile Home                    # default
./make-claude-home.sh --profile Side --badge star.fill --color FF9500
./make-claude-home.sh --icon ~/Pictures/my-icon.png     # your own icon (.png or .icns)
./make-claude-home.sh --no-badge                        # Claude's icon unchanged
./make-claude-home.sh --help
```

The default icon is Claude's icon with a badge drawn by `icon/badge-icon.swift`.
The badge is any [SF Symbol](https://developer.apple.com/sf-symbols/) name.
The first Swift run takes about 30 seconds.

Re-running the script is safe. It replaces the launcher and leaves the data folders alone.

## Limits

- **Dock icon:** the launcher starts the real Claude.app and quits, so both running instances show Claude's icon in the Dock.
  The custom icon shows in Finder, Spotlight and Launchpad. Changing the Dock icon would mean copying and re-signing Claude.app, which breaks auto-updates.
- **Sign-in:** browser-based sign-in (such as Google) comes back through a `claude://` link, which may open the default instance.
  Use email-code sign-in, or quit the default instance while you sign in.
- **Empty config:** `~/.claude-<profile>` starts empty. Copy in the CLAUDE.md, skills or settings you want.
- Claude updates need no rebuild: the launcher opens the app by bundle ID.

## Remove a profile

```bash
rm -rf ~/Applications/"Claude Home.app"
rm -rf ~/Library/Application\ Support/Claude-Home ~/.claude-home   # deletes that account's local data
```
