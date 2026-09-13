{ config, pkgs, ... }:

let
  port = config.fbl.ports.tcp.prometheus;
  blackboxPort = config.fbl.ports.tcp.prometheusBB;
  nodePort = config.fbl.ports.tcp.prometheusExporters;
  gpuPort = config.fbl.ports.tcp.prometheusGpu;
  smartctlPort = config.fbl.ports.tcp.prometheusSmartctl;
  dnsPort = config.fbl.ports.udp.dns;
  externalSites = config.fbl.monitoring.externalSites;
  familyGateway = config.fbl.network.upstream.familyGateway;
  upstreamDns = config.fbl.network.upstream.dns;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
  ihfHostInterface = config.fbl.network.interfaces.cr01IhfHost;
  ivnHostInterface = config.fbl.network.interfaces.cr01IvnHost;
  iafHostInterface = config.fbl.network.interfaces.cr01IafHost;

  blackboxRelabel = [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = "127.0.0.1:${toString blackboxPort}";
    }
  ];
in
{
  services.prometheus = {
    enable = true;

    # Cr01 is the single FBL monitoring backend. Physical GF01 writes over the
    # FBL LAN; Cr01-hosted MicroVMs write over their dedicated host-only TAPs.
    listenAddress = "0.0.0.0";
    inherit port;
    extraFlags = [
      "--web.enable-remote-write-receiver"
      "--storage.tsdb.retention.time=14d"
      "--storage.tsdb.retention.size=5GB"
    ];

    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = blackboxPort;
      configFile = (pkgs.formats.yaml { }).generate "blackbox.yml" {
        modules = {
          http_2xx = {
            prober = "http";
            timeout = "20s";
            http = {
              preferred_ip_protocol = "ip4";
              ip_protocol_fallback = false;
              follow_redirects = true;
            };
          };

          icmp_ip4 = {
            prober = "icmp";
            timeout = "5s";
            icmp = {
              preferred_ip_protocol = "ip4";
              ip_protocol_fallback = false;
            };
          };

          dns_a = {
            prober = "dns";
            timeout = "5s";
            dns = {
              preferred_ip_protocol = "ip4";
              ip_protocol_fallback = false;
              transport_protocol = "udp";
              query_name = "example.com";
              query_type = "A";
            };
          };
        };
      };
    };

    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "prometheus-cr01";
        static_configs = [
          { targets = [ "127.0.0.1:${toString port}" ]; }
        ];
      }
      {
        job_name = "cr01-node";
        static_configs = [
          { targets = [ "127.0.0.1:${toString nodePort}" ]; }
        ];
      }
      {
        job_name = "cr01-nvidia-gpu";
        static_configs = [
          { targets = [ "127.0.0.1:${toString gpuPort}" ]; }
        ];
      }
      {
        job_name = "cr01-smartctl";
        scrape_interval = "30m";
        scrape_timeout = "30s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString smartctlPort}" ]; }
        ];
      }
      {
        job_name = "external-http";
        scrape_interval = "1m";
        scrape_timeout = "30s";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        static_configs =
          (map
            (site: {
              targets = [ site.url ];
              labels = {
                site = site.host;
                probe_group = site.group;
              };
            })
            externalSites)
          ++ [
            {
              targets = [
                "http://${familyGateway}"
                "http://${upstreamDns}"
              ];
              labels.probe_group = "lan";
            }
          ];
        relabel_configs = blackboxRelabel;
      }
      {
        job_name = "external-icmp";
        scrape_interval = "30s";
        scrape_timeout = "10s";
        metrics_path = "/probe";
        params.module = [ "icmp_ip4" ];
        static_configs = [
          {
            targets = [
              "1.1.1.1"
              "8.8.8.8"
              "9.9.9.9"
              "77.88.8.8"
            ];
          }
        ];
        relabel_configs = blackboxRelabel;
      }
      {
        job_name = "external-dns";
        scrape_interval = "1m";
        scrape_timeout = "10s";
        metrics_path = "/probe";
        params.module = [ "dns_a" ];
        static_configs = [
          {
            targets = [
              "1.1.1.1:${toString dnsPort}"
              "8.8.8.8:${toString dnsPort}"
              "77.88.8.8:${toString dnsPort}"
            ];
          }
        ];
        relabel_configs = blackboxRelabel;
      }
    ];
  };

  # The receiver is reachable only on the FBL LAN and private Cr01<->MicroVM
  # links. Blackbox and local hardware exporters stay loopback-only.
  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.prometheus.enable then [ port ] else [ ];
  networking.firewall.interfaces.${ihfHostInterface}.allowedTCPPorts =
    if config.services.prometheus.enable then [ port ] else [ ];
  networking.firewall.interfaces.${ivnHostInterface}.allowedTCPPorts =
    if config.services.prometheus.enable then [ port ] else [ ];
  networking.firewall.interfaces.${iafHostInterface}.allowedTCPPorts =
    if config.services.prometheus.enable then [ port ] else [ ];
}
