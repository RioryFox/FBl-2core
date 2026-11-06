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
      hashedPassword = "$6$FBLgf02temp2026$cQAMFngZR8wYFntqqaM5OlHWufU5/Hgno.qXw0udbBjj//crIh0A.PsgvW/aRyN5lLLyKSxJiJ5FXljFKyctA1";
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
        esptool
        platformio
        telegram-desktop
        steam
        goofcord
        libreoffice
        ani-cli
        shotcut
        traceroute
        minicom
        (python3.withPackages (python-pkgs:
          with python-pkgs; [
            requests
            levenshtein
            httpx
            beautifulsoup4
            pip
            myVkApi
            pytz
            aiogram
          ]))
      ];
    };

    defaultUserShell = pkgs.zsh;
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