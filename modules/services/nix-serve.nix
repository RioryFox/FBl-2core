{ config, ... }:

let
  port = config.fbl.ports.tcp.nix-serve;
  address = config.fbl.network.hosts.cr01;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  services.nix-serve = {
    enable = true;
    bindAddress = address;
    inherit port;
    secretKeyFile = "/var/lib/nix-serve/cache-key.sec";
    openFirewall = false;
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.nix-serve.enable
    then [ port ]
    else [ ];
}
