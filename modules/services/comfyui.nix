{ config, inputs, ... }:

let
  port = config.fbl.ports.tcp.comfyui;
  hotRoot = config.fbl.storage.hotRoot;
  dataDir = "${hotRoot}/comfyui";
in
{
  imports = [ inputs.comfyui-nix.nixosModules.default ];

  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    inherit port dataDir;

    # ComfyUI is an internal backend. Browser/LAN access is owned by the
    # Authentik-protected nginx frontend in modules/services/authentik.nix.
    listenAddress = "127.0.0.1";
    openFirewall = false;

    # GTX 1650 has limited VRAM; prefer ComfyUI's low-VRAM execution path.
    extraArgs = [ "--lowvram" ];

    # Keep the initial runtime surface small and deterministic. The pinned
    # upstream package currently carries the bundled-node dependencies in its
    # closure even when they are not linked, so this is a runtime-surface
    # reduction rather than a claim that the Nix closure itself is minimal.
    bundledCustomNodes = false;
    enableManager = false;

    # The writable ComfyUI base directory is on Cr01's NVMe hot tier.
    requiresMounts = [ "nix.mount" ];
  };

  systemd.tmpfiles.rules = [
    "d ${hotRoot} 0755 root root -"
  ];
}

# [GPT-5.6 Sol] изменил в 23:22 09.09.2026 (МСК).
# [GPT-5.6 Sol] изменил в 09:47 11.09.2026 (МСК).
# [GPT-5.6 Sol] изменил в 00:43 13.09.2026 (МСК).
# [GPT-5.6 Sol] изменил в 18:49 13.09.2026 (МСК).
