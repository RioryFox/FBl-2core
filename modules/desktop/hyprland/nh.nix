{pkgs, ...}: {
  programs.nh = {
    enable = true;
    clean = {
      enable = false;
      extraArgs = "--keep-since 7d --keep 5";
    };
    flake = "/home/rioryfox/FBl-2core";
  };

  environment.systemPackages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
