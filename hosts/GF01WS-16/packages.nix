# 💫 https://github.com/JaKooLit 💫 #
# Packages for this host only

# packages-fonts.nix

# packages-fonts.nix
{ lib, pkgs, ... }:

let
  # Определяем vk_api как Python-пакет
  myVkApi = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "vk_api";
    version = "11.10.0";
    format = "setuptools";
    src = pkgs.python3.pkgs.fetchPypi {
      pname = "vk_api";
      inherit version;
      hash = "sha256-pj+9fXqdOTSGONPq3kn5ZOjr66CJigcLA6fwgtv10RI=";
    };
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      requests
    ];
    meta = with lib; {
      description = "Python module for VK API";
      homepage = "https://vk-api.readthedocs.io/";
    };
  };

  # Собираем все Python-пакеты в одно окружение
  python-packages = pkgs.python3.withPackages (ps: with ps; [
    requests
    pandas
    pyquery
    flask
    myVkApi
    #pipx
  ]);

in {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    mpvpaper
    amnezia-vpn
    xray
    fastfetch
    obs-studio
    git
    winbox
    rclone
    #pipx
    python3
    xauth
    python-packages
    convertx
  ];

  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = false;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    amnezia-vpn = {
      enable = true;
    };

    thunderbird = {
      enable = true;
    };
  };

  systemd.services = {
    AmneziaVPN.path = with pkgs; [
      amneziawg-go
      amneziawg-tools
    ];
  };

  services = {
    v2raya = {
      enable = true;
      cliPackage = pkgs.xray;
    };
    fprintd = {
      enable = false;
      tod = {
        enable = false;
        driver = pkgs.libfprint-2-tod1-goodix;
      };
    };
  };
}
