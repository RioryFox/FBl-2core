{ lib, ... }:

{
  options.fbl.network = {
    lan = {
      cidr = lib.mkOption {
        type = lib.types.str;
        default = "192.168.3.0/24";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.3.1";
      };
    };

    upstream = {
      familyGateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.1.1";
      };
      dns = lib.mkOption {
        type = lib.types.str;
        default = "192.168.2.1";
      };
      publicDns = lib.mkOption {
        type = lib.types.str;
        default = "1.1.1.1";
      };
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        cr01 = "192.168.3.253";
        gf01 = "192.168.3.50";
        gf02 = "192.168.1.235"
      };
    };

    interfaces = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        cr01Lan = "enp3s0";
        gf01Lan = "enp4s0f4u1c2";
      };
    };

    hostLinks = {
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 30;
      };
    };
  };
}