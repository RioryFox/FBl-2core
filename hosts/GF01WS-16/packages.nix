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
    pyquery
    flask
    myVkApi   # ← вот здесь добавляем нашу vk_api
    pipx
  ]);

in {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    mpvpaper
    amnezia-vpn
    amneziawg-go
    xray
    fastfetch
    obs-studio
    stable-diffusion-cpp-vulkan
    git
    winbox
    rclone
    pipx
    python3
    xauth
    python-packages   # ← добавляем собранное окружение в systemPackages
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
      package = pkgs.amnezia-vpn;
    };

    thunderbird = {
      enable = true;
    };
  };

  services = {
    v2raya = {
      enable = true;
      cliPackage = pkgs.xray;
    };
    fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = pkgs.libfprint-2-tod1-goodix;
      };
    };
  };
}

# [GPT-5.6 Sol] изменил в 00:09 07.09.2026 (МСК).
