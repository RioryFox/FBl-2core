{ config, pkgs, ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;

    settings = {
      Peers = [
        "tls://ygg.mkg20001.io:443"
        "tls://ygg.peer.tilde.green:59454"
        "tls://37.192.232.33:442"
        "tls://5.252.118.13:443"
      ];
    };
  };
}