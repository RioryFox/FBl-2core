{ lib, ... }:

{
  options.fbl.storage = {
    # Rebuildable/high-speed payload root on the Cr01 ADATA NVMe. Unique data
    # must not rely on this as its only copy.
    hotRoot = lib.mkOption {
      type = lib.types.str;
      default = "/nix/fbl-hot";
    };

    cloud01 = {
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/srv/fbl-cloud";
      };
      uuid = lib.mkOption {
        type = lib.types.str;
        default = "953c8e3a-7289-419d-91b0-2997529bcbd8";
      };
    };

    cloud02 = {
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/srv/fbl-cloud-02";
      };
      uuid = lib.mkOption {
        type = lib.types.str;
        default = "af7640a3-c763-4cd9-8a09-afd0675f9e8b";
      };
    };

    cr01Mirror = {
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/cr01-mirror";
      };
      label = lib.mkOption {
        type = lib.types.str;
        default = "CR01_MIRROR";
      };
    };
  };
}