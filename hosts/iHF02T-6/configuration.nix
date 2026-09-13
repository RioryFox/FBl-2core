{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/services/prometheus.nix
    ../../modules/services/grafana.nix
    ./hf-proxy.nix
    ./hf-gateway-test.nix
    ./mirror-backup.nix
    ./fixed-fans.nix
    ./vpn-gateway.nix
  ];

  # Privacy underlay: Xray/VLESS starts from a root-only local source, then Tor
  # is forced through Xray. Transit interception stays OFF until one explicit
  # MikroTik test client is selected below.
  fbl.vpnGateway = {
    enable = true;
    vlessSourceFile = "/var/lib/fbl-secrets/vless.uri";
    lanInterface = "enp0s10";
    lanCidr = "192.168.3.0/24";

    transit = {
      enable = false;
      vpnClients = [ ];
      torClients = [ ];
    };
  };

  # Historical Squid/MITM experiment; intentionally separate from the privacy
  # gateway and disabled unless explicitly revisited.
  fbl.ihfGatewayTest = {
    enable = false;
    ingressInterface = "enp0s10";
    clientCidr = "192.168.3.0/24";
    egressInterface = null;
    masquerade = true;
    httpsMitm = false;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "nomodeset" "radeon.uvd=0" "radeon.audio=0" ];
  boot.blacklistedKernelModules = [ "radeon" "amdgpu" ];
  boot.kernelModules = [ "applesmc" "coretemp" ];

  networking = {
    hostName = "iHF02T-6";
    networkmanager.enable = true;
    firewall.interfaces.enp0s10.allowedTCPPorts = [ 22 3002 3128 9100 9301 ];
  };

  # MikroTik is the confirmed FBL default gateway. The route was previously
  # added manually during diagnostics; keep it across reboot without pinning
  # the still-DHCP iHF address itself.
  systemd.services.fbl-default-route = {
    description = "Ensure the iHF02 FBL default route";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.iproute2}/bin/ip route replace default via 192.168.3.1 dev enp0s10";
    };
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.imac = {
    isNormalUser = true;
    description = "iMac / iHF02 operator";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      fastfetch
      gdown
      gpufetch
      htop
      ipfetch
      lm_sensors
      mc
      python3
      smartmontools
      tree
      yazi
    ];
  };

  hardware.enableRedistributableFirmware = true;

  environment.systemPackages = with pkgs; [
    ffuf
    gobuster
    kitty
    lynis
    nikto
    nmap
    nuclei
    smartmontools
    tcpdump
    testssl
    whatweb
  ];

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = true;
  };

  services.smartd = {
    enable = true;
    autodetect = true;
  };

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
    MaxRetentionSec=30day
  '';

  system.stateVersion = "26.05";
}
