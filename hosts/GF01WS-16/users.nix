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
        #vscodium
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
        codex
        shotcut
        traceroute
        rclone
        #pipx
        gajim
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

  services.n8n.enable = false;

  services = {
        i2pd = {
                enable = true;
                proto.http = {
                        enable = true;
                        address = "127.0.0.1";
                        port = i2pConsolePort;
                };
                proto.httpProxy.enable = true;
                yggdrasil.enable = true;
                bandwidth = 2048;
                limits.transittunnels = 2500;
                outTunnels.jabber-client = {
                        type = "client";
                        address = "127.0.0.1";
                        port = i2pJabberPort;

                        destination = "7cxm54tzp7oo6qu6i3tegcbpsdtlcyxefvjv3k5www2g7o72u4kxhin5.b32.i2p";
                        destinationPort = 5222;

                        keys = "jabber-transient";
                };
        };
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

# [GPT-5.6 Sol] изменил в 00:10 06.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:14 06.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 03:21 06.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 20:29 06.09.2026 (МСК).
