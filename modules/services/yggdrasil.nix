{ config, pkgs, ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;

    settings = {
      Peers = [
        "tls://ygg.mkg20001.io:443"
        "tls://yggpeer.tilde.green:59454"
        "tls://box.paulll.cc:13338"
        "tls://37.192.232.33:442"
        "tls://5.252.118.13:443"
      ];
    };
  };

  networking.nftables.tables.fbl-yggdrasil-guard = {
    family = "ip6";
    content = ''
      chain input {
        type filter hook input priority -10; policy accept;
        iifname "tun0" ct state != { established, related } drop
      }
    '';
  };

}