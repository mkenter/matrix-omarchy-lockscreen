# Matrix Omarchy Lock Screen

A Matrix-inspired lock screen plugin for Omarchy's Quickshell shell.

It replaces the stock lock-screen presentation with:

- Matrix-style digital rain
- CRT/phosphor effects
- terminal-style password entry
- animated CRT open/close transition
- password and fingerprint authentication through Omarchy's existing lock service

## Screenshot

<img width="3440" height="1440" alt="mpv-shot0001" src="https://github.com/user-attachments/assets/0c8ef380-f22d-460c-9580-73f538d3b08b" />

<img width="3440" height="1440" alt="mpv-shot0002" src="https://github.com/user-attachments/assets/e5b93bb4-91f9-488e-a869-cf2d4b0c7923" />


## Installation

Clone the plugin into your Omarchy user plugin directory:

```bash
git clone https://github.com/mkenter/matrix-omarchy-lockscreen \
  ~/.config/omarchy/plugins/matrix.lock
```

Restart the shell so Omarchy discovers the plugin:

```bash
omarchy restart shell
```

Open the Omarchy plugin manager, then:

1. Disable the built-in `omarchy.lock`
2. Enable `matrix.lock`

Only one lock service should be enabled at a time.

Restart the shell again:

```bash
omarchy restart shell
```

Verify that the custom lock service loaded:

```bash
omarchy-shell lock status
```

If that returns lock status JSON, test the lock:

```bash
omarchy-shell lock lock
```

## Updating

Pull the latest changes and restart the shell:

```bash
cd ~/.config/omarchy/plugins/matrix.lock
git pull
omarchy restart shell
```

## Troubleshooting

If the custom lock service fails to load, inspect the most recent Quickshell log:

```bash
grep -iE 'matrix.lock|LockView.qml|Service.qml|error|failed' \
  "$(ls -t /run/user/$UID/quickshell/by-id/*/log.log | head -1)"
```

If `omarchy-shell lock lock` reports:

```text
Target not found
```

the plugin probably failed to instantiate. Re-enable the stock `omarchy.lock`, disable `matrix.lock`, and restart the shell.

Because this replaces the system lock-screen service, it is a good idea to know how to recover from a TTY or another active session before experimenting with local changes.

## Attribution

This project is derived from Omarchy's built-in `omarchy.lock` plugin.

The session-lock, PAM authentication, fingerprint support, and related lock-service plumbing originate from Omarchy and are used under the MIT License.

The Matrix rain renderer, CRT presentation, terminal-style password UI, and associated modifications were created for this project.

This is an unofficial fan project and is not affiliated with or endorsed by Warner Bros., The Matrix franchise, or Omarchy.

## License

MIT. See [LICENSE](LICENSE).
