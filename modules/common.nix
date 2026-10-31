{ pkgs, ... }:

{
  imports = [
    ./registry/ports.nix
    ./registry/monitoring.nix
    ./registry/cache.nix
    ./services/ssh.nix
  ];

  #time.timeZone = "Europe/Moscow";
  services.automatic-timezoned.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    cmatrix
    curl
    git
    hyfetch
    fastfetch
    jq
    nano
    vim
    mc
    yazi
    nmap
    rclone
    restic
    rsync
    wget
    kpcli
    keepass

    # ─────────────────────────────────────────────
    # DEVELOPMENT
    # ─────────────────────────────────────────────
    gcc
    gh
    gnumake
    openssl
    python3
    go
    rustc
    cargo

    # ─────────────────────────────────────────────
    # ARCHIVE / TRANSFER / SYNC
    # ─────────────────────────────────────────────
    p7zip
    unzip
    rclone
    rsync

    # ───────────────────────────────────────────────
    # TERMINAL / SESSION MANAGEMENT
    # ─────────────────────────────────────────────
    screen
    tmux

    # ─────────────────────────────────────────────
    # CLI / SHELL UTILITIES
    # ─────────────────────────────────────────────
    curl
    fd
    jq
    ripgrep
    wget
    yq

    # ─────────────────────────────────────────────
    # FILESYSTEM / STORAGE
    # ─────────────────────────────────────────────
    file
    parted
    gparted
    tree

    # ─────────────────────────────────────────────
    # SYSTEM INFO / HARDWARE
    # ─────────────────────────────────────────────
    btop
    htop
    dmidecode
    gpufetch
    inxi
    ipfetch
    lm_sensors
    lsof
    pciutils
    usbutils  
  ];

  environment.interactiveShellInit = ''
    if [ -n "''${SSH_CONNECTION:-}" ] && command -v fastfetch >/dev/null 2>&1; then
      fastfetch
    fi
  '';

  networking.firewall.enable = true;

  
  # Temporary workaround for Nixpkgs #580269 it is a bag?
  # Remove after the fix reaches nixos-26.05 but i got a troubles with now pkgs
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions ++ [
          (pyFinal: pyPrev: {
            imageio = pyPrev.imageio.overridePythonAttrs (old: {
              disabledTestPaths =
                (old.disabledTestPaths or []) ++ [
                  "tests/test_pillow.py::test_png_16bit"
                  "tests/test_pillow_legacy.py::test_png"
                ];
            });
          })
        ];
    })
  ];


}
