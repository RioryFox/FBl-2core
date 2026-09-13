{ config, pkgs, ... }:

let
  sshPort = config.fbl.ports.tcp.ssh;
  lanAddress = config.fbl.network.hosts.ivn01;
  lanPrefix = config.fbl.network.lan.prefixLength;
  lanGateway = config.fbl.network.lan.gateway;
  lanInterface = config.fbl.network.interfaces.ivnLan;
  hostInterface = config.fbl.network.interfaces.ivnHost;
  hostLinkAddress = config.fbl.network.hostLinks.cr01Ivn.guest;
  hostLinkPrefix = config.fbl.network.hostLinks.prefixLength;
  upstreamDns = config.fbl.network.upstream.dns;
  publicDns = config.fbl.network.upstream.publicDns;
in
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/ivn-monitoring-exporters.nix
    ./vpn.nix
  ];

  microvm = {
    hypervisor = "qemu";
    mem = 4096;
    vcpu = 2;
    socket = "control.socket";

    # 10 GiB persistent state disk. The Nix store is shared read-only from Cr01.
    volumes = [
      {
        image = "var.img";
        mountPoint = "/var";
        size = 10240;
      }
    ];

    shares = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # LAN macvtap plus a private Cr01<->iVN link for monitoring/management.
    # The TAP avoids macvtap host<->guest reachability limitations.
    interfaces = [
      {
        type = "macvtap";
        id = "vm-ivn01";
        mac = "02:46:42:01:00:02";
        macvtap = {
          link = "enp3s0";
          mode = "bridge";
        };
      }
      {
        type = "tap";
        id = "vm-ivn01-host";
        mac = "02:46:42:01:10:02";
      }
    ];
  };

  networking = {
    hostName = "iVN01T-2";
    networkmanager.enable = false;
    useDHCP = false;
    usePredictableInterfaceNames = false;

    # Outside the documented MikroTik DHCP pool (192.168.3.10-254).
    interfaces.${lanInterface}.ipv4.addresses = [
      {
        address = lanAddress;
        prefixLength = lanPrefix;
      }
    ];

    interfaces.${hostInterface}.ipv4.addresses = [
      {
        address = hostLinkAddress;
        prefixLength = hostLinkPrefix;
      }
    ];

    defaultGateway = {
      address = lanGateway;
      interface = lanInterface;
    };

    nameservers = [ upstreamDns publicDns ];
    firewall.interfaces.${lanInterface}.allowedTCPPorts =
      if config.services.openssh.enable
      then [ sshPort ]
      else [ ];
  };

  users.mutableUsers = true;
  users.users.ivn = {
    isNormalUser = true;
    description = "iVN01 operator";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      htop
      tcpdump
      wireguard-tools
    ];
  };

  # Local console bootstrap remains available; SSH authentication is key-only
  # via modules/common.nix.
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    iproute2
    iptables
    tcpdump
    wireguard-tools
  ];

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=512M
    MaxRetentionSec=14day
  '';

  system.stateVersion = "26.05";
}
