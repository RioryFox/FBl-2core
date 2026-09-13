{ pkgs, ... }:

{
  imports = [
    ./registry/ports.nix
    ./registry/network.nix
    ./registry/monitoring.nix
    ./registry/storage.nix
    ./registry/cache.nix
    ./services/ssh.nix
  ];

  time.timeZone = "Europe/Moscow";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    cmatrix
    curl
    git
    hyfetch
    jq
    fastfetch
    nano
    nmap
    rclone
    restic
    rsync
    tree
    wget
  ];

  # Show a compact host summary only for interactive SSH shells. NixOS
  # evaluates environment.interactiveShellInit for interactive shells, while
  # SSH_CONNECTION keeps local terminals quiet and avoids scp/sftp/rsync and
  # non-interactive remote commands.
  environment.interactiveShellInit = ''
    if [ -n "''${SSH_CONNECTION:-}" ] && command -v fastfetch >/dev/null 2>&1; then
      fastfetch
    fi
  '';

  networking.firewall.enable = true;
}
