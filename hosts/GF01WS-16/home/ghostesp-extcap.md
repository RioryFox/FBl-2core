# GhostESP Wireshark Extcap (GF01WS-16)

## Purpose

Expose the ESP32-C3 running GhostESP v2.1 (Revival) as **GhostESP WiFi/BLE Capture** in the existing Wireshark GUI on GF01WS-16. The ESP32-C3 performs radio capture; GF01 merely receives the USB/UART PCAP stream and displays it in Wireshark.

This integration uses **Home Manager**, imported by `hosts/GF01WS-16/home/default.nix` from `ghostesp-extcap.nix`. It does **not** modify the `student` role, install Wireshark again, run `pip install`, flash the ESP, or alter USB permissions.

## Source and version pin

- Upstream: [GhostESP-Revival/GhostESP](https://github.com/GhostESP-Revival/GhostESP).
- Firmware/source tag: **v2.1**.
- Upstream commit: `9151548e8d841afb38f97ac9bc31d4e33e71a243`.
- Script: `scripts/wireshark_extcap_installer/ghostesp_extcap.py`.
- SHA-256 SRI: `sha256-IXXNJf1j9qbw8GruZLmQDhwv0oedYYKeW4iA3/oYxX4=`.
- Python dependency: `pkgs.python3.withPackages (ps: [ ps.pyserial ])`; no dynamic Python dependency installation in the intended path.
- Home Manager destination: `~/.local/lib/wireshark/extcap/ghostesp_extcap.py`.

The upstream script contains a fallback that tries `pip install pyserial --user` if `serial` cannot be imported. The Nix wrapper always supplies `pyserial` with its interpreter; if this stops working, fix the Nix package rather than installing Python dependencies globally.

## Post-merge activation and checks

Follow the repository's normal GF01 flake deployment procedure. For example, from the repository root on GF01:

```bash
# Optional static evaluation before deployment:
nix eval --raw .#nixosConfigurations.GF01WS-16.config.system.build.toplevel.drvPath

# Only after the change has been merged and reviewed:
sudo nixos-rebuild switch --flake .#GF01WS-16
```

Then verify from a **normal host terminal**, not a transient Python environment:

```bash
test -x "$HOME/.local/lib/wireshark/extcap/ghostesp_extcap.py"
"$HOME/.local/lib/wireshark/extcap/ghostesp_extcap.py" --extcap-interfaces
"$HOME/.local/lib/wireshark/extcap/ghostesp_extcap.py" --extcap-config --extcap-interface ghostesp
id -nG
ls -l /dev/ttyACM0
```

Expected in the `--extcap-interfaces` output:

```text
interface {value=ghostesp}{display=GhostESP WiFi/BLE Capture}
```

The exact serial device name can change when USB devices are reconnected. `GF01WS-16/users.nix` currently includes the user's `dialout` group; runtime permissions still need checking.

## GUI capture on the isolated SNR test bench

1. Close the Tabby session connected to `/dev/ttyACM0`. One process must not compete with Wireshark for the same serial device.
2. Fully restart Wireshark after the declarative deployment.
3. Find the **GhostESP WiFi/BLE Capture** Extcap interface. If absent, inspect **Help → About Wireshark → Folders** for its Extcap directory, then compare to the managed path above.
4. Configure the actual ESP serial port (previously `/dev/ttyACM0`), baud **115200**, capture type **WiFi**, channel lock **2**.
5. Start a short, passive capture in an isolated test network; do not launch deauth or other active attacks.
6. Apply this **display filter** (not a capture filter) to review only the target AP's Beacon and Probe Response frames:

```wireshark
wlan.bssid == f8:f0:82:6c:e0:58 && (wlan.fc.type_subtype == 0x08 || wlan.fc.type_subtype == 0x05)
```

The ESP radio still receives other nearby traffic on channel 2. Limit what is inspected and retained; do not publish unrelated raw captures.

Review RSN Information Elements (AKM and cipher suites such as CCMP/TKIP), vendor-specific WPS elements, and advertised PMF capability. Absence of a WPS element in a short capture does **not** prove WPS is disabled.

## Scope and verification status

- Confirmed in repository code: `cyber.role = "student"`, `wireshark` included in that role, Wireshark also present in GF01 user packages, GF01 user belongs to `dialout`, Home Manager imported for GF01.
- Confirmed from ESP console: GhostESP **v2.1 (Revival)**, `capture -wireshark` supported in `help capture`.
- Not confirmed yet: NixOS flake evaluation/build on GF01; deployment; executable discovery by Wireshark; live PCAP data and accuracy of decoding.
- `programs.wireshark.enable`/`dumpcap` permissions are a separate issue from GhostESP's USB serial capture.

A Git commit or PR is **not** evidence of a successfully applied configuration. Complete the checks above on GF01 before marking the integration operational.
