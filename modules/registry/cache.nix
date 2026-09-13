{ config, lib, ... }:

let
  cfg = config.fbl.cache;
  cacheUrl = "${cfg.protocol}://${cfg.address}:${toString config.fbl.ports.tcp.nix-serve}";
in
{
  options.fbl.cache = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the shared FBL binary cache hosted on Cr01MS-32.";
    };

    protocol = lib.mkOption {
      type = lib.types.enum [ "http" "https" ];
      default = "http";
      description = "Protocol used to reach the shared FBL binary cache.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = config.fbl.network.hosts.cr01;
      description = "Address or DNS name of the shared Cr01MS-32 binary cache.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "cr01ms-32-cache:6FuaTLLDmm6sIefm8A82IqB8k6UgpIzs8T5SHZyFAoc=";
      description = "Public signing key of the shared Cr01MS-32 binary cache.";
    };

    extraSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific binary caches inserted after the primary Cr01 cache.";
    };

    extraTrustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific trusted signing keys for extra binary caches.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      # Explicit priorities guarantee the intended fallback order.
      # Lower numeric priority is preferred by Nix. Host-specific caches are
      # intentionally scoped through fbl.cache.extraSubstituters instead of
      # broadening the trust surface on every FBL host.
      substituters = lib.mkForce (
        [ "${cacheUrl}?priority=10" ]
        ++ cfg.extraSubstituters
        ++ [
          "https://cache.nixos.org/?priority=20"
          "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=30"
          "https://mirrors.ustc.edu.cn/nix-channels/store?priority=40"
        ]
      );
      trusted-public-keys = lib.mkAfter ([ cfg.publicKey ] ++ cfg.extraTrustedPublicKeys);
      fallback = true;
      connect-timeout = lib.mkDefault 5;
      stalled-download-timeout = lib.mkDefault 20;
    };
  };
}
