{
  config,
  pkgs,
  options,
  ...
}: let
  inherit (import ./variables.nix) keyboardLayout;
  sshPort = config.fbl.ports.tcp.ssh;
in {
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./packages.nix
    ./pkgs/dude.nix
    ./pkgs/wireguard.nix

    ../../modules/registry/ports.nix
    ../../modules/registry/network.nix
    ../../modules/registry/cache.nix
    ../../modules/services/ssh.nix
    ../../modules/services/gf-monitoring-exporters.nix
    ../../modules/cyber
    ../../modules/desktop/hyprland

    ../../modules/hardware/amd-drivers.nix
    ../../modules/hardware/nvidia-drivers.nix
    ../../modules/hardware/nvidia-prime-drivers.nix
    ../../modules/hardware/intel-drivers.nix
    ../../modules/hardware/vm-guest-services.nix
    ../../modules/hardware/local-hardware-clock.nix


    ../../programs/vscodium.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device"
      "nowatchdog"
      "modprobe.blacklist=sp5100_tco"
      "modprobe.blacklist=iTCO_wdt"
    ];

    kernelModules = ["v4l2loopback"];

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = ["amdgpu"];
    };

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 5;
    };

    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
    };

    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };

    plymouth.enable = true;
  };

  drivers = {
    amdgpu.enable = true;
    intel.enable = true;
    nvidia.enable = false;
    nvidia-prime = {
      enable = false;
      intelBusID = "";
      nvidiaBusID = "";
    };
  };

  vm.guest-services.enable = false;
  local.hardware-clock.enable = false;

  networking = {
    hostName = "GF01WS-16";
    networkmanager.enable = true;
    timeServers = options.networking.timeServers.default ++ ["pool.ntp.org"];
    firewall = {
      enable = true;
      # Only owned/listening services should open inbound ports. Historical
      # 443/11434/5000/8081/42001 openings had no active GF01 service owner.
      allowedTCPPorts =
        if config.services.openssh.enable
        then [ sshPort ]
        else [ ];
    };
  };

  services.automatic-timezoned.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  services = {
    xserver = {
      enable = false;
      xkb = {
        layout = keyboardLayout;
        variant = "";
      };
    };

    smartd = {
      enable = true;
      #autodetect = true;
    };

    gvfs.enable = true;
    tumbler.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    udev.enable = true;
    envfs.enable = true;
    dbus.enable = true;

    fstrim = {
      enable = true;
      interval = "weekly";
    };

    libinput.enable = true;
    rpcbind.enable = true;
    nfs.server.enable = true;
    flatpak.enable = true;
    blueman.enable = true;
    fwupd.enable = true;
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    pulseaudio.enable = false;
  };

  systemd.services.flatpak-repo = {
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 30;
    swapDevices = 1;
    algorithm = "zstd";
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  hardware = {
    logitech.wireless.enable = false;
    logitech.wireless.enableGraphical = false;
    graphics.enable = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };

  security = {
    rtkit.enable = true;
    polkit = {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (
            subject.isInGroup("users")
              && (
                action.id == "org.freedesktop.login1.reboot" ||
                action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
                action.id == "org.freedesktop.login1.power-off" ||
                action.id == "org.freedesktop.login1.power-off-multiple-sessions"
              )
          ) {
            return polkit.Result.YES;
          }
        })
      '';
    };
    pam.services.swaylock.text = ''
      auth include login
    '';
  };

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      fallback = true;
      connect-timeout = 5;
      stalled-download-timeout = 10;
      download-attempts = 2;
      narinfo-cache-negative-ttl = 3600;

      # The FBL primary/fallback cache chain is owned by modules/registry/cache.nix.
      # Keep Hyprland Cachix additive for GF01-specific packages.
      extra-substituters = ["https://hyprland.cachix.org"];
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  cyber = {
    enable = true;
    role = "student";
  };

  virtualisation = {
    libvirtd.enable = false;
    podman = {
      enable = false;
      dockerCompat = false;
      defaultNetwork.settings.dns_enabled = false;
    };
  };

  environment = {
    systemPackages = [pkgs.gparted];
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QML_IMPORT_PATH = "${pkgs.hyprland-qt-support}/lib/qt-6/qml";
    };
  };

  console.keyMap = "us";
  system.stateVersion = "26.05";
}
