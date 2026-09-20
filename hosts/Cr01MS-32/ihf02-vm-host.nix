{ config, ... }:

let
  hostInterface = config.fbl.network.interfaces.cr01IhfHost;
  hostAddress = config.fbl.network.hostLinks.cr01Ihf.host;
  prefixLength = config.fbl.network.hostLinks.prefixLength;
in
{
  microvm.vms."iHF02T-6" = {
    autostart = true;
    config.imports = [ ../iHF02T-6/vm.nix ];
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