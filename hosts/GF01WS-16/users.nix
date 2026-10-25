{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  inherit (import ./variables.nix) gitUsername;
  i2pConsolePort = config.fbl.ports.tcp.i2pConsole;
  i2pJabberPort = config.fbl.ports.tcp.i2pJabber;

  myVkApi = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "vk_api";
    version = "11.10.0";
    format = "setuptools";
    src = pkgs.python3.pkgs.fetchPypi {
      pname = "vk_api";
      inherit version;
      hash = "sha256-pj+9fXqdOTSGONPq3kn5ZOjr66CJigcLA6fwgtv10RI=";
    };
    propagatedBuildInputs = with pkgs.python3.pkgs; [requests];
    meta = with lib; {
      description = "Python module for VK API";
      homepage = "https://vk-api.readthedocs.io/";
    };
  };
in {
  users = {
    # Keep the GF01 login password declarative. SSH password authentication
    # remains disabled by modules/services/ssh.nix; this hash is for local TTY/sudo.
    mutableUsers = false;
    users.${username} = {
      homeMode = "755";
      isNormalUser = true;
      description = gitUsername;
      hashedPassword = "$6$p5UEBYWKO7LzGnJM$kKJ2RAGB6HKmMVPoQVhx.lpk3ouzwAAKUAZCf0Luy.0IVRBfaZW7ACbN6bbBb4cYZVTAVZTaSiWqEF1FMjYDI/";
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "scanner"
        "lp"
        "video"
        "input"
        "audio"
        "dialout"
      ];

      packages = with pkgs; [
        firefox
        chromium
        librewolf
        dbeaver-bin
        esptool
        platformio
        figma-linux
        telegram-desktop
        wireshark
        gparted
        steam
        goofcord
        open-webui
        libreoffice
        ani-cli
        #codex
        shotcut
        traceroute
        rclone
        #pipx
        minicom
        (python3.withPackages (python-pkgs:
          with python-pkgs; [
            requests
            levenshtein
            httpx
            beautifulsoup4
            pip
            myVkApi
            #pipx
            pytz
            aiogram
          ]))
      ];
    };

    defaultUserShell = pkgs.zsh;
  };

  security.pki.certificateFiles = [
          ./cert.crt
  ];

  environment = {
    shells = with pkgs; [zsh];

    # The original GF cyber/common module supplied these. The shared FBL cyber
    # module supplies the role tools; this is the GF-only compatibility delta.
    systemPackages = with pkgs; [
      wine
      (wine.override {wineBuild = "wine64";})
      wine64
      wineWowPackages.staging
      winetricks
      wineWowPackages.waylandFull
    ];
  };

  programs.zsh = {
    ohMyZsh = {
      enable = true;
      theme = "agnoster";
      plugins = ["git"];
    };
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };
}