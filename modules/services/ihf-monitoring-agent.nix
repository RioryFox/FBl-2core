{ config, ... }:

let
  prometheusPort = config.fbl.ports.tcp.prometheus;
  nodePort = config.fbl.ports.tcp.prometheusHFNode;
  squidPort = config.fbl.ports.tcp.prometheusSquid;
  monitoringHost = config.fbl.network.hostLinks.cr01Ihf.host;
in
{
  # blackbox probing and Grafana now live on Cr01MS-32.
  services.prometheus = {
    enable = true;
    enableAgentMode = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;

    remoteWrite = [
      {
        url = "http://${monitoringHost}:${toString prometheusPort}/api/v1/write";
      }
    ];

    scrapeConfigs = [
      {
        job_name = "ihf02-node";
        static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}" ]; } ];
      }
      {
        job_name = "ihf02-squid";
        static_configs = [ { targets = [ "127.0.0.1:${toString squidPort}" ]; } ];
      }
    ];
  };
}