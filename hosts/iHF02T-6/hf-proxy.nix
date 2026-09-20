{ config, pkgs, ... }:

let
  squidPort = config.fbl.ports.tcp.squid;
  httpPort = config.fbl.ports.tcp.http;
  httpsPort = config.fbl.ports.tcp.https;
  privoxyPort = config.fbl.ports.tcp.privoxy;
  xraySocksPort = config.fbl.ports.tcp.xraySocks;
  nodePort = config.fbl.ports.tcp.prometheusHFNode;
  squidExporterPort = config.fbl.ports.tcp.prometheusSquid;
  lanAddress = config.fbl.network.hosts.ihf02;
  lanInterface = config.fbl.network.interfaces.ihfLan;
in
{
  services.squid = {
    enable = true;
    proxyAddress = lanAddress;
    proxyPort = squidPort;
    configText = ''
      acl localnet src 10.0.0.0/8
      acl localnet src 172.16.0.0/12
      acl localnet src 192.168.0.0/16
      acl localnet src 169.254.0.0/16
      acl localnet src fc00::/7
      acl localnet src fe80::/10
      acl SSL_ports port ${toString httpsPort}
      acl Safe_ports port ${toString httpPort}
      acl Safe_ports port ${toString httpsPort}
      acl CONNECT method CONNECT
      http_access deny !Safe_ports
      http_access deny CONNECT !SSL_ports
      http_access allow localhost manager
      http_access deny manager
      http_access deny to_localhost
      http_access allow localnet
      http_access allow localhost
      http_access deny all
      http_port ${lanAddress}:${toString squidPort}
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
      access_log stdio:/var/log/squid/access.log
      cache_store_log none
      log_mime_hdrs on
      strip_query_terms off
      cache_peer 127.0.0.1 parent ${toString privoxyPort} 0 no-query default
      never_direct allow all
      refresh_pattern ^ftp:             1440 20% 10080
      refresh_pattern ^gopher:          1440  0%  1440
      refresh_pattern -i (/cgi-bin/|\?) 0     0%     0
      refresh_pattern .                 0    20%  4320
    '';
  };

  services.privoxy = {
    enable = true;
    inspectHttps = false;
    settings = {
      listen-address = "127.0.0.1:${toString privoxyPort}";
      # Fail-closed egress: resolve destinations through Xray SOCKS5 and
      # never fall back to the host's direct WAN for proxied web traffic.
      "forward-socks5" = "/ 127.0.0.1:${toString xraySocksPort} .";
      toggle = false;
      enable-remote-toggle = false;
      enable-remote-http-toggle = false;
      enable-edit-actions = false;
      enforce-blocks = true;
      # Disable upstream connection sharing: HTTPS CONNECT tunnels over
      # Xray SOCKS5 must stay bound to their own upstream stream.
      connection-sharing = false;
      keep-alive-timeout = 300;
      debug = [ 1024 4096 ];
    };
  };

  # Startup ordering only; fail-closed behavior is provided by Privoxy's
  # unconditional SOCKS5 forwarding and Squid's never_direct rule.
  systemd.services.privoxy = {
    requires = [ "fbl-xray.service" ];
    after = [ "fbl-xray.service" ];
  };

  systemd.services.squid = {
    requires = [ "privoxy.service" "fbl-xray.service" ];
    after = [ "privoxy.service" "fbl-xray.service" ];
  };

  services.suricata = {
    enable = true;
    enabledSources = [ "et/open" "abuse.ch/sslbl-c2" "oisf/trafficid" ];
    settings = {
      vars.address-groups = {
        HOME_NET = "[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7]";
        EXTERNAL_NET = "!$HOME_NET";
      };
      stats = { enable = true; interval = "30"; };
      outputs = [
        { fast = { enabled = true; filename = "fast.log"; append = "yes"; }; }
        {
          eve-log = {
            enabled = true;
            filetype = "regular";
            filename = "eve.json";
            community-id = true;
            types = [ "alert" "http" "dns" "tls" "anomaly" ];
          };
        }
      ];
      af-packet = [
        {
          interface = lanInterface;
          threads = 1;
          cluster-id = "99";
          cluster-type = "cluster_flow";
          defrag = "yes";
          "tpacket-v3" = "yes";
        }
      ];
    };
  };

  services.clamav.updater = {
    enable = true;
    frequency = 1;
    interval = "*-*-* 03:30:00";
  };

  systemd.tmpfiles.rules = [ "d /var/log/clamav 0750 root root -" ];

  systemd.services.ihf02-cache-malware-scan = {
    description = "Scan the iHF02 Squid cache with ClamAV";
    after = [ "clamav-freshclam.service" "squid.service" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 15;
      IOSchedulingClass = "idle";
      MemoryHigh = "1400M";
      MemoryMax = "1800M";
    };
    script = ''
      result=0
      ${pkgs.clamav}/bin/clamscan --recursive --infected \
        --log=/var/log/clamav/squid-cache.log /var/cache/squid || result=$?
      if [ "$result" -eq 1 ]; then
        ${pkgs.util-linux}/bin/logger -p security.warning \
          "ClamAV detected content in Squid cache; see its log"
        exit 0
      fi
      exit "$result"
    '';
  };

  systemd.timers.ihf02-cache-malware-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = nodePort;
    enabledCollectors = [ "systemd" ];
  };

  systemd.services.ihf02-squid-exporter = {
    description = "Prometheus exporter for iHF02 Squid";
    wantedBy = [ "multi-user.target" ];
    after = [ "squid.service" ];
    wants = [ "squid.service" ];
    serviceConfig = {
      DynamicUser = true;
      Restart = "on-failure";
      ExecStart = ''
        ${pkgs.prometheus-squid-exporter}/bin/squid-exporter \
          -squid-hostname 127.0.0.1 -squid-port ${toString squidPort} -listen 127.0.0.1:${toString squidExporterPort}
      '';
    };
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.squid.enable
    then [ squidPort ]
    else [ ];
}
