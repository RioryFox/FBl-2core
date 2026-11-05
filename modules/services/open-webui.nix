{ config, ... }:

let
  port = config.fbl.ports.tcp.open-webui;
  address = config.fbl.network.hosts.cr01;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  services.open-webui = {
    enable = true;
    inherit port;
    host = address;
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.open-webui.enable
    then [ port ]
    else [ ];
}
