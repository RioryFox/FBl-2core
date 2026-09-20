{ config, pkgs, ... }:

let
  sshPort = config.fbl.ports.tcp.ssh;
  lanAddress = config.fbl.network.hosts.ihf02;
  lanPrefix = config.fbl.network.lan.prefixLength;
  lanGateway = config.fbl.network.lan.gateway;
  lanCidr = config.fbl.network.lan.cidr;
  upstreamDns = config.fbl.network.upstream.dns;
  lanInterface = config.fbl.network.interfaces.ihfLan;
  hostInterface = config.fbl.network.interfaces.ihfHost;
  hostLinkAddress = config.fbl.network.hostLinks.cr01Ihf.guest;
  hostLinkPrefix = config.fbl.network.hostLinks.prefixLength;
in
{
  imports = [
    ../../modules/common.nix
    ../../modules/services/ihf-monitoring-agent.nix
    ./hf-proxy.nix
    ./hf-gateway-test.nix
    ./vpn-gateway.nix
  ];

  # iHF02T-6 runs as a persistent MicroVM on Cr01MS-32.
  microvm = {
    hypervisor = "qemu";
    mem = 8192;
    vcpu = 4;
    socket = "control.socket";

    # Keep service state, secrets, logs and mutable user state across VM
    # rebuilds/restarts. Historical Grafana/Prometheus data may still be
    # present here until a separate runtime migration/cleanup is performed.
    volumes = [
      {
        image = "var.img";
        mountPoint = "/var";
        size = 10240;
      }
    ];

    # Reuse the host Nix store instead of duplicating it into the VM disk.
    shares = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Direct L2 presence on the FBL LAN plus a private Cr01<->iHF link.
    interfaces = [
      {
        type = "macvtap";
        id = "vm-ihf02";
        mac = "02:46:42:02:00:06";
        macvtap = {
          link = "enp3s0";
          mode = "bridge";
        };
      }
      {
        type = "tap";
        id = "vm-ihf02-host";
        mac = "02:46:42:02:10:06";
      }
    ];
  };

  networking = {
    hostName = "iHF02T-6";
    networkmanager.enable = false;
    useDHCP = false;
    usePredictableInterfaceNames = false;

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

    nameservers = [ upstreamDns ];

    # Central Grafana/Prometheus moved to Cr01. iHF exposes only SSH and its
    # explicit proxy listener on the FBL LAN; monitoring agent traffic is
    # outbound over the host-only TAP.
    firewall.interfaces.${lanInterface}.allowedTCPPorts =
      if config.services.openssh.enable
      then [ sshPort ]
      else [ ];
  };

  # Privacy underlay and gateway role moved from the physical iMac.
  fbl.vpnGateway = {
    enable = true;
    vlessSourceFile = "/var/lib/fbl-secrets/vless.uri";
    lanInterface = lanInterface;
    lanCidr = lanCidr;

    transit = {
      enable = false;
      vpnClients = [ ];
      torClients = [ ];
    };
  };

  fbl.ihfGatewayTest = {
    enable = false;
    ingressInterface = lanInterface;
    clientCidr = lanCidr;
    egressInterface = null;
    masquerade = true;
    httpsMitm = false;
  };

  users.mutableUsers = true;
  users.users.imac = {
    isNormalUser = true;
    description = "iHF02 operator";
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$TDkOfxHzMkdy2sJg$qGBv9/CLlp.A5XNMpPoUNfjWsCPx/0WohvCoOAnAoOmpOxMhkf214kZmMQuIfTe5hN8ZamamSHS5f34EvCGG3.";
    packages = with pkgs; [
      fastfetch
      gdown
      gpufetch
      htop
      ipfetch
      mc
      python3
      tree
      yazi
    ];
  };

  # Local serial console autologin remains a bootstrap path; SSH is key-only
  # via modules/common.nix.
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    ffuf
    gobuster
    lynis
    nikto
    nmap
    nuclei
    tcpdump
    testssl
    whatweb
  ];

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
    MaxRetentionSec=30day
  '';

  # The old iHF02 physical-disk mirror is replaced by Cr01's host-level mirror:
  # /var/lib/microvms is part of the Cr01 root tree and is therefore copied to
  # CR01_MIRROR by the existing cr01-mirror job.

  system.stateVersion = "26.05";
}