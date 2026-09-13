{ config, lib, pkgs, ... }:

let
  roleFiles = {
    blue = "blue.nix";
    bugbounty = "bugbounty.nix";
    cracker = "cracker.nix";
    dos = "dos.nix";
    forensic = "forensic.nix";
    malware = "malware.nix";
    mobile = "mobile.nix";
    network = "network.nix";
    osint = "osint.nix";
    red = "red.nix";
    student = "student.nix";
    web = "web.nix";
  };

  rolePackages = import (./roles + "/${roleFiles.${config.cyber.role}}") {
    inherit pkgs;
  };
in
{
  options.cyber = {
    enable = lib.mkEnableOption "FBL cyber tools";
    role = lib.mkOption {
      type = lib.types.enum (builtins.attrNames roleFiles);
      default = "student";
    };
  };

  config = lib.mkIf config.cyber.enable {
    environment.systemPackages =
      (import ./common.nix { inherit pkgs; }) ++ rolePackages;
  };
}
