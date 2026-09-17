# Tunnelblick Reset

[Русский](README.ru.md)

Tunnelblick Reset is a macOS menu bar app that repairs the network after Tunnelblick hangs. Its single-slot icon shows a large `T` and a small `b`; the ring indicates progress. The menu shows the current step and a disabled **Status** line. After a successful repair, the app relaunches Tunnelblick, shows a checkmark for 5 seconds, then returns to the monogram.

The app and script support English and Russian. The app follows macOS language preferences; the standalone script follows the shell locale or accepts `--lang en|ru`.

The script stops Tunnelblick, `tunnelblickd`, and Tunnelblick's OpenVPN process; unloads `net.tunnelblick.openvpn.process-network-changes`; removes DNS keys from `scutil`; restarts Wi-Fi; flushes the resolver cache; and checks DNS. It fails if the VPN processes remain. If a later step fails while Wi-Fi is off, it attempts to turn Wi-Fi back on.

## Release status

**The changes on `main` are not released yet.** The current [1.0.0 release](https://github.com/viktoraseev/dns-reset-tunnelblick/releases/tag/v1.0.0) and [Homebrew cask](https://github.com/viktoraseev/homebrew) still install the previous `DNS Reset.app`, with its previous icon and Russian-only interface. The cask will be updated when a new release is made.

## Build the current source

Requires macOS 13 or later, Xcode Command Line Tools, Tunnelblick at `/Applications/Tunnelblick.app`, and administrator access.

```sh
./build.sh
open "$HOME/Applications/Tunnelblick Reset.app"
```

`./build-release.sh` builds separate ad hoc signed ZIP archives for Apple Silicon and Intel into `dist/`; running it does not publish a release. The project has no Apple Developer ID certificate or notarization. If Gatekeeper blocks a build you installed from a downloaded archive, inspect its source and then remove quarantine only from that app if you trust it.

## Touch ID

The app runs `sudo -A`. For fingerprint authorization, `/etc/pam.d/sudo_local` must contain the line in [`sudo_local`](sudo_local):

```text
auth       sufficient     pam_tid.so
```

This system-wide PAM setting also affects other `sudo` commands. Preserve other entries if the file already exists. The app does not present a password dialog; if Touch ID is unavailable, the repair fails. The standalone `./run.sh` allows a normal `sudo` password prompt.

## Manual operation

`sudo bash reset.sh [--lang en|ru]` performs the six repair steps without relaunching Tunnelblick. `./run.sh` performs the repair and relaunches Tunnelblick as the current user. Relaunch is step seven in the menu bar app.

The Wi-Fi interface is set to `en0` in `reset.sh`; change it for Macs with a different interface. The `net.tunnelblick.tunnelblick.tunnelblickd` service stays registered so Tunnelblick can launch again. A new VPN connection may set corporate DNS again.

The app does not start automatically. Use **Quit** in its menu to stop it. Hold Command and drag the icon to change its menu bar position.

## License

MIT. See [LICENSE](LICENSE).
