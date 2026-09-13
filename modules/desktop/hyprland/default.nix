{
  inputs,
  system,
  username,
  host,
  ...
}: {
  imports = [
    ../../overlays.nix
    ./quickshell.nix
    ./packages.nix
    ./fonts.nix
    ./portals.nix
    ./theme.nix
    ./ly.nix
    ./nh.nix
    inputs.catppuccin.nixosModules.catppuccin
    inputs.home-manager.nixosModules.home-manager
  ];

  # Preserved from GF01's original flake for temporarily broken unstable packages.
  nixpkgs.config.allowBroken = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = {inherit inputs system username host;};

    users.${username} = {
      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "24.05";
      };

      imports = [../../../hosts/GF01WS-16/home];
    };
  };
}
