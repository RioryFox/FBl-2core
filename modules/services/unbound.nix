{ config, lib, ...}:

let
  ipv6 = config.networking.enableIPv6;
  isCr01 = config.networking.hostName == "Cr01MS-32";
in
{
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "127.0.0.1" ]
          ++ lib.optionals isCr01 [ "${config.fbl.network.hosts.cr01}" ]
          ++ lib.optional ipv6 "::1";
        access-control = [ "127.0.0.0/8 allow" ] 
          ++ lib.optionals isCr01 ["${config.fbl.network.lan.cidr} allow"]
          ++ lib.optional ipv6 "::1/128 allow";

        serve-expired = true;
        serve-expired-ttl = 86400;
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = false; #true;
          forward-addr = [
            #cloudflare-dns.com
            "1.1.1.1" #@853#cloudflare-dns.com" # without DoT - [homefox@Cr01MS-32:~/FBl-2core]$ dig @1.1.1.1 query yt3.ggpht.com +short  give fake ip adress 188.186.154.88
            "1.0.0.1" #@853#cloudflare-dns.com"
            #dns.google
            "8.8.4.4" #@853#dns.google"
            "8.8.8.8" #@853#dns.google"
            #dns.quad.net
            "9.9.9.9" #@853#dns.quad9.net"
            "149.112.112.112" #@853#dns.quad9.net"
            #common.det.dns.yandex.net
            #"77.88.8.1@853#common.dot.dns.yandex.net" [homefox@Cr01MS-32:~/FBl-2core]$ dig @77.88.8.1 query yt3.ggpht.com +short give fake IP adress 188.186.154.88
            #"77.88.8.2" #@853#safe.dot.dns.yandex.net"
          ];
        }
      ];
      remote-control.control-enable = true;
    };
  };

  networking.firewall.interfaces.${config.fbl.network.interfaces.cr01Lan} = {
    allowedTCPPorts = [ config.fbl.ports.tcp.dns ];
    allowedUDPPorts = [ config.fbl.ports.udp.dns ];
  };
}