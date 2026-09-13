{ config, pkgs, ... }:

let
  mirrorRoot = config.fbl.storage.cr01Mirror.mountPoint;
  mirrorLabel = config.fbl.storage.cr01Mirror.label;

  mirrorScript = pkgs.writeShellApplication {
    name = "cr01-mirror";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gawk
      gnugrep
      rsync
      util-linux
    ];
    text = ''
      set -euo pipefail

      exec 9>/run/lock/cr01-mirror.lock
      if ! flock -n 9; then
        echo "Cr01 mirror is already running; skipping"
        exit 0
      fi

      label_path="/dev/disk/by-label/${mirrorLabel}"
      if [ ! -e "$label_path" ]; then
        echo "Mirror disk with label ${mirrorLabel} is not connected; skipping"
        exit 0
      fi

      mkdir -p "${mirrorRoot}"
      if ! mountpoint -q "${mirrorRoot}"; then
        mount "${mirrorRoot}"
      fi

      expected_device="$(readlink -f "$label_path")"
      mounted_device="$(findmnt -n -o SOURCE --target "${mirrorRoot}")"
      mounted_device="$(readlink -f "$mounted_device")"
      if [ "$mounted_device" != "$expected_device" ]; then
        echo "Refusing to mirror: ${mirrorRoot} is mounted from $mounted_device, expected $expected_device" >&2
        exit 1
      fi

      target="${mirrorRoot}/Cr01MS-32"
      mkdir -p "$target/root" "$target/boot" "$target/metadata"

      # Persistent service state under /var (including /var/lib/gitea) is
      # intentionally mirrored; /nix remains rebuildable and excluded below.
      rsync -aHAXx --numeric-ids --delete --delete-excluded \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/run/*' \
        --exclude='/tmp/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude='/nix/*' \
        --exclude='/lost+found' \
        / "$target/root/"

      rsync -aHAX --numeric-ids --delete /boot/ "$target/boot/"

      root_source="$(findmnt -n -o SOURCE /)"
      root_partition="$(readlink -f "$root_source")"
      parent_name="$(lsblk -n -o PKNAME "$root_partition" | head -n1)"
      if [ -n "$parent_name" ]; then
        sfdisk --dump "/dev/$parent_name" > "$target/metadata/partition-table.sfdisk"
      fi

      lsblk -f > "$target/metadata/lsblk.txt"
      findmnt --real > "$target/metadata/findmnt.txt"
      date --iso-8601=seconds > "$target/metadata/last-success.txt"
      sync
    '';
  };
in
{
  fileSystems."${mirrorRoot}" = {
    device = "/dev/disk/by-label/${mirrorLabel}";
    fsType = "ext4";
    options = [
      "nofail"
      "noauto"
      "x-systemd.device-timeout=5s"
    ];
  };

  environment.systemPackages = [ mirrorScript ];

  systemd.services.cr01-mirror = {
    description = "File-level mirror of the Cr01 system disk";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mirrorScript}/bin/cr01-mirror";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "2h";
    };
  };

  systemd.timers.cr01-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "24h";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };

  systemd.services.cr01-mirror-on-shutdown = {
    description = "Final Cr01 mirror before shutdown";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${mirrorScript}/bin/cr01-mirror";
      TimeoutStopSec = "30m";
    };
  };
}
