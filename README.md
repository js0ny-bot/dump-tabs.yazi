# dump-tabs.yazi

A small [Yazi](https://yazi-rs.github.io/) plugin that dumps all open tabs to a file.

It has two main use cases:

1. Human/debug dump: a table with tab index, active tab, name, cwd, and hovered path.
2. Restore dump: paths or a ready-to-run `yazi ...` command.

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

## Basic keymap

```toml
[[mgr.prepend_keymap]]
on = [ "<C-s>" ]
run = "plugin dump-tabs"
desc = "Dump all tabs to file"
```

Default output path:

```text
~/.local/state/yazi/tabs.dump
```

Default format is `table`:

```text
<index> <active-or-> <tab-name> <cwd> <hovered-url-or->
```

Example:

```text
1 - home /home/user /home/user/.config
2 active project /home/user/project /home/user/project/src
3 - docs /home/user/docs /home/user/docs/notes
```

Fields in `table` format are backslash-escaped for readability:

- space -> `\ `
- backslash -> `\\`
- tab -> `\t`
- carriage return -> `\r`
- newline -> `\n`

## Restore-friendly formats

For reopening tabs, prefer one of these instead of parsing the default table.

### `format=cmd`

Writes a ready-to-run shell command:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-s>" ]
run = "plugin dump-tabs -- --format=cmd"
desc = "Dump tabs as yazi command"
```

Output:

```sh
yazi '/home/user/.config' '/home/user/project/src' '/home/user/docs/notes'
```

Run it with:

```sh
sh ~/.local/state/yazi/tabs.dump
```

or inspect first:

```sh
cat ~/.local/state/yazi/tabs.dump
```

### `format=nul`

Writes NUL-separated paths for robust machine parsing:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-s>" ]
run = "plugin dump-tabs -- --format=nul"
desc = "Dump tabs as NUL-separated paths"
```

Default output path for this mode:

```text
~/.local/state/yazi/tabs.nul
```

Restore with:

```sh
xargs -0 yazi < ~/.local/state/yazi/tabs.nul
```

This is the safest format for paths containing spaces, quotes, or other shell metacharacters.

### `format=lines`

Writes one path per line:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-s>" ]
run = "plugin dump-tabs -- --format=lines"
desc = "Dump tabs as one path per line"
```

Restore only if your paths do not contain newlines:

```sh
xargs -d '\n' yazi < ~/.local/state/yazi/tabs.dump
```

## Other options

Custom output path:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-A-s>" ]
run = "plugin dump-tabs -- --format=cmd --output=/tmp/yazi-tabs.sh"
desc = "Dump all tabs to /tmp"
```

Custom separator for `table` format:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-A-s>" ]
run = "plugin dump-tabs -- --format=table --sep=| --output=/tmp/yazi-tabs.dump"
desc = "Dump all tabs with pipe separator"
```

Debug mode:

```toml
[[mgr.prepend_keymap]]
on = [ "<C-S-s>" ]
run = "plugin dump-tabs -- --debug"
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

For each tab, restore-oriented formats use the hovered URL if present; otherwise they fall back to the tab cwd.

This plugin does **not** dump Yazi's internal back/forward history stack because that state is not currently exposed to Lua plugins.
