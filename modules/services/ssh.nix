{ config, ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;
    ports = [ config.fbl.ports.tcp.ssh ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}