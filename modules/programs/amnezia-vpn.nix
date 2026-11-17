{ pkgsUnstable, ... }:

{
  programs.amnezia-vpn = {
    enable = true;
    package = pkgsUnstable.amnezia-vpn;
  };
}
