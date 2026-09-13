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
        ihf02 = "192.168.3.254";
        ivn01 = "192.168.3.9";
        iaf01 = "192.168.3.8";
      };
    };

    interfaces = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        cr01Lan = "enp3s0";
        cr01IhfHost = "vm-ihf02-host";
        cr01IvnHost = "vm-ivn01-host";
        cr01IafHost = "vm-iaf01-host";
        ihfLan = "eth0";
        ihfHost = "eth1";
        ivnLan = "eth0";
        ivnHost = "eth1";
        iafLan = "eth0";
        iafHost = "eth1";
      };
    };

    hostLinks = {
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 30;
      };
      cr01Ihf = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          host = "10.254.0.1";
          guest = "10.254.0.2";
        };
      };
      cr01Ivn = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          host = "10.252.0.1";
          guest = "10.252.0.2";
        };
      };
      cr01Iaf = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          host = "10.253.8.1";
          guest = "10.253.8.2";
        };
      };
    };

    wireguard = {
      cidr = lib.mkOption {
        type = lib.types.str;
        default = "10.66.0.0/24";
      };
      serverAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.66.0.1";
      };
      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
      };
    };
  };
}

# [GPT-5.6 Sol] изменил в 23:03 05.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:14 06.09.2026 (МСК).
