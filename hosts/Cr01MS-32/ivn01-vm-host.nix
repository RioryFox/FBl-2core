{ config, ... }:

let
  hostInterface = config.fbl.network.interfaces.cr01IvnHost;
  hostAddress = config.fbl.network.hostLinks.cr01Ivn.host;
  prefixLength = config.fbl.network.hostLinks.prefixLength;
in
{
  microvm.vms."iVN01T-2" = {
    autostart = true;
    config.imports = [ ../iVN01T-2/vm.nix ];
  };

  networking.interfaces.${hostInterface} = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = hostAddress;
        inherit prefixLength;
      }
    ];
  };
}
