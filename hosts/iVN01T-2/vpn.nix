{ config, pkgs, ... }:

let
  listenPort = config.fbl.ports.udp.wireguard;
  lanInterface = config.fbl.network.interfaces.ivnLan;
  serverAddress = config.fbl.network.wireguard.serverAddress;
  serverPrefix = config.fbl.network.wireguard.prefixLength;
  wireguardCidr = config.fbl.network.wireguard.cidr;
  fblCidr = config.fbl.network.lan.cidr;
  wireguardEnabled = builtins.hasAttr "wg0" config.networking.wg-quick.interfaces;
in
{
  networking.firewall = {
    interfaces.${lanInterface}.allowedUDPPorts =
      if wireguardEnabled
      then [ listenPort ]
      else [ ];
    trustedInterfaces = [ "wg0" ];
  };

  networking.nat = {
    enable = true;
    externalInterface = lanInterface;
    internalInterfaces = [ "wg0" ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  system.activationScripts.ivn01WireGuardKey = {
    text = ''
      install -d -m 0700 /var/lib/wireguard
      if [ ! -s /var/lib/wireguard/iVN01T-2.key ]; then
        ${pkgs.wireguard-tools}/bin/wg genkey > /var/lib/wireguard/iVN01T-2.key
        chmod 0600 /var/lib/wireguard/iVN01T-2.key
      fi
    '';
  };

  networking.wg-quick.interfaces.wg0 = {
    address = [ "${serverAddress}/${toString serverPrefix}" ];
    inherit listenPort;
    privateKeyFile = "/var/lib/wireguard/iVN01T-2.key";

    # Add client public keys here. For LAN-only access, client AllowedIPs
    # should contain ${wireguardCidr} and ${fblCidr}.
    peers = [ ];
  };
}
