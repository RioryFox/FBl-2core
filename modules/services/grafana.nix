{ config, pkgs, ... }:

let
  port = config.fbl.ports.tcp.grafana;
  prometheusPort = config.fbl.ports.tcp.prometheus;
  address = config.fbl.network.hosts.cr01;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
  secretFile = "/var/lib/fbl-secrets/grafana.env";
in
{
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = address;
        http_port = port;
      };

      # The actual key is generated locally on Cr01 and never enters Drive or
      # the Nix store. Grafana expands this from the EnvironmentFile at runtime.
      security.secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "FBL Prometheus";
            uid = "fbl-prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString prometheusPort}";
            isDefault = true;
            editable = false;
            jsonData = {
              httpMethod = "POST";
              timeInterval = "15s";
            };
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "Fox Byte Lab";
            folder = "Fox Byte Lab";
            type = "file";
            disableDeletion = true;
            editable = false;
            updateIntervalSeconds = 30;
            options.path = ./monitoring/dashboards;
          }
        ];
      };
    };
  };

  systemd.services.grafana-secret = {
    description = "Create persistent local Grafana secret";
    requiredBy = [ "grafana.service" ];
    before = [ "grafana.service" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      install -d -m 0700 /var/lib/fbl-secrets
      if [ ! -s ${secretFile} ]; then
        umask 077
        printf 'GF_SECURITY_SECRET_KEY=%s\\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${secretFile}
      fi
    '';
  };

  systemd.services.grafana.serviceConfig.EnvironmentFile = [ secretFile ];

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.grafana.enable
    then [ port ]
    else [ ];
}
