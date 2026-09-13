{ pkgs, ... }:

let
  mirrorRoot = "/mnt/ihf02-mirror";
  mirrorLabel = "IHF02_MIRROR";
  mirrorScript = pkgs.writeShellApplication {
    name = "ihf02-mirror";
    runtimeInputs = with pkgs; [ coreutils findutils gawk gnugrep rsync util-linux ];
    text = ''
      set -euo pipefail
      exec 9>/run/lock/ihf02-mirror.lock
      if ! flock -n 9; then
        echo "iHF02 mirror is already running; skipping"
        exit 0
      fi
      label_path="/dev/disk/by-label/${mirrorLabel}"
      if [ ! -e "$label_path" ]; then
        echo "Backup disk with label ${mirrorLabel} is not connected; skipping"
        exit 0
      fi
      mkdir -p "${mirrorRoot}"
      if ! mountpoint -q "${mirrorRoot}"; then mount "${mirrorRoot}"; fi
      target="${mirrorRoot}/iHF02T-6"
      mkdir -p "$target/root" "$target/boot" "$target/metadata"
      rsync -aHAXx --numeric-ids --delete --delete-excluded \
        --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' \
        --exclude='/run/*' --exclude='/tmp/*' --exclude='/mnt/*' \
        --exclude='/media/*' --exclude='/lost+found' / "$target/root/"
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
  environment.systemPackages = [ mirrorScript ];
  systemd.services.ihf02-mirror = {
    description = "File-level mirror of the iHF02 internal disk";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mirrorScript}/bin/ihf02-mirror";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "2h";
    };
  };
  systemd.timers.ihf02-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "24h";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };
  systemd.services.ihf02-mirror-on-shutdown = {
    description = "Final iHF02 mirror before shutdown";
    wantedBy = [ "multi-user.target" ];
    after = [ "mnt-ihf02\\x2dmirror.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${mirrorScript}/bin/ihf02-mirror";
      TimeoutStopSec = "30m";
    };
  };
}
