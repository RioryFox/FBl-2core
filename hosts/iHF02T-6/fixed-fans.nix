{ pkgs, ... }:

{
  # AppleSMC is controlled exclusively by this service.
  services.mbpfan.enable = false;

  systemd.services.ihf02-fixed-fans = {
    description = "Fixed cooling profile for iHF02T-6";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    wants = [ "systemd-modules-load.service" ];

    path = with pkgs; [
      coreutils
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      hwmon="/sys/devices/platform/applesmc.768"

      # During activation the module can be loaded before its control files exist.
      for attempt in $(seq 1 60); do
        if [ -w "$hwmon/fan1_output" ] \
          && [ -w "$hwmon/fan2_output" ] \
          && [ -w "$hwmon/fan3_output" ] \
          && [ -w "$hwmon/fan1_manual" ] \
          && [ -w "$hwmon/fan2_manual" ] \
          && [ -w "$hwmon/fan3_manual" ]; then
          break
        fi

        echo "Waiting for AppleSMC fan controls ($attempt/60)"
        sleep 1
      done

      if [ ! -w "$hwmon/fan1_output" ] \
        || [ ! -w "$hwmon/fan2_output" ] \
        || [ ! -w "$hwmon/fan3_output" ]; then
        echo "AppleSMC fan controls were not found after 60 seconds" >&2
        exit 1
      fi

      echo "Using AppleSMC at $hwmon"

      echo 1 > "$hwmon/fan1_manual"
      echo 1 > "$hwmon/fan2_manual"
      echo 1 > "$hwmon/fan3_manual"

      # Profile validated on the physical iHF02T-6 after restoring airflow.
      echo 3000 > "$hwmon/fan1_output" # ODD / GPU airflow
      echo 1500 > "$hwmon/fan2_output" # HDD
      echo 1800 > "$hwmon/fan3_output" # CPU

      sleep 3
      echo "ODD: $(cat "$hwmon/fan1_input") RPM"
      echo "HDD: $(cat "$hwmon/fan2_input") RPM"
      echo "CPU: $(cat "$hwmon/fan3_input") RPM"
    '';

    # Return control to Apple SMC when the service is deliberately stopped.
    preStop = ''
      hwmon="/sys/devices/platform/applesmc.768"
      if [ -w "$hwmon/fan1_manual" ] \
        && [ -w "$hwmon/fan2_manual" ] \
        && [ -w "$hwmon/fan3_manual" ]; then
        echo 0 > "$hwmon/fan1_manual"
        echo 0 > "$hwmon/fan2_manual"
        echo 0 > "$hwmon/fan3_manual"
      fi
    '';
  };
}
