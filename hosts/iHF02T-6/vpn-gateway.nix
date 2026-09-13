{ config, lib, pkgs, ... }:

let
  cfg = config.fbl.vpnGateway;
  tcfg = cfg.transit;
  defaultLanInterface = config.fbl.network.interfaces.ihfLan;
  defaultLanCidr = config.fbl.network.lan.cidr;
  defaultXraySocksPort = config.fbl.ports.tcp.xraySocks;
  xrayTproxyTcpPort = config.fbl.ports.tcp.xrayTproxy;
  xrayTproxyUdpPort = config.fbl.ports.udp.xrayTproxy;
  defaultXrayTproxyPort = xrayTproxyTcpPort;
  defaultTorSocksPort = config.fbl.ports.tcp.torSocks;
  defaultTorTransPort = config.fbl.ports.tcp.torTrans;
  defaultTorDnsPort = config.fbl.ports.udp.torDns;
  dnsTcpPort = config.fbl.ports.tcp.dns;
  dnsUdpPort = config.fbl.ports.udp.dns;
  defaultDnsUpstream = config.fbl.network.upstream.publicDns;

  vpnClientElements = lib.concatStringsSep ", " tcfg.vpnClients;
  torClientElements = lib.concatStringsSep ", " tcfg.torClients;
  managedClients = lib.unique (tcfg.vpnClients ++ tcfg.torClients);
  managedClientElements = lib.concatStringsSep ", " managedClients;
  vpnSetElements = lib.optionalString (tcfg.vpnClients != [ ]) "elements = { ${vpnClientElements} }";
  torSetElements = lib.optionalString (tcfg.torClients != [ ]) "elements = { ${torClientElements} }";
  torInputRules = lib.optionalString (tcfg.torClients != [ ]) ''
    ip saddr { ${torClientElements} } tcp dport ${toString cfg.torTransPort} accept
    ip saddr { ${torClientElements} } udp dport ${toString cfg.torDnsPort} accept
  '';

  xrayConfigGenerator = pkgs.writeShellApplication {
    name = "fbl-xray-config-generate";
    runtimeInputs = with pkgs; [ coreutils python3 ];
    text = ''
      set -euo pipefail
      umask 077
      install -d -m 0700 "$(dirname ${lib.escapeShellArg cfg.runtimeConfigFile})"

      export FBL_VLESS_SOURCE=${lib.escapeShellArg cfg.vlessSourceFile}
      export FBL_XRAY_CONFIG=${lib.escapeShellArg cfg.runtimeConfigFile}
      export FBL_XRAY_SOCKS_PORT=${toString cfg.xraySocksPort}
      export FBL_XRAY_TPROXY_PORT=${toString cfg.xrayTproxyPort}
      export FBL_DNS_UPSTREAM=${lib.escapeShellArg cfg.dnsUpstream}
      export FBL_DNS_TCP_PORT=${toString dnsTcpPort}
      export FBL_DNS_UDP_PORT=${toString dnsUdpPort}
      export FBL_TRANSIT_ENABLE=${if tcfg.enable then "1" else "0"}
      ${pkgs.python3}/bin/python3 <<'PY'
      import base64
      import json
      import os
      import uuid
      from pathlib import Path
      from urllib.parse import parse_qs, urlparse

      source_path = Path(os.environ["FBL_VLESS_SOURCE"])
      output_path = Path(os.environ["FBL_XRAY_CONFIG"])
      socks_port = int(os.environ["FBL_XRAY_SOCKS_PORT"])
      tproxy_port = int(os.environ["FBL_XRAY_TPROXY_PORT"])
      dns_upstream = os.environ["FBL_DNS_UPSTREAM"]
      dns_tcp_port = int(os.environ["FBL_DNS_TCP_PORT"])
      dns_udp_port = int(os.environ["FBL_DNS_UDP_PORT"])
      transit_enabled = os.environ["FBL_TRANSIT_ENABLE"] == "1"
      st = source_path.stat()
      if st.st_uid != 0:
          raise SystemExit("FBL VLESS source must be owned by root")
      if st.st_mode & 0o077:
          raise SystemExit("FBL VLESS source must not be readable/writable/executable by group or others")

      payload = source_path.read_text(encoding="utf-8").strip()
      if not payload:
          raise SystemExit("FBL VLESS source file is empty")

      def first_vless(text: str):
          for line in text.replace("\r", "\n").splitlines():
              line = line.strip()
              if line.startswith("vless://"):
                  return line
          return None

      uri = first_vless(payload)
      if uri is None:
          compact = "".join(payload.split())
          padded = compact + "=" * ((4 - len(compact) % 4) % 4)
          decoded = None
          for decoder in (base64.b64decode, base64.urlsafe_b64decode):
              try:
                  decoded = decoder(padded).decode("utf-8", errors="strict")
                  break
              except Exception:
                  pass
          if decoded is None:
              raise SystemExit("Subscription response is neither a VLESS URI nor decodable Base64")
          uri = first_vless(decoded)

      if uri is None:
          raise SystemExit("No vless:// profile found in subscription")

      parsed = urlparse(uri)
      query = {key: values[0] for key, values in parse_qs(parsed.query).items() if values}

      if parsed.scheme != "vless" or not parsed.hostname or not parsed.port or not parsed.username:
          raise SystemExit("Invalid VLESS URI")

      try:
          uuid.UUID(parsed.username)
      except ValueError as exc:
          raise SystemExit("VLESS user id is not a valid UUID") from exc

      required = {
          "security": "reality",
          "type": "xhttp",
      }
      for key, expected in required.items():
          if query.get(key) != expected:
              raise SystemExit(f"Unsupported profile: expected {key}={expected}")

      for key in ("pbk", "sid", "sni"):
          if not query.get(key):
              raise SystemExit(f"VLESS REALITY profile is missing {key}")

      user = {
          "id": parsed.username,
          "encryption": query.get("encryption", "none"),
      }
      if query.get("flow"):
          user["flow"] = query["flow"]

      vless_out = {
          "tag": "vless-out",
          "protocol": "vless",
          "settings": {
              "vnext": [
                  {
                      "address": parsed.hostname,
                      "port": parsed.port,
                      "users": [user],
                  }
              ]
          },
          "streamSettings": {
              # Xray 26.3.27 on iHF02T-6 has been empirically validated with
              # the legacy-compatible network=xhttp form below.
              "network": "xhttp",
              "security": "reality",
              "xhttpSettings": {
                  "path": query.get("path", "/"),
                  "mode": query.get("mode", "auto"),
              },
              "realitySettings": {
                  "serverName": query["sni"],
                  "fingerprint": query.get("fp", "firefox"),
                  "password": query["pbk"],
                  "shortId": query["sid"],
                  "spiderX": query.get("spx", ""),
              },
          },
      }

      inbounds = [
          {
              "tag": "socks-in",
              "listen": "127.0.0.1",
              "port": socks_port,
              "protocol": "socks",
              "settings": {"udp": True},
          }
      ]
      outbounds = [vless_out]
      routing_rules = []

      if transit_enabled:
          inbounds.append(
              {
                  "tag": "transparent-in",
                  "listen": "0.0.0.0",
                  "port": tproxy_port,
                  "protocol": "tunnel",
                  "settings": {
                      "allowedNetwork": "tcp,udp",
                      "followRedirect": True,
                  },
                  "streamSettings": {
                      "sockopt": {"tproxy": "tproxy"},
                  },
              }
          )
          outbounds.append(
              {
                  "tag": "dns-out",
                  "protocol": "dns",
                  "settings": {
                      "rewriteNetwork": "udp",
                      "rewriteAddress": dns_upstream,
                      "rewritePort": dns_udp_port,
                      "rules": [{"action": "direct"}],
                  },
                  "proxySettings": {"tag": "vless-out"},
              }
          )
          routing_rules.append(
              {
                  "type": "field",
                  "inboundTag": ["transparent-in"],
                  "network": "tcp",
                  "port": str(dns_tcp_port),
                  "outboundTag": "dns-out",
              }
          )
          routing_rules.append(
              {
                  "type": "field",
                  "inboundTag": ["transparent-in"],
                  "network": "udp",
                  "port": str(dns_udp_port),
                  "outboundTag": "dns-out",
              }
          )

      cfg = {
          "log": {"loglevel": "warning"},
          "inbounds": inbounds,
          "outbounds": outbounds,
          "routing": {
              "domainStrategy": "AsIs",
              "rules": routing_rules,
          },
      }

      tmp = output_path.with_suffix(output_path.suffix + ".tmp")
      tmp.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
      os.chmod(tmp, 0o600)
      os.replace(tmp, output_path)
      print("FBL Xray runtime config generated; credentials were not printed")
      PY
    '';
  };

  vpnCheck = pkgs.writeShellApplication {
    name = "fbl-vpn-check";
    runtimeInputs = with pkgs; [ coreutils curl ];
    text = ''
      set -euo pipefail
      for _ in $(seq 1 12); do
        if curl -4 -fsS --connect-timeout 5 --max-time 12 \
          --socks5-hostname 127.0.0.1:${toString cfg.xraySocksPort} \
          ${lib.escapeShellArg cfg.healthCheckUrl} >/dev/null; then
          echo "FBL VLESS health check passed"
          exit 0
        fi
        sleep 5
      done
      echo "FBL VLESS health check failed" >&2
      exit 1
    '';
  };

  privacyRouterStart = pkgs.writeShellScript "fbl-privacy-router-start" ''
    set -euo pipefail

    ${pkgs.iproute2}/bin/ip rule del fwmark 0x1/0x1 table 100 priority 100 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip route flush table 100 2>/dev/null || true
    ${pkgs.nftables}/bin/nft delete table inet fbl_privacy 2>/dev/null || true

    ${pkgs.iproute2}/bin/ip route add local 0.0.0.0/0 dev lo table 100
    ${pkgs.iproute2}/bin/ip rule add fwmark 0x1/0x1 table 100 priority 100

    ${pkgs.nftables}/bin/nft -f - <<'NFT'
    table inet fbl_privacy {
      set private_v4 {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 }
      }

      set vpn_clients {
        type ipv4_addr
        flags interval
        ${vpnSetElements}
      }

      set tor_clients {
        type ipv4_addr
        flags interval
        ${torSetElements}
      }

      chain prerouting_mangle {
        type filter hook prerouting priority mangle; policy accept;

        # Tor mode: TCP DNS must not bypass Tor; Tor DNSPort only accepts UDP.
        iifname "${cfg.lanInterface}" ip saddr @tor_clients tcp dport ${toString dnsTcpPort} drop
        iifname "${cfg.lanInterface}" ip saddr @tor_clients ip daddr @private_v4 return
        iifname "${cfg.lanInterface}" ip saddr @tor_clients udp dport != ${toString dnsUdpPort} drop

        # VPN mode: capture DNS even when DHCP points clients at the private
        # the private DHCP DNS; Xray rewrites it to cfg.dnsUpstream over VLESS.
        iifname "${cfg.lanInterface}" ip saddr @vpn_clients tcp dport ${toString dnsTcpPort} meta mark set 0x1 tproxy to :${toString cfg.xrayTproxyPort} accept
        iifname "${cfg.lanInterface}" ip saddr @vpn_clients udp dport ${toString dnsUdpPort} meta mark set 0x1 tproxy to :${toString cfg.xrayTproxyPort} accept
        iifname "${cfg.lanInterface}" ip saddr @vpn_clients ip daddr @private_v4 return
        iifname "${cfg.lanInterface}" ip saddr @vpn_clients meta l4proto { tcp, udp } meta mark set 0x1 tproxy to :${toString cfg.xrayTproxyPort} accept
      }

      chain prerouting_nat {
        type nat hook prerouting priority dstnat; policy accept;

        # UDP DNS goes to Tor DNSPort. Other public UDP was already dropped.
        iifname "${cfg.lanInterface}" ip saddr @tor_clients udp dport ${toString dnsUdpPort} redirect to :${toString cfg.torDnsPort}
        iifname "${cfg.lanInterface}" ip saddr @tor_clients ip daddr @private_v4 return
        iifname "${cfg.lanInterface}" ip saddr @tor_clients tcp redirect to :${toString cfg.torTransPort}
      }
    }
    NFT
  '';

  privacyRouterStop = pkgs.writeShellScript "fbl-privacy-router-stop" ''
    set -u
    ${pkgs.nftables}/bin/nft delete table inet fbl_privacy 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip rule del fwmark 0x1/0x1 table 100 priority 100 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip route flush table 100 2>/dev/null || true
  '';
in
{
  options.fbl.vpnGateway = {
    enable = lib.mkEnableOption "the headless FBL VLESS privacy gateway stack";

    vlessSourceFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fbl-secrets/vless.uri";
      description = ''
        Root-only persistent source containing one vless:// URI (or a locally
        saved Base64 subscription payload). Its contents must never enter the Nix store.
      '';
    };

    runtimeConfigFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/xray.json";
      description = "Generated runtime-only Xray configuration.";
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = defaultLanInterface;
      description = "FBL LAN interface receiving policy-routed transit traffic.";
    };

    lanCidr = lib.mkOption {
      type = lib.types.str;
      default = defaultLanCidr;
      description = "Current FBL IPv4 LAN; used only for Tor systemd network access policy.";
    };

    xraySocksPort = lib.mkOption {
      type = lib.types.port;
      default = defaultXraySocksPort;
    };

    xrayTproxyPort = lib.mkOption {
      type = lib.types.port;
      default = defaultXrayTproxyPort;
    };

    torSocksPort = lib.mkOption {
      type = lib.types.port;
      default = defaultTorSocksPort;
      description = "Loopback-only Tor SOCKS port used for local chain validation.";
    };

    torTransPort = lib.mkOption {
      type = lib.types.port;
      default = defaultTorTransPort;
    };

    torDnsPort = lib.mkOption {
      type = lib.types.port;
      default = defaultTorDnsPort;
    };

    dnsUpstream = lib.mkOption {
      type = lib.types.str;
      default = defaultDnsUpstream;
      description = "Public DNS endpoint used only through the VLESS outbound for VPN-mode clients.";
    };

    healthCheckUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://ifconfig.me/ip";
      description = "HTTPS target used to verify that the local Xray SOCKS path is alive.";
    };

    transit = {
      enable = lib.mkEnableOption "policy-routed FBL transit interception";

      vpnClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "192.168.3.100" ];
        description = "Exact IPv4 client addresses routed through VLESS only.";
      };

      torClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "192.168.3.101" ];
        description = "Exact IPv4 client addresses routed through Tor over VLESS.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = xrayTproxyTcpPort == xrayTproxyUdpPort;
          message = "fbl.vpnGateway requires matching TCP/UDP xrayTproxy registry ports because one Xray transparent inbound handles both protocols";
        }
        {
          assertion = lib.intersectLists tcfg.vpnClients tcfg.torClients == [ ];
          message = "fbl.vpnGateway: a client may not be in both vpnClients and torClients";
        }
        {
          assertion = (!tcfg.enable) || managedClients != [ ];
          message = "fbl.vpnGateway.transit.enable requires at least one VPN or Tor client";
        }
      ];

      environment.systemPackages = [ pkgs.xray pkgs.tor pkgs.nftables pkgs.iproute2 xrayConfigGenerator vpnCheck ];

      systemd.tmpfiles.rules = [
        "d /var/lib/fbl-secrets 0700 root root -"
        "d /run/secrets 0700 root root -"
      ];

      systemd.services.fbl-xray-config = {
        description = "Generate FBL Xray config from the local VLESS source";
        restartTriggers = [ xrayConfigGenerator ];
        before = [ "fbl-xray.service" ];
        requiredBy = [ "fbl-xray.service" ];
        unitConfig.ConditionFileNotEmpty = cfg.vlessSourceFile;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${xrayConfigGenerator}/bin/fbl-xray-config-generate";
          UMask = "0077";
        };
      };

      systemd.services.fbl-xray = {
        description = "FBL VLESS/Xray privacy underlay";
        restartTriggers = [ xrayConfigGenerator ];
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" "fbl-xray-config.service" ];
        requires = [ "fbl-xray-config.service" ];
        unitConfig.ConditionFileNotEmpty = cfg.vlessSourceFile;
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${pkgs.xray}/bin/xray run -test -config ${cfg.runtimeConfigFile}";
          ExecStart = "${pkgs.xray}/bin/xray run -config ${cfg.runtimeConfigFile}";
          ExecStartPost = "${vpnCheck}/bin/fbl-vpn-check";
          Restart = "on-failure";
          RestartSec = "10s";
          UMask = "0077";
        };
      };

      services.tor = {
        enable = true;
        client = {
          enable = true;
          socksListenAddress = {
            addr = "127.0.0.1";
            port = cfg.torSocksPort;
          };
        };
        settings = {
          ClientOnly = true;
          Socks5Proxy = "127.0.0.1:${toString cfg.xraySocksPort}";
          TransPort = lib.optionals (tcfg.enable && tcfg.torClients != [ ]) [
            {
              addr = "0.0.0.0";
              port = cfg.torTransPort;
              IsolateClientAddr = true;
              IsolateDestAddr = true;
              IsolateDestPort = true;
            }
          ];
          DNSPort = lib.optionals (tcfg.enable && tcfg.torClients != [ ]) [
            {
              addr = "0.0.0.0";
              port = cfg.torDnsPort;
              IsolateClientAddr = true;
            }
          ];
          ClientUseIPv4 = true;
          ClientUseIPv6 = false;
        };
      };

      # Tor's OR connections are forced through the local Xray SOCKS port.
      # IPAddressDeny is a second fail-closed layer: Tor itself cannot open a
      # public socket even if its proxy setting is accidentally changed later.
      systemd.services.tor = {
        wants = [ "fbl-xray.service" ];
        after = [ "fbl-xray.service" ];
        unitConfig.ConditionFileNotEmpty = cfg.vlessSourceFile;
        serviceConfig = {
          ExecStartPre = lib.mkAfter [ "${vpnCheck}/bin/fbl-vpn-check" ];
          IPAddressDeny = "any";
          IPAddressAllow = [ "127.0.0.0/8" "::1/128" cfg.lanCidr ];
          Restart = "on-failure";
          RestartSec = "15s";
        };
      };

      # Do not route IPv6 transit until an explicit dual-stack privacy design
      # exists. Selected clients must also have IPv6 direct fallback blocked on
      # MikroTik; traffic that never reaches iHF cannot be stopped here.
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = if tcfg.enable then 1 else 0;
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
        "net.ipv4.conf.${cfg.lanInterface}.send_redirects" = 0;
      };
    }

    (lib.mkIf tcfg.enable {
      networking.nftables.enable = true;
      networking.firewall = {
        checkReversePath = "loose";
        filterForward = true;

        # TPROXY/REDIRECT packets are locally delivered after these marks are
        # applied by fbl_privacy; untrusted wire traffic arrives unmarked.
        extraInputRules = ''
          meta mark & 0x1 == 0x1 accept
          ${torInputRules}
        '';
        extraReversePathFilterRules = ''
          meta mark & 0x1 == 0x1 accept
        '';

        # Independent fail-closed barrier: public forwarding is never allowed
        # for managed privacy clients. Public traffic must become local via
        # Xray/Tor interception; only RFC1918/link-local destinations may be
        # forwarded directly for LAN management/resources.
        extraForwardRules = ''
          ip saddr { ${managedClientElements} } ip daddr { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 } accept
        '';
      };

      systemd.services.fbl-privacy-router = {
        description = "FBL fail-closed transparent routing for selected clients";
        wantedBy = [ "multi-user.target" ];
        wants = [ "fbl-xray.service" ] ++ lib.optional (tcfg.torClients != [ ]) "tor.service";
        after = [ "network-online.target" "nftables.service" "fbl-xray.service" ] ++ lib.optional (tcfg.torClients != [ ]) "tor.service";
        requires = [ "nftables.service" ];
        unitConfig.ConditionFileNotEmpty = cfg.vlessSourceFile;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = privacyRouterStart;
          ExecStop = privacyRouterStop;
        };
      };
    })
  ]);
}
