{ config, lib, pkgs, ... }:

let
  cfg = config.fbl.ihfGatewayTest;
  baseSquidPort = config.fbl.ports.tcp.squid;
  httpPort = config.fbl.ports.tcp.http;
  httpsPort = config.fbl.ports.tcp.https;
  quicPort = config.fbl.ports.udp.quic;
  defaultIngressInterface = config.fbl.network.interfaces.ihfLan;
  defaultClientCidr = config.fbl.network.lan.cidr;
  defaultHttpInterceptPort = config.fbl.ports.tcp.squidTransparentHttp;
  defaultHttpsInterceptPort = config.fbl.ports.tcp.squidTransparentHttps;
  caDir = "/var/lib/squid/mitm";
  certDb = "/var/lib/squid/ssl_db";

  interfaceMatch = lib.optionalString (cfg.egressInterface != null)
    ''oifname "${cfg.egressInterface}" '';

  httpsSquidConfig = lib.optionalString cfg.httpsMitm ''
    https_port 0.0.0.0:${toString cfg.httpsInterceptPort} intercept ssl-bump \
      generate-host-certificates=on dynamic_cert_mem_cache_size=16MB \
      tls-cert=${caDir}/ca.crt tls-key=${caDir}/ca.key

    sslcrtd_program /run/squid/security_file_certgen -s ${certDb} -M 16MB
    sslcrtd_children 4 startup=1 idle=1

    acl bump_step1 at_step SslBump1
    acl bump_step2 at_step SslBump2
    acl splice_sites ssl::server_name "${caDir}/splice-domains.txt"

    ssl_bump splice splice_sites
    ssl_bump peek bump_step1
    ssl_bump stare bump_step2
    ssl_bump bump all
  '';

  squidConfig = ''
    acl gateway_clients src ${cfg.clientCidr}
    acl localhost src 127.0.0.1/32 ::1
    acl manager proto cache_object
    acl SSL_ports port ${toString httpsPort}
    acl Safe_ports port ${toString httpPort}
    acl Safe_ports port ${toString httpsPort}
    acl CONNECT method CONNECT

    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow localhost manager
    http_access deny manager
    http_access deny to_localhost
    http_access allow gateway_clients
    http_access allow localhost
    http_access deny all

    # Existing explicit proxy plus a separate transparent HTTP listener.
    http_port 0.0.0.0:${toString baseSquidPort}
    http_port 0.0.0.0:${toString cfg.httpInterceptPort} intercept
    ${httpsSquidConfig}

    cache_effective_user squid squid
    pid_filename /run/squid.pid
    coredump_dir /var/cache/squid

    cache_mem 128 MB
    maximum_object_size_in_memory 512 KB
    maximum_object_size 256 MB
    cache_dir ufs /var/cache/squid 20480 16 256
    cache_replacement_policy heap LFUDA
    memory_replacement_policy heap GDSF

    cache_log stdio:/var/log/squid/cache.log
    access_log stdio:/var/log/squid/gateway-access.log
    cache_store_log none
    log_mime_hdrs on
    strip_query_terms off

    # Do not expose client addresses to origin servers.
    forwarded_for delete
    via off

    refresh_pattern ^ftp:             1440 20% 10080
    refresh_pattern ^gopher:          1440  0%  1440
    refresh_pattern -i (/cgi-bin/|\?) 0     0%     0
    refresh_pattern .                 0    20%  4320
  '';

  gatewayRules = pkgs.writeShellScript "ihf02-gateway-test-rules" ''
    set -eu

    ${pkgs.nftables}/bin/nft delete table inet ihf_gateway_test 2>/dev/null || true

    ${pkgs.nftables}/bin/nft -f - <<'NFT'
    table inet ihf_gateway_test {
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "${cfg.ingressInterface}" ip saddr ${cfg.clientCidr} tcp dport ${toString httpPort} redirect to :${toString cfg.httpInterceptPort}
        ${lib.optionalString cfg.httpsMitm ''iifname "${cfg.ingressInterface}" ip saddr ${cfg.clientCidr} tcp dport ${toString httpsPort} redirect to :${toString cfg.httpsInterceptPort}''}
      }

      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ${lib.optionalString cfg.masquerade ''ip saddr ${cfg.clientCidr} ${interfaceMatch}masquerade''}
      }

      ${lib.optionalString cfg.httpsMitm ''
      chain block_quic {
        type filter hook forward priority filter; policy accept;
        ip saddr ${cfg.clientCidr} udp dport ${toString quicPort} reject
      }
      ''}
    }
    NFT
  '';

  removeGatewayRules = pkgs.writeShellScript "ihf02-gateway-test-rules-remove" ''
    ${pkgs.nftables}/bin/nft delete table inet ihf_gateway_test 2>/dev/null || true
  '';
in
{
  options.fbl.ihfGatewayTest = {
    enable = lib.mkEnableOption "the isolated iHF02 transparent gateway test";

    ingressInterface = lib.mkOption {
      type = lib.types.str;
      default = defaultIngressInterface;
      description = "Interface receiving policy-routed client traffic from MikroTik.";
    };

    egressInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional interface restriction for source NAT; null also supports a later VPN TUN interface.";
    };

    clientCidr = lib.mkOption {
      type = lib.types.str;
      default = defaultClientCidr;
      description = "Only this isolated MikroTik test subnet is intercepted.";
    };

    httpInterceptPort = lib.mkOption {
      type = lib.types.port;
      default = defaultHttpInterceptPort;
    };

    httpsInterceptPort = lib.mkOption {
      type = lib.types.port;
      default = defaultHttpsInterceptPort;
    };

    httpsMitm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable TLS interception for lab-owned clients that trust the generated test CA.";
    };

    masquerade = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Source-NAT the test subnet so no return route is required during initial tests.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.squid.enable;
        message = "fbl.ihfGatewayTest requires services.squid.enable from hf-proxy.nix";
      }
    ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
    };

    networking.firewall.interfaces.${cfg.ingressInterface}.allowedTCPPorts =
      [ cfg.httpInterceptPort ]
      ++ lib.optional cfg.httpsMitm cfg.httpsInterceptPort;

    environment.systemPackages = with pkgs; [ nftables openssl ];

    # Test mode replaces only Squid's generated text. Suricata and the other
    # services from hf-proxy.nix remain enabled and unchanged.
    services.squid.configText = lib.mkForce squidConfig;

    systemd.tmpfiles.rules = [
      "d ${caDir} 0750 root squid -"
      "f ${caDir}/splice-domains.txt 0644 root squid -"
    ];

    systemd.services.ihf02-mitm-ca-init = lib.mkIf cfg.httpsMitm {
      description = "Create the local iHF02 test MITM CA outside the Nix store";
      before = [ "squid.service" ];
      requiredBy = [ "squid.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g squid ${caDir}

        if [ ! -s ${caDir}/ca.key ] || [ ! -s ${caDir}/ca.crt ]; then
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:3072 -sha256 \
            -nodes -days 3650 \
            -subj "/CN=FBL iHF02 Test MITM CA/O=FBL Lab/OU=HF" \
            -addext "basicConstraints=critical,CA:TRUE" \
            -addext "keyUsage=critical,keyCertSign,cRLSign" \
            -keyout ${caDir}/ca.key \
            -out ${caDir}/ca.crt
        fi

        ${pkgs.coreutils}/bin/chown root:squid ${caDir}/ca.key ${caDir}/ca.crt
        ${pkgs.coreutils}/bin/chmod 0640 ${caDir}/ca.key
        ${pkgs.coreutils}/bin/chmod 0644 ${caDir}/ca.crt
      '';
    };

    systemd.services.squid = lib.mkIf cfg.httpsMitm {
      preStart = lib.mkBefore ''
        set -euo pipefail
        certgen="${pkgs.squid}/libexec/security_file_certgen"
        if [ ! -x "$certgen" ]; then
          certgen="$(${pkgs.findutils}/bin/find ${pkgs.squid} -type f -name security_file_certgen -print -quit)"
        fi
        if [ -z "$certgen" ] || [ ! -x "$certgen" ]; then
          echo "Squid certificate generator was not found" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/install -d -m 0755 /run/squid
        ${pkgs.coreutils}/bin/ln -sfn "$certgen" /run/squid/security_file_certgen

        if [ ! -f ${certDb}/index.txt ]; then
          ${pkgs.coreutils}/bin/rm -rf ${certDb}
          "$certgen" -c -s ${certDb} -M 16MB
        fi
        ${pkgs.coreutils}/bin/chown -R squid:squid ${certDb}
      '';
    };

    systemd.services.ihf02-gateway-test = {
      description = "Transparent gateway rules for the isolated iHF02 test subnet";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "squid.service" ];
      requires = [ "squid.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = gatewayRules;
        ExecStop = removeGatewayRules;
      };
    };
  };
}
