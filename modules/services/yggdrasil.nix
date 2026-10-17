{ config, pkgs, ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;

    settings = {
      Peers = [
        "tls://ygg.mkg20001.io:443"
        "tls://yggpeer.tilde.green:5945"
        "tls://box.paulll.cc:13338"
        "tls://37.192.232.33:442"
        "tls://5.252.118.13:443"
      ];
    };
  };

  networking.firewall.extraCommands = ''
    ip6tables -A INPUT -i tun0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -i tun0 -m conntrack --ctstate INVALID -j DROP
    ip6tables -A INPUT -i tun0 -j DROP
  '';
}