{ config, ...}:

{
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ 
          "127.0.0.1"
          "${config.fbl.network.hosts.cr01}"
        ];
        access-control = [
          "127.0.0.0/8 allow"
          "${config.fbl.network.lan.cidr} allow"
        ];
      };
      forward-zone = [
        {
          name = ".";
          forward-tls-upstream = true;
          forward-addr = [
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
          ];
        };
      ];
      remote-control.control-enable = true;
    };
  };

  networking.firewall.interfaces.${config.fbl.network.interfaces.cr01Lan} = {
    allowedTCPPorts = [ config.fbl.ports.tcp.dns ];
    allowedUDPPorts = [ config.fbl.ports.udp.dns ];
  };
}