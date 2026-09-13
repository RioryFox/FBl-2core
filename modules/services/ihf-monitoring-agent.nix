{ config, ... }:

let
  prometheusPort = config.fbl.ports.tcp.prometheus;
  nodePort = config.fbl.ports.tcp.prometheusHFNode;
  squidPort = config.fbl.ports.tcp.prometheusSquid;
  monitoringHost = config.fbl.network.hostLinks.cr01Ihf.host;
in
{
  # iHF keeps only a lightweight Prometheus Agent. Long-term TSDB state,
  # blackbox probing and Grafana now live on Cr01MS-32.
  services.prometheus = {
    enable = true;
    enableAgentMode = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;

    globalConfig = {
      scrape_interval = "15s";
      external_labels.fbl_host = "iHF02T-6";
    };

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

# [GPT-5.6 Sol] создал в 23:03 05.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:52 13.09.2026 (МСК).
