{ lib, pkgs, ... }:

let
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

  python-packages = pkgs.python3.withPackages (ps: with ps; [
    requests
    pandas
    pyquery
    flask
    myVkApi
  ]);

in {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    mpvpaper
    fastfetch
    git
    winbox
    rclone
    python3
    xauth
    python-packages
    convertx
  ];
  
}
