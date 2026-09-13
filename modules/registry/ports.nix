{ lib, ... }:

{
  options.fbl.ports = {
    tcp = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      # Architectural invariant: assigned TCP/UDP port numbers live only in
      # this registry. Host, container, backend, protocol and helper modules
      # consume semantic fbl.ports keys and must not duplicate numeric ports.
      default = {
        dns = 53;
        http = 80;
        https = 443;
        ssh = 22;
        nextcloud = 80;
        # Cr01 internal Git forge / primary writable Git source.
        gitea = 3000;
        # Gitea built-in SSH listener for clone/push; system OpenSSH remains on ssh=22.
        giteaSsh = 2222;
        open-webui = 3001;
        # Authentik public nginx entrypoint; Authentik backend uses the same
        # number on loopback only.
        authentik = 9000;
        # Authentik worker/backend listeners stay loopback-only.
        authentikWorker = 9010;
        comfyui = 8188;
        # Authentik-protected nginx frontend for browser access to ComfyUI.
        comfyuiProtected = 8189;
        grafana = 3002;
        squid = 3128;
        squidTransparentHttp = 3129;
        squidTransparentHttps = 3130;
        nix-serve = 5000;
        ollama = 5001;
        prometheus = 5002;
        i2pConsole = 7070;
        qbittorrentWeb = 8081;
        metube = 8082;
        metubeContainer = 8081;
        jellyfin = 8096;
        jellyfinRuntime = 8096;
        privoxy = 8118;
        searxng = 8888;
        prometheusExporters = 9001;
        prometheusGpu = 9002;
        prometheusBB = 9003;
        prometheusSmartctl = 9004;
        torTrans = 9040;
        torSocks = 9050;
        prometheusHFNode = 9100;
        authentikMetrics = 9300;
        prometheusSquid = 9301;
        authentikWorkerMetrics = 9310;
        authentikHttps = 9443;
        i2pJabber = 9675;
        xraySocks = 10808;
        xrayTproxy = 12345;
        qbittorrentPeer = 49160;
      };
    };

    udp = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = {
        dns = 53;
        quic = 443;
        torDns = 9053;
        xrayTproxy = 12345;
        qbittorrentPeer = 49160;
        wireguard = 51820;
      };
    };
  };
}

# [GPT-5.6 Sol] изменил в 20:51 13.09.2026 (МСК).
