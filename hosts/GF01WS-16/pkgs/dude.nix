{ pkgs, lib, ... }:

let
  mikrotik-dude-client = pkgs.stdenv.mkDerivation rec {
    pname = "mikrotik-dude-client";
    version = "7.23.1";

    src = pkgs.fetchurl {
      url = "https://download.mikrotik.com/routeros/${version}/dude-install-${version}.exe";
      hash = "sha256-Y1fb7aLYMC/a/wNbz6Ua5a3AIArWjN+e/I2DFaR931o=";
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/mikrotik-dude
      cp $src $out/share/mikrotik-dude/dude-install.exe

      mkdir -p $out/bin
      makeWrapper ${pkgs.wineWowPackages.stable}/bin/wine $out/bin/mikrotik-dude-client \
        --add-flags "$out/share/mikrotik-dude/dude-install.exe"

      runHook postInstall
    '';

    meta = {
      description = "MikroTik The Dude Client wrapped with Wine";
      homepage = "https://mikrotik.com/download/tools";
      license = lib.licenses.unfreeRedistributable;
      platforms = [ "x86_64-linux" ];
      mainProgram = "mikrotik-dude-client";
    };
  };
in
{
  environment.systemPackages = [
    mikrotik-dude-client
  ];
}