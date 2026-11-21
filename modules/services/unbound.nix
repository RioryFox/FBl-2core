{ config, lib, ...}:

let
  ipv6 = config.networking.enableIPv6;
in
{
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [
          "127.0.0.1"
          "${config.fbl.network.hosts.cr01}"
        ] ++ lib.optional ipv6 "::1";
        access-control = [
          "127.0.0.0/8 allow"
          "${config.fbl.network.lan.cidr} allow"
        ] ++ lib.optional ipv6 "::1/128 allow";

        serve-expired = true;
        serve-expired-ttl = 86400;
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = [
            #cloudflare-dns.com
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
            #dns.google
            "8.8.4.4@853#dns.google"
            "8.8.8.8@853#dns.google"
            #dns.quad.net
            "9.9.9.9@853#dns.quad.net"
            "149.112.112.122@853#dns.quad9.net"
            #common.det.dns.yandex.net
            "77.88.8.8@853#common.det.dns.yandex.net"
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