{ config, pkgs, ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;

    settings = {
      Peers = [
        "tls://yggmkg20001.io:443"
        "tls://yggpeer.tilde.green:59454"
      ];
    };
  };
}