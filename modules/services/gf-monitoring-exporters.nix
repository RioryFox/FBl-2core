{ config, ... }:

let
  prometheusPort = config.fbl.ports.tcp.prometheus;
  nodePort = config.fbl.ports.tcp.prometheusExporters;
  monitoringHost = config.fbl.network.hosts.cr01;
in
{
  services.prometheus = {
    enable = true;
    enableAgentMode = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;

    globalConfig = {
      scrape_interval = "15s";
      external_labels.fbl_host = "GF01WS-16";
    };

    remoteWrite = [
      {
        url = "http://${monitoringHost}:${toString prometheusPort}/api/v1/write";
      }
    ];

    scrapeConfigs = [
      {
        job_name = "gf01-node";
        static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}" ]; } ];
      }
    ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = nodePort;
    enabledCollectors = [ "ethtool" "softirqs" "systemd" "tcpstat" ];
    extraFlags = [ "--no-collector.mdadm" ];
  };
}
