{
  pkgs,
  inputs,
  host,
  ...
}: {
  services.power-profiles-daemon.enable = true;

  programs = {
    hyprland = {
      enable = true;
      withUWSM = false;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
    };
    zsh.enable = true;
    firefox.enable = false;
    waybar.enable = false;
    hyprlock.enable = true;
    dconf.enable = true;
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    git.enable = true;
    tmux.enable = true;
    nm-applet.indicator = true;
    neovim = {
      enable = true;
      defaultEditor = false;
    };

    thunar.enable = true;
    thunar.plugins = with pkgs; [
      xfce4-exo
      mousepad
      thunar-archive-plugin
      thunar-volman
      tumbler
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    alejandra
    onefetch
    atop
    go

    (writeShellScriptBin "update" ''
      cd /home/rioryfox/FBl-2core
      nh os switch -u -H ${host} .
    '')

    (writeShellScriptBin "rebuild" ''
      cd /home/rioryfox/FBl-2core
      nh os switch -H ${host} .
    '')

    (writeShellScriptBin "ncg" ''
      nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot
    '')

    # Hyprland stack
    hypridle
    hyprpolkitagent
    pyprland
    hyprlang
    hyprshot
    hyprcursor
    mesa
    nwg-displays
    nwg-look
    waypaper
    waybar
    waybar-weather
    hyprland-qt-support

    # Applications and desktop utilities
    power-profiles-daemon
    loupe
    appimage-run
    bc
    brightnessctl
    (btop.override {
      cudaSupport = true;
      rocmSupport = true;
    })
    bottom
    baobab
    btrfs-progs
    cmatrix
    distrobox
    dua
    duf
    cava
    cargo
    clang
    cmake
    cliphist
    cpufrequtils
    curl
    dysk
    eog
    eza
    findutils
    figlet
    ffmpeg
    fd
    feh
    file-roller
    glib
    gsettings-qt
    git
    google-chrome
    gnome-system-monitor
    jq
    gcc
    gnumake
    grim
    grimblast
    gtk-engine-murrine
    inxi
    imagemagick
    killall
    kdePackages.qt6ct
    kdePackages.qtwayland
    kdePackages.qtstyleplugin-kvantum
    lazydocker
    lazygit
    libappindicator
    libnotify
    libsForQt5.qtstyleplugin-kvantum
    libsForQt5.qt5ct
    (mpv.override {scripts = [mpvScripts.mpris];})
    nvtopPackages.full
    openssl
    pciutils
    networkmanagerapplet
    pamixer
    pavucontrol
    playerctl
    kdePackages.polkit-kde-agent-1
    rofi
    slurp
    swappy
    serie
    swaynotificationcenter
    awww
    unzip
    wallust
    wdisplays
    wl-clipboard
    wlr-randr
    wlogout
    wget
    xarchiver
    yad
    yazi
    xdg-user-dirs
    yt-dlp

    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.tabby-terminal.packages.${pkgs.stdenv.hostPlatform.system}.default

    # CLI utilities
    ctop
    erdtree
    frogmouth
    lstr
    lolcat
    lsd
    macchina
    mcat
    mdcat
    parallel-disk-usage
    pik
    oh-my-posh
    ncdu
    ncftp
    netop
    ripgrep
    socat
    starship
    trippy
    tldr
    tuptime
    ugrep
    unrar
    v4l-utils
    obs-studio
    zoxide

    # Hardware and monitoring
    bandwhich
    caligula
    cpufetch
    cpuid
    cpu-x
    cyme
    gdu
    glances
    gping
    htop
    hyfetch
    ipfetch
    pfetch
    smartmontools
    #light
    lm_sensors
    mission-center
    #neofetch
    fastfetch
    hyfetch

    # Development and virtualization
    luarocks
    nh
    virt-viewer
    libvirt

    # Video and terminals
    vlc
    kitty
    wezterm
  ];

  environment.variables = {
    JAKOS_NIXOS_VERSION = "0.0.5";
    JAKOS = "true";
  };
}
