{ lib, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
  builtins.elem (lib.getName phg) [
    "cloudflare-warp"
  ];

  services.cloudflare-warp = {
    enable = true;
    openFirewall = false;
  };
}