{ lib, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getNAme phg) [
    "cloudflare-warp"
  ];

  services.cloudflare-warp = {
    enable = true;
    openFirewall = false;
  };
}