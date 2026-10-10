{
  description = "FBl-2core — FBL-Core for  GF01WS-16 and Cr01MS-32";

  # Bootstrap cache hints: these apply while evaluating/building this flake,
  # before a new NixOS generation can persist the same Cr01 host settings.
  nixConfig = {
    extra-substituters = [
      "https://comfyui.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgsUnstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    # ComfyUI packaging is pinned independently from FBL core nixpkgs so the
    # CUDA/PyTorch runtime stays on the upstream-tested dependency set.
    comfyui-nix.url = "github:utensils/comfyui-nix/5e6d5155d302a015645164d195a6ad79f00ed43a";
    authentik-nix.url = "github:nix-community/authentik-nix/fd34a5238314351ed92dd79d00f518b8a03e19cb";
    alejandra.url = "github:kamadorueda/alejandra/8f47c5e82ee8e6e8adcc1748be0056a1e349f7e8";

    ags = {
      type = "github";
      owner = "aylur";
      repo = "ags";
      rev = "237601999d65a4663bcbab934f4f6ce1f579d728";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix/5e9efb97caeffea3bf248023b6d8b68e63b839b9";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=1e4d804e7f3fa7465811030e8da2bf10d544426a";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tabby-terminal = {
      url = "path:./pkgs/tabby-terminal-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgsUnstable,
    alejandra,
    ...
  }: let
    system = "x86_64-linux";

    corePkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    mkCoreHost = module:
      nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = corePkgs;
        specialArgs = { inherit inputs; };
        modules = [ module ];
      };

    UnstablePkgs = import nixpkgsUnstable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages.${system}.waybar-weather =
      corePkgs.callPackage ./pkgs/waybar-weather.nix {};

    nixosConfigurations = {
      Cr01MS-32 = mkCoreHost {
        imports = [
          ./hosts/Cr01MS-32/configuration.nix
        ];
      };

      GF01WS-16 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs system;
          host = "GF01WS-16";
          username = "rioryfox";

          pkgsUnstable = UnstablePkgs;
        };
        modules = [ ./hosts/GF01WS-16/configuration.nix ];
      };


    };

    formatter.${system} = alejandra.defaultPackage.${system};
  };
}
