{ config, lib, ... }:

let
  httpsPort = config.fbl.ports.tcp.https;
  externalSiteType = lib.types.submodule {
    options = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "DNS hostname used for FBL external network diagnostics.";
      };

      url = lib.mkOption {
        type = lib.types.str;
        description = "HTTP(S) URL probed by the central Blackbox exporter.";
      };

      group = lib.mkOption {
        type = lib.types.enum [ "ru" "global" "infra" ];
        description = "Logical dashboard/probe group.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = httpsPort;
        description = "TCP port probed directly on the resolved IPv4 address.";
      };
    };
  };
in
{
  options.fbl.monitoring.externalSites = lib.mkOption {
    type = lib.types.listOf externalSiteType;
    default = [
      { host = "ya.ru"; url = "https://ya.ru"; group = "ru"; }
      { host = "vk.ru"; url = "https://vk.ru"; group = "ru"; }
      { host = "mail.ru"; url = "https://mail.ru"; group = "ru"; }
      { host = "rutube.ru"; url = "https://rutube.ru"; group = "ru"; }

      { host = "github.com"; url = "https://github.com"; group = "global"; }
      { host = "www.google.com"; url = "https://www.google.com"; group = "global"; }
      { host = "www.youtube.com"; url = "https://www.youtube.com"; group = "global"; }
      { host = "www.wikipedia.org"; url = "https://www.wikipedia.org"; group = "global"; }
      { host = "telegram.org"; url = "https://telegram.org"; group = "global"; }

      { host = "cloudflare.com"; url = "https://cloudflare.com"; group = "infra"; }
      { host = "example.com"; url = "https://example.com"; group = "infra"; }
      { host = "search.nixos.org"; url = "https://search.nixos.org"; group = "infra"; }
    ];
    description = "Single source of truth for externally monitored FBL web targets.";
  };
}              