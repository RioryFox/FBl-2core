{ pkgs, ... }:
let
  # Match the GhostESP v2.1 firmware flashed on GF01's ESP32-C3.
  ghostespRevision = "9151548e8d841afb38f97ac9bc31d4e33e71a243";

  # Only the upstream Extcap script is fetched; no GhostESP installer or pip.
  upstreamExtcap = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/GhostESP-Revival/GhostESP/${ghostespRevision}/scripts/wireshark_extcap_installer/ghostesp_extcap.py";
    hash = "sha256-IXXNJf1j9qbw8GruZLmQDhwv0oedYYKeW4iA3/oYxX4=";
  };

  pythonWithSerial = pkgs.python3.withPackages (ps: [ ps.pyserial ]);

  # Wireshark calls Extcap executables directly. A shell wrapper gives it an
  # immutable Python interpreter with pyserial already available.
  ghostespExtcap = pkgs.writeShellScript "ghostesp_extcap.py" ''
    export PYTHONNOUSERSITE=1
    exec ${pythonWithSerial}/bin/python3 ${upstreamExtcap} "$@"
  '';
in
{
  # Official GhostESP per-user Linux Extcap location.
  # This is a Home Manager-managed symlink, not a mutable pip installation.
  home.file.".local/lib/wireshark/extcap/ghostesp_extcap.py".source = ghostespExtcap;
}
