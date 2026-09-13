{ config, pkgs, ... }:

let
  sshPort = config.fbl.ports.tcp.ssh;
  lanAddress = config.fbl.network.hosts.iaf01;
  lanPrefix = config.fbl.network.lan.prefixLength;
  lanGateway = config.fbl.network.lan.gateway;
  lanInterface = config.fbl.network.interfaces.iafLan;
  hostInterface = config.fbl.network.interfaces.iafHost;
  hostLinkAddress = config.fbl.network.hostLinks.cr01Iaf.guest;
  hostLinkPrefix = config.fbl.network.hostLinks.prefixLength;
  publicDns = config.fbl.network.upstream.publicDns;
in
{
  imports = [
    ../../modules/common.nix
    ../../modules/cyber
    ../../modules/services/af-monitoring-exporters.nix
  ];

  microvm = {
    hypervisor = "qemu";
    mem = 8192;
    vcpu = 2;
    socket = "control.socket";

    # DEXP USB Wi-Fi adapter (Realtek RTL8812BU) dedicated to iAF01T-8.
    # QEMU matches it by USB vendor/product ID, so the device may be moved
    # between physical USB ports without changing the VM configuration.
    devices = [
      {
        bus = "usb";
        path = "vendorid=0x0bda,productid=0xb812";
      }
    ];

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

    interfaces = [
      {
        type = "macvtap";
        id = "vm-iaf01";
        mac = "02:46:42:01:00:03";
        macvtap = {
          link = "enp3s0";
          mode = "bridge";
        };
      }
      {
        type = "tap";
        id = "vm-iaf01-host";
        mac = "02:46:42:01:10:08";
      }
    ];
  };

  networking = {
    hostName = "iAF01T-8";
    networkmanager.enable = false;
    useDHCP = false;
    usePredictableInterfaceNames = false;

    interfaces.${lanInterface}.ipv4.addresses = [
      {
        address = lanAddress;
        prefixLength = lanPrefix;
      }
    ];

    # Dedicated host-only link to Cr01 for Azure's execution broker.
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

    nameservers = [ lanGateway publicDns ];
    firewall.interfaces.${lanInterface}.allowedTCPPorts =
      if config.services.openssh.enable
      then [ sshPort ]
      else [ ];
    firewall.interfaces.${hostInterface}.allowedTCPPorts =
      if config.services.openssh.enable
      then [ sshPort ]
      else [ ];
  };

  cyber = {
    enable = true;
    role = "student";
  };

  users.mutableUsers = false;

  users.users.azure = {
    isNormalUser = true;
    description = "Azure Fox workstation user";
    extraGroups = [ "wheel" "wireshark" ];
    hashedPassword = "$6$dnwKHLlGtBJQabf8$u0ndnd5r3s3ujFjvmLVB3HeG4s2OtDLCSjtC6MTonxbu9ClvC3Gb.aO97QLzMjI6hamKdR7GKmOScveZ1i2VJ.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK6zCJanPFj4AXuvFDTVLVkxxl8xw+5ruf0lzN4RG90H azure-router@Cr01MS-32"
    ];
    packages = with pkgs; [
      git
      htop
      jq
      mc
      tmux
      tree
      yazi
    ];
  };

  users.users.riory = {
    isNormalUser = true;
    description = "Riory administrative workstation user";
    extraGroups = [ "wheel" "wireshark" ];
    hashedPassword = "$6$6.469Hd0WCo8da8o$dlYGARSVGHQFeHPZaE6vY.qQSlgcyKCFRsLqPQuQqFFdZBG6MxUnP6NTlAnAZcb79cB3W0fUofFutrnoGSNxR1";
  };

  security.sudo.wheelNeedsPassword = true;

  services.getty.autologinUser = "root";

  system.stateVersion = "26.05";
}
