# remotes.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin that lists your SFTP hosts in an overlay picker.

## Requirements

- **Yazi ≥ 25.12.29**
- [vfs.toml](https://yazi-rs.github.io/docs/configuration/vfs/) with at least one host

```toml
[sftp.foo]
host = "foo"
user = "bar"
port = 22
```

The older `[services.foo]` + `type = "sftp"` layout (Yazi < 26) is still read.

## Installation

```sh
ya pkg add cwelsys/remotes
```

## Usage

```toml
[[mgr.prepend_keymap]]
on = "R"
run = "plugin remotes"
desc = "Pick a remote host"
```

| Key | Action |
|-----|--------|
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `⏎` / `l` / `→` | Connect |
| `q` / `⎋` | Close |
