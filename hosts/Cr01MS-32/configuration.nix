{ config, inputs, pkgs, ... }:

let
  lanInterface = config.fbl.network.interfaces.cr01Lan;
  lanAddress = config.fbl.network.hosts.cr01;
  lanPrefix = config.fbl.network.lan.prefixLength;
  lanGateway = config.fbl.network.lan.gateway;
  publicDns = config.fbl.network.upstream.publicDns;
  sshPort = config.fbl.ports.tcp.ssh;
in
{
  imports = [
    ./hardware-configuration.nix
    ./mirror-backup.nix
    ../../modules/common.nix
    ../../modules/system/cr01-build-survivability.nix
    ../../modules/services/nix-serve.nix
    ../../modules/services/ollama.nix
    ../../modules/services/open-webui.nix
    ../../modules/services/comfyui.nix
    ../../modules/services/authentik.nix
    ../../modules/services/cr-monitoring-exporters.nix
    ../../modules/services/prometheus.nix
    ../../modules/services/network-diagnostics.nix
    ../../modules/services/grafana.nix
    ../../modules/services/nextcloud.nix
    ../../modules/services/jellyfin.nix
    ../../modules/services/qbittorrent.nix
    ../../modules/services/metube.nix
    ../../modules/services/searxng.nix
    ../../modules/desktop/fluxbox.nix
    ../../modules/cyber
    ../../modules/projects/vision.nix
    ../../modules/programs/steam.nix
    inputs.microvm.nixosModules.host
    ./ihf02-vm-host.nix
    ./ivn01-vm-host.nix
    ./iaf01-vm-host.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Cr01 hot tier: ADATA LEGEND 710 NVMe. /nix is intentionally kept on
  # rebuildable fast storage and is not part of CR01_MIRROR.
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/0651b5d7-075a-45e7-8a8b-83f38715feea";
    fsType = "ext4";
  };

  # Cr01 is the primary FBL binary-cache host. Keep store paths until an
  # explicit/manual garbage collection so builds from other hosts can remain
  # available through nix-serve. Boot-menu history is still capped separately.
  nix.gc.automatic = false;
  boot.loader.systemd-boot.configurationLimit = 5;

  # Cr01 only: trust the caches published by the pinned comfyui-nix stack.
  # Keeping these host-scoped avoids widening the trust surface on FBL nodes
  # that do not consume ComfyUI/CUDA artifacts.
  fbl.cache.extraSubstituters = [
    "https://comfyui.cachix.org?priority=15"
    "https://nix-community.cachix.org?priority=16"
    #"https://cuda-maintainers.cachix.org?priority=17"
  ];

  fbl.cache.extraTrustedPublicKeys = [
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    #"cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];

  networking.hostName = "Cr01MS-32";
  networking.networkmanager.enable = false;

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="b812", GROUP="kvm"
  '';

  networking.useDHCP = false;
  networking.interfaces.${lanInterface} = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = lanAddress;
        prefixLength = lanPrefix;
      }
    ];
  };
  networking.interfaces."vm-ihf02".useDHCP = false;
  networking.interfaces."vm-ivn01".useDHCP = false;
  networking.interfaces."vm-iaf01".useDHCP = false;
  networking.defaultGateway = {
    address = lanGateway;
    interface = lanInterface;
  };
  networking.nameservers = [ lanGateway publicDns ];
  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.openssh.enable
    then [ sshPort ]
    else [ ];

  cyber = {
    enable = true;
    role = "student";
  };

  # Cr01 only: keep local account credentials declarative so the configured
  # password hash is authoritative after each rebuild. Other FBL hosts retain
  # their current mutableUsers policy.
  users.mutableUsers = false;

  users.users.homefox = {
    isNormalUser = true;
    description = "homefox";
    # Local/TTY/sudo password. SSH password authentication stays disabled by
    # modules/services/ssh.nix; only the crypt(3) hash is stored declaratively.
    hashedPassword = "$6$5Bm9ZYDSIhvH4gI9$5uKVHeI12NHmydVjEtEGqsiQtbe08OPX.0Pii3NKblqZMgTFzD6KeIUAY5X82SZfxj4oEyLAWyJLtnCCT.cIG0";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      fastfetch
      gpufetch
      ipfetch
      mc
      tree
      yazi
    ];
  };

  users.users.ollama = {
    isNormalUser = true;
    extraGroups = [ "video" "render" ];
  };

  environment.systemPackages = with pkgs; [
    smartmontools
    vulkan-tools
  ];

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 30;
    swapDevices = 1;
    algorithm = "zstd";
  };

  system.stateVersion = "26.11";
}
