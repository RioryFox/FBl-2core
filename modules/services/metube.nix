{ config, pkgs, ... }:

let
  cloudMount02 = config.fbl.storage.cloud02.mountPoint;
  downloadRoot = "${cloudMount02}/downloads/YouTube";
  stateRoot = "/var/lib/metube";
  hostAddress = config.fbl.network.hosts.cr01;
  hostPort = config.fbl.ports.tcp.metube;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
  containerPort = config.fbl.ports.tcp.metubeContainer;
  metubeEnabled = builtins.hasAttr "metube" config.virtualisation.oci-containers.containers;
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 0750 root root -"
  ];

  systemd.services.metube-storage-prepare = {
    description = "Prepare MeTube storage on FBL_CLOUD02";
    before = [ "podman-metube.service" ];
    requiredBy = [ "podman-metube.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount02 ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g users ${downloadRoot}
      ${pkgs.coreutils}/bin/install -d -m 2775 -o root -g users ${downloadRoot}/.tmp
    '';
  };

  virtualisation.oci-containers.containers.metube = {
    # TODO: pin to an immutable upstream tag/digest after runtime validation.
    image = "ghcr.io/alexta69/metube:latest";
    ports = [ "${hostAddress}:${toString hostPort}:${toString containerPort}" ];
    volumes = [
      "${downloadRoot}:/downloads"
      "${stateRoot}:/config"
    ];
    environment = {
      DOWNLOAD_DIR = "/downloads";
      AUDIO_DOWNLOAD_DIR = "/downloads";
      STATE_DIR = "/config";
      TEMP_DIR = "/downloads/.tmp";
      CUSTOM_DIRS = "true";
      CREATE_CUSTOM_DIRS = "true";
      DOWNLOAD_DIRS_INDEXABLE = "false";
      DEFAULT_THEME = "dark";
      UMASK = "002";
    };
  };

  systemd.services."podman-metube".unitConfig = {
    RequiresMountsFor = [ cloudMount02 ];
    ConditionPathIsMountPoint = cloudMount02;
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if metubeEnabled
    then [ hostPort ]
    else [ ];
}

# GPT-5.6 Sol изменил в 18:15 05.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 23:20 08.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 00:43 13.09.2026 (МСК).
