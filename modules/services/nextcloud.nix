{ config, pkgs, ... }:

let
  cloudMount = config.fbl.storage.cloud01.mountPoint;
  cloudMount02 = config.fbl.storage.cloud02.mountPoint;
  cloud01Uuid = config.fbl.storage.cloud01.uuid;
  cloud02Uuid = config.fbl.storage.cloud02.uuid;
  nextcloudData = "${cloudMount}/nextcloud";
  nextcloudConfig = "${nextcloudData}/config";
  cloudExternal02 = "${cloudMount02}/nextcloud-external";
  adminPassFile = "/var/lib/fbl-secrets/nextcloud-admin-pass";
  address = config.fbl.network.hosts.cr01;
  familyGateway = config.fbl.network.upstream.familyGateway;
  port = config.fbl.ports.tcp.nextcloud;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  fileSystems."${cloudMount}" = {
    device = "/dev/disk/by-uuid/${cloud01Uuid}";
    fsType = "ext4";
  };

  fileSystems."${cloudMount02}" = {
    device = "/dev/disk/by-uuid/${cloud02Uuid}";
    fsType = "ext4";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/fbl-secrets 0700 root root -"
  ];

  users.groups.fbl-media = { };
  users.users.nextcloud.extraGroups = [ "fbl-media" ];
  users.users.homefox.extraGroups = [ "fbl-media" ];

  systemd.services.nextcloud-storage-prepare = {
    description = "Prepare FBL Cloud storage for Nextcloud";
    wantedBy = [ "multi-user.target" ];
    before = [ "nextcloud-setup.service" "phpfpm-nextcloud.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount cloudMount02 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 -o fbl-media -g fbl-media ${nextcloudData}
      ${pkgs.coreutils}/bin/install -d -m 0750 -o fbl-media -g fbl-media ${nextcloudConfig}
      ${pkgs.coreutils}/bin/install -d -m 0750 -o fbl-media -g fbl-media ${cloudExternal02}
      ${pkgs.coreutils}/bin/chown fbl-media:fbl-media ${nextcloudData} ${nextcloudConfig} ${cloudExternal02}
    '';
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = address;
    datadir = nextcloudData;
    database.createLocally = true;
    configureRedis = true;

    extraApps = {
      inherit (pkgs.nextcloud33Packages.apps) spreed;
    };
    extraAppsEnable = true;
    appstoreEnable = true;

    config = {
      dbtype = "pgsql";
      adminuser = "riory";
      adminpassFile = adminPassFile;
    };

    settings = {
      trusted_domains = [
        address
        familyGateway
        "cloud.fbl.lan"
      ];
      default_phone_region = "RU";
      maintenance_window_start = 3;
      log_type = "systemd";
    };
  };

  services.redis.servers.nextcloud.settings = {
    maxmemory = "1gb";
    maxmemory-policy = "allkeys-lru";
  };

  services.nginx.virtualHosts.${address}.listen = [
    {
      addr = address;
      inherit port;
    }
  ];

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.nextcloud.enable
    then [ port ]
    else [ ];

  systemd.services.nextcloud-setup = {
    requires = [ "nextcloud-storage-prepare.service" ];
    after = [ "nextcloud-storage-prepare.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount cloudMount02 ];
  };
  systemd.services."phpfpm-nextcloud" = {
    requires = [ "nextcloud-storage-prepare.service" ];
    after = [ "nextcloud-storage-prepare.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount cloudMount02 ];
  };

  systemd.services.nextcloud-fbl-cloud02 = {
    description = "Register FBL_CLOUD02 in Nextcloud";
    wantedBy = [ "multi-user.target" ];
    wants = [ "nextcloud-setup.service" ];
    after = [ "nextcloud-setup.service" "nextcloud-storage-prepare.service" ];
    requires = [ "nextcloud-storage-prepare.service" ];
    unitConfig.RequiresMountsFor = [ cloudMount02 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      OCC=/run/current-system/sw/bin/nextcloud-occ
      ${pkgs.util-linux}/bin/runuser -u nextcloud -- "$OCC" app:enable files_external >/dev/null

      if ! ${pkgs.util-linux}/bin/runuser -u nextcloud -- "$OCC" files_external:list | ${pkgs.gnugrep}/bin/grep -Fq "FBL_CLOUD02"; then
        ${pkgs.util-linux}/bin/runuser -u nextcloud -- "$OCC" files_external:create "/FBL_CLOUD02" local null::null -c datadir="${cloudExternal02}"
      fi
    '';
  };
}