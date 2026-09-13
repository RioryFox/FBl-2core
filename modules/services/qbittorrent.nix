{ config, pkgs, ... }:

let
  cloudMount02 = config.fbl.storage.cloud02.mountPoint;
  downloadRoot = "${cloudMount02}/downloads";
  webPort = config.fbl.ports.tcp.qbittorrentWeb;
  peerTcpPort = config.fbl.ports.tcp.qbittorrentPeer;
  peerUdpPort = config.fbl.ports.udp.qbittorrentPeer;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  assertions = [
    {
      assertion = peerTcpPort == peerUdpPort;
      message = "FBL qBittorrent requires the same TCP/UDP peer port";
    }
  ];

  users.groups.fbl-downloads = { };

  services.qbittorrent = {
    enable = true;
    user = "qbittorrent";
    group = "fbl-downloads";
    profileDir = "/var/lib/qBittorrent";
    webuiPort = webPort;
    torrentingPort = peerTcpPort;
    openFirewall = false;
    extraArgs = [ "--confirm-legal-notice" ];
  };

  # Prepare external-storage directories only after the real CLOUD02 mount is
  # available. systemd-tmpfiles is intentionally not used below the mountpoint
  # so a missing disk can never create a fallback download tree on Cr01 root.
  systemd.services.qbittorrent-storage-prepare = {
    description = "Prepare qBittorrent storage on FBL_CLOUD02";
    before = [ "qbittorrent.service" ];
    requiredBy = [ "qbittorrent.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount02 ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 2770 -o qbittorrent -g fbl-downloads ${downloadRoot}
      ${pkgs.coreutils}/bin/install -d -m 2770 -o qbittorrent -g fbl-downloads ${downloadRoot}/Incoming
      ${pkgs.coreutils}/bin/install -d -m 2770 -o qbittorrent -g fbl-downloads ${downloadRoot}/Movies
      ${pkgs.coreutils}/bin/install -d -m 2770 -o qbittorrent -g fbl-downloads ${downloadRoot}/Video
      ${pkgs.coreutils}/bin/install -d -m 2770 -o qbittorrent -g fbl-downloads ${downloadRoot}/Books
    '';
  };

  systemd.services.qbittorrent.unitConfig.RequiresMountsFor = [ cloudMount02 ];

  # FBL LAN only; upstream NAT/port-forwarding remains a separate router policy.
  networking.firewall.interfaces.${lanInterface} = {
    allowedTCPPorts =
      if config.services.qbittorrent.enable
      then [ webPort peerTcpPort ]
      else [ ];
    allowedUDPPorts =
      if config.services.qbittorrent.enable
      then [ peerUdpPort ]
      else [ ];
  };
}

# GPT-5.6 Sol изменил в 18:15 05.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 00:43 13.09.2026 (МСК).
