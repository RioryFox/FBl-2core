{ config, pkgs, ... }:

let
  port = config.fbl.ports.tcp.ollama;
in
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    inherit port;
    host = "127.0.0.1";
    loadModels = [ ];
    environmentVariables = {
      OLLAMA_CUDA = "1";
      acceleration = "cuda";
    };
  };

  # Ollama is consumed locally by Open WebUI; no LAN firewall exposure needed.
}
