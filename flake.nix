{
  description = "FBl-2core — FBL-Core plus GF01WS-16, iHF02T-6, iVN01T-2 and iAF01T-8 MicroVMs on Cr01MS-32";

  # Bootstrap cache hints: these apply while evaluating/building this flake,
  # before a new NixOS generation can persist the same Cr01 host settings.
  nixConfig = {
    extra-substituters = [
      "https://comfyui.cachix.org"
      "https://nix-community.cachix.org"
      #"https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      #"cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # ComfyUI packaging is pinned independently from FBL core nixpkgs so the
    # CUDA/PyTorch runtime stays on the upstream-tested dependency set.
    comfyui-nix.url = "github:utensils/comfyui-nix/5e6d5155d302a015645164d195a6ad79f00ed43a";

    # Authentik is pinned independently. Do not make its nixpkgs follow FBL
    # core nixpkgs: authentik-nix carries a tested dependency set for the
    # packaged Authentik release.
    authentik-nix.url = "github:nix-community/authentik-nix/fd34a5238314351ed92dd79d00f518b8a03e19cb";

    nixpkgsGF.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/cbd8a72e5fe6af19d40e2741dc440d9227836860";
      inputs.nixpkgs.follows = "nixpkgsGF";
    };

    #nixvim.url = "github:nix-community/nixvim/51abc532525e486176f9a7b24b17908c60017b54";
    alejandra.url = "github:kamadorueda/alejandra/8f47c5e82ee8e6e8adcc1748be0056a1e349f7e8";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      type = "github";
      owner = "aylur";
      repo = "ags";
      rev = "237601999d65a4663bcbab934f4f6ce1f579d728";
    };

    catppuccin = {
      url = "github:catppuccin/nix/5e9efb97caeffea3bf248023b6d8b68e63b839b9";
      inputs.nixpkgs.follows = "nixpkgsGF";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=1e4d804e7f3fa7465811030e8da2bf10d544426a";
      inputs.nixpkgs.follows = "nixpkgsGF";
    };

    tabby-terminal = {
      url = "path:./pkgs/tabby-terminal-flake";
      inputs.nixpkgs.follows = "nixpkgsGF";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgsGF,
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

    gfPkgs = import nixpkgsGF {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages.${system}.waybar-weather =
      gfPkgs.callPackage ./pkgs/waybar-weather.nix {};

    nixosConfigurations = {
      Cr01MS-32 = mkCoreHost {
        imports = [
          ./hosts/Cr01MS-32/configuration.nix
          ./modules/services/gitea.nix
        ];
      };

      # Standalone build target for validation/debugging of the guest.
      # Production autostart is owned by Cr01MS-32 via microvm.vms.iHF02T-6.
      iHF02T-6-VM = nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = corePkgs;
        specialArgs = { inherit inputs; };
        modules = [
          inputs.microvm.nixosModules.microvm
          ./hosts/iHF02T-6/vm.nix
        ];
      };

      # Standalone build target for the VPN MicroVM.
      # Production autostart is owned by Cr01MS-32 via microvm.vms.iVN01T-2.
      iVN01T-2-VM = nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = corePkgs;
        specialArgs = { inherit inputs; };
        modules = [
          inputs.microvm.nixosModules.microvm
          ./hosts/iVN01T-2/vm.nix
        ];
      };

      # Standalone build target for the Azure Fox workstation MicroVM.
      # Production autostart is owned by Cr01MS-32 via microvm.vms.iAF01T-8.
      iAF01T-8-VM = nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = corePkgs;
        specialArgs = { inherit inputs; };
        modules = [
          inputs.microvm.nixosModules.microvm
          ./hosts/iAF01T-8/vm.nix
        ];
      };

      GF01WS-16 = nixpkgsGF.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs system;
          host = "GF01WS-16";
          username = "rioryfox";
        };
        modules = [ ./hosts/GF01WS-16/configuration.nix ];
      };


    };

    formatter.${system} = alejandra.defaultPackage.${system};
  };
}
