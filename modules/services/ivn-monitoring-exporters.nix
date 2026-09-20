{ config, ... }:

let
  prometheusPort = config.fbl.ports.tcp.prometheus;
  nodePort = config.fbl.ports.tcp.prometheusExporters;
  monitoringHost = config.fbl.network.hostLinks.cr01Ivn.host;
in
{
  services.prometheus = {
    enable = true;
    enableAgentMode = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;

    globalConfig = {
      scrape_interval = "15s";
      external_labels.fbl_host = "iVN01T-2";
    };

    remoteWrite = [
      {
        url = "http://${monitoringHost}:${toString prometheusPort}/api/v1/write";
      }
    ];

    scrapeConfigs = [
      {
        job_name = "ivn01-node";
        static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}" ]; } ];
      }
    ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = nodePort;
    enabledCollectors = [ "softirqs" "systemd" "tcpstat" ];
    extraFlags = [ "--no-collector.mdadm" ];
  };
}