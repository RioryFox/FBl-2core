{ config, pkgs, ... }:

let
  address = config.fbl.network.hosts.cr01;
  port = config.fbl.ports.tcp.searxng;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;
    environmentFile = "/var/lib/searx/searx.env";
    settings = {
      general = {
        debug = false;
        instance_name = "FBL Search";
      };
      server = {
        bind_address = address;
        inherit port;
        secret_key = "$SEARXNG_SECRET";
        limiter = false;
        public_instance = false;
        image_proxy = true;
      };
      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/searx 0750 searx searx -"
  ];

  systemd.services.searx-secret = {
    description = "Create persistent SearXNG secret";
    wantedBy = [ "multi-user.target" ];
    before = [ "searx.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if [ ! -s /var/lib/searx/searx.env ]; then
        umask 077
        printf 'SEARXNG_SECRET=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
          > /var/lib/searx/searx.env
        chown searx:searx /var/lib/searx/searx.env
      fi
    '';
  };
  systemd.services.searx.requires = [ "searx-secret.service" ];
  systemd.services.searx.after = [ "searx-secret.service" ];

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.searx.enable
    then [ port ]
    else [ ];
}