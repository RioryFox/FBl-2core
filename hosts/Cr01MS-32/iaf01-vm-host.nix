{ config, ... }:

let
  hostInterface = config.fbl.network.interfaces.cr01IafHost;
  hostAddress = config.fbl.network.hostLinks.cr01Iaf.host;
  prefixLength = config.fbl.network.hostLinks.prefixLength;
in
{
  microvm.vms."iAF01T-8" = {
    autostart = true;
    config.imports = [ ../iAF01T-8/vm.nix ];
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

# [GPT-5.6 Sol] изменил в 23:03 05.09.2026 (МСК).
