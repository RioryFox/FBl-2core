{ config, inputs, lib, ... }:

let
  address = config.fbl.network.hosts.cr01;
  lanInterface = config.fbl.network.interfaces.cr01Lan;

  authPort = config.fbl.ports.tcp.authentik;
  authHttpsPort = config.fbl.ports.tcp.authentikHttps;
  authMetricsPort = config.fbl.ports.tcp.authentikMetrics;
  authWorkerPort = config.fbl.ports.tcp.authentikWorker;
  authWorkerMetricsPort = config.fbl.ports.tcp.authentikWorkerMetrics;
  comfyBackendPort = config.fbl.ports.tcp.comfyui;
  comfyFrontendPort = config.fbl.ports.tcp.comfyuiProtected;

  authHost = address;
  secretFile = "/var/lib/fbl-secrets/authentik.env";
in
{
  imports = [ inputs.authentik-nix.nixosModules.default ];

  # Secrets live only on Cr01. At minimum this file must contain
  # AUTHENTIK_SECRET_KEY=<generated value> and be mode 0600/root:root.
  systemd.tmpfiles.rules = [
    "d /var/lib/fbl-secrets 0700 root root -"
  ];

  services.authentik = {
    enable = false;
    environmentFile = secretFile;

    # Keep every Authentik backend listener off the LAN. nginx is the only
    # owner of browser-facing Authentik/ComfyUI listeners.
    worker = {
      listenHTTP = "127.0.0.1:${toString authWorkerPort}";
      listenMetrics = "127.0.0.1:${toString authWorkerMetricsPort}";
    };

    settings = {
      disable_startup_analytics = true;
      # 2026.8 introduces a persistent Base URL setting; seed it on first
      # startup with the LAN URL used for Authentik bootstrap and login.
      web.base_url = "http://${address}:${toString authPort}";

      listen = {
        http = [ "127.0.0.1:${toString authPort}" ];
        https = [
          "127.0.0.1:${toString authHttpsPort}"
          "[::1]:${toString authHttpsPort}"
        ];
        metrics = [ "127.0.0.1:${toString authMetricsPort}" ];
        # nginx connects locally; do not trust arbitrary LAN clients to set
        # X-Forwarded-* headers.
        trusted_proxy_cidrs = [
          "127.0.0.0/8"
          "::1/128"
        ];
      };
    };

    # Reuse the NixOS nginx already present on Cr01. authentik-nix provides
    # the static frontend handling and proxies this vhost to loopback HTTPS.
    nginx = {
      enable = true;
      enableACME = false;
      host = authHost;
    };
  };

  services.nginx = {
    recommendedProxySettings = true;

    # The authentik-nix vhost normally uses nginx's default listen socket.
    # Scope it to Cr01 LAN and the registry-owned Authentik port instead.
    virtualHosts.${authHost}.listen = [
      {
        addr = address;
        port = authPort;
      }
    ];

    # Separate protected frontend. ComfyUI itself remains bound to loopback.
    virtualHosts."comfyui-protected" = {
      serverName = address;
      listen = [
        {
          addr = address;
          port = comfyFrontendPort;
        }
      ];

      extraConfig = ''
        proxy_buffers 8 16k;
        proxy_buffer_size 32k;
        port_in_redirect off;

        # Preserve an explicit Host header including the non-standard port,
        # matching Authentik's current nginx forward-auth template.
        set $ak_http_host $http_host;
        if ($ak_http_host = "") {
          set $ak_http_host $host;
        }
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString comfyBackendPort}";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /outpost.goauthentik.io/auth/nginx;
          error_page 401 = @goauthentik_proxy_signin;

          auth_request_set $auth_cookie $upstream_http_set_cookie;
          add_header Set-Cookie $auth_cookie;

          auth_request_set $authentik_username $upstream_http_x_authentik_username;
          auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
          auth_request_set $authentik_entitlements $upstream_http_x_authentik_entitlements;
          auth_request_set $authentik_email $upstream_http_x_authentik_email;
          auth_request_set $authentik_name $upstream_http_x_authentik_name;
          auth_request_set $authentik_uid $upstream_http_x_authentik_uid;

          proxy_set_header X-authentik-username $authentik_username;
          proxy_set_header X-authentik-groups $authentik_groups;
          proxy_set_header X-authentik-entitlements $authentik_entitlements;
          proxy_set_header X-authentik-email $authentik_email;
          proxy_set_header X-authentik-name $authentik_name;
          proxy_set_header X-authentik-uid $authentik_uid;
        '';
      };

      # Embedded outpost path. It must be reachable without prior auth because
      # it performs the auth check and starts the login flow.
      locations."/outpost.goauthentik.io" = {
        proxyPass = "http://127.0.0.1:${toString authPort}/outpost.goauthentik.io";
        extraConfig = ''
          proxy_set_header Host $ak_http_host;
          proxy_set_header X-Forwarded-Host $ak_http_host;
          proxy_set_header X-Original-URL $scheme://$ak_http_host$request_uri;
          # Defense-in-depth for pre-2026.2.3 nginx forward-auth bypasses.
          proxy_set_header X-Original-URI "";
          add_header Set-Cookie $auth_cookie;
          auth_request_set $auth_cookie $upstream_http_set_cookie;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };

      locations."@goauthentik_proxy_signin".extraConfig = ''
        internal;
        add_header Set-Cookie $auth_cookie;
        return 302 /outpost.goauthentik.io/start?rd=$scheme://$ak_http_host$request_uri;
      '';
    };
  };

  # FBL fail-closed invariant: only nginx entrypoints are exposed. Neither
  # ComfyUI's backend nor Authentik's HTTPS/metrics/worker ports reach the LAN.
  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    (lib.optionals config.services.authentik.enable [ authPort ])
    ++ (lib.optionals
      (config.services.authentik.enable && config.services.comfyui.enable)
      [ comfyFrontendPort ]);
}
