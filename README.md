# dump-tabs.yazi

A small [Yazi](https://yazi-rs.github.io/) plugin that dumps all open tabs to a file.

By default it writes a space-separated file and backslash-escapes spaces in fields, so paths like `/home/me/a b` become `/home/me/a\ b`.

## Output

Default output path:

```text
~/.local/state/yazi/tabs.dump
```

Default line format:

```text
<index> <active-or-> <tab-name> <cwd> <hovered-url-or->
```

Example:

```text
1 active projects /home/me/projects /home/me/projects/foo
2 - Downloads /home/me/Downloads /home/me/Downloads/file\ with\ spaces.txt
```

Fields are escaped with backslashes:

- space -> `\ `
- backslash -> `\\`
- tab -> `\t`
- carriage return -> `\r`
- newline -> `\n`

## Install

With Yazi's package manager:

```sh
ya pkg add js0ny-bot/dump-tabs.yazi
```

Or manually:

```sh
mkdir -p ~/.config/yazi/plugins/dump-tabs.yazi
curl -fsSL https://raw.githubusercontent.com/js0ny-bot/dump-tabs.yazi/main/main.lua \
  -o ~/.config/yazi/plugins/dump-tabs.yazi/main.lua
```

## Keymap

Add this to `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-s>" ]
run = "plugin dump-tabs"
desc = "Dump all tabs to file"
```

## Options

Custom output path:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-A-s>" ]
run = "plugin dump-tabs --output=/tmp/yazi-tabs.dump"
desc = "Dump all tabs to /tmp"
```

Custom separator:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-A-s>" ]
run = "plugin dump-tabs --sep=| --output=/tmp/yazi-tabs.dump"
desc = "Dump all tabs with pipe separator"
```

Debug mode:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-S-s>" ]
run = "plugin dump-tabs --debug"
desc = "Dump all tabs with debug notifications"
```

Debug mode does three things:

1. Shows short notifications for each stage: start, collect, ensure output dir, write, done.
2. Writes messages with `ya.dbg()` to Yazi's log when Yazi is started with `YAZI_LOG=debug`.
3. Wraps collection errors with `pcall()` and reports them via `ya.notify()` / `ya.err()` instead of failing silently.

For logs, start Yazi like this:

```sh
YAZI_LOG=debug yazi
```

Then inspect:

```sh
~/.local/state/yazi/yazi.log
```

## Notes

This plugin dumps the visible tab state exposed by Yazi's Lua context API: tab index, active tab, tab name, cwd, and hovered URL.

It does **not** dump Yazi's internal back/forward history stack because that state is not currently exposed to Lua plugins.
