{ config, ... }:

let
  nodePort = config.fbl.ports.tcp.prometheusExporters;
  gpuPort = config.fbl.ports.tcp.prometheusGpu;
  smartctlPort = config.fbl.ports.tcp.prometheusSmartctl;
in
{
  boot.kernelModules = [ "coretemp" ];

  # Cr01 owns only its local exporters here. The central Prometheus backend
  # and all scrape/remote_write receiver state live in prometheus.nix.
  services.prometheus.exporters = {
    node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = nodePort;
      enabledCollectors = [ "ethtool" "softirqs" "systemd" "tcpstat" "textfile" ];
      extraFlags = [
        "--collector.ntp.protocol-version=4"
        "--no-collector.mdadm"
        "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files"
      ];
    };

    nvidia-gpu = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = gpuPort;
    };

    smartctl = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = smartctlPort;
      # TODO: replace enumeration-sensitive /dev/sdX with confirmed /dev/disk/by-id paths.
      devices = [ "/dev/sda" "/dev/sdb" ];
    };
  };
}
