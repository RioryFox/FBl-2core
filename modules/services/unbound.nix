{ config, ...}:

{
  services.unbound = {
    enable = true;
  };
  settings = {
    server = {
      interface = [ 
        "127.0.0.1"
        "192.168.3.253"
      ];
      access-control = [
        "127.0.0.1/8 allow"
        "192.168.3.253/24 allow"
      ];
    };
    forward-zone = [
      {
        name = ".";
        forward-addr = "1.1.1.1@853#cloudflare-dns.com";
      }
      {
        name = "example.org.";
        forward-addr = [
          "1.1.1.1@853#cloudflare-dns.com"
          "1.0.0.1@853#cloudflare-dns.com"
        ];
      }
    ];
    remote-control.control-enable = true;
  };

  }
}