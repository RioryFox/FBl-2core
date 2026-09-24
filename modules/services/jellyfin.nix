{ config, pkgs, ... }:

let
  cloudMount02 = config.fbl.storage.cloud02.mountPoint;
  mediaRoot = "${cloudMount02}";
  port = config.fbl.ports.tcp.jellyfin;
  runtimePort = config.fbl.ports.tcp.jellyfinRuntime;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  assertions = [
    {
      assertion = port == runtimePort;
      message = "Jellyfin runtime port is not yet exposed by the NixOS module; keep fbl.ports.tcp.jellyfin aligned with fbl.ports.tcp.jellyfinRuntime until network.xml is managed declaratively";
    }
  ];

  # Jellyfin runs on Cr01 while the media payload stays on FBL_CLOUD02.
  # Metadata/cache remain on the system disk; large media remains separate
  # from Nextcloud's data tree.
  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
  };

  users.groups.fbl-media = { };
  users.users.jellyfin.extraGroups = [ "fbl-media" ];
  users.users.homefox.extraGroups = [ "fbl-media" ];

  systemd.services.jellyfin-media-prepare = {
    description = "Prepare FBL media library on FBL_CLOUD02";
    wantedBy = [ "multi-user.target" ];
    before = [ "jellyfin.service" ];
    requiredBy = [ "jellyfin.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount02 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g fbl-media ${mediaRoot}
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g fbl-media ${mediaRoot}/Movies
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g fbl-media ${mediaRoot}/Series
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g fbl-media ${mediaRoot}/HomeVideo
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g fbl-media ${mediaRoot}/Education
    '';
  };

  systemd.services.jellyfin = {
    after = [ "jellyfin-media-prepare.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount02 ];
  };

  # Jellyfin's runtime listener remains upstream-managed for now. Both the
  # runtime constraint and LAN exposure are registry-owned, so no module
  # duplicates its numeric port.
  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.jellyfin.enable
    then [ port ]
    else [ ];
}
