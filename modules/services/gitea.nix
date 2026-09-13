{ config, ... }:

let
  address = config.fbl.network.hosts.cr01;
  port = config.fbl.ports.tcp.gitea;
  sshPort = config.fbl.ports.tcp.ssh;
  lanInterface = config.fbl.network.interfaces.cr01Lan;
in
{
  services.gitea = {
    enable = true;
    appName = "FBL Gitea";

    # Keep the first-stage forge self-contained on Cr01. The NixOS Gitea
    # module stores SQLite and repositories below /var/lib/gitea.
    database.type = "sqlite3";

    settings = {
      server = {
        HTTP_ADDR = address;
        HTTP_PORT = port;
        DOMAIN = address;
        ROOT_URL = "http://${address}:${toString port}/";

        # Reuse FBL system OpenSSH for clone/push. Gitea must not own a second
        # SSH listener or introduce another SSH port outside the registry.
        DISABLE_SSH = false;
        START_SSH_SERVER = false;
        SSH_PORT = sshPort;
      };

      # Users are provisioned deliberately by an administrator. The first
      # admin is created locally with the Gitea CLI after runtime validation.
      service.DISABLE_REGISTRATION = true;
    };
  };

  # Make the administration CLI available to the operator on Cr01.
  environment.systemPackages = [ config.services.gitea.package ];

  # FBL invariant: service registration and network exposure are separate.
  # A disabled service must not leave its inbound listener reachable.
  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts =
    if config.services.gitea.enable
    then [ port ]
    else [ ];
}

# [GPT-5.6 Sol] изменил в 17:40 13.09.2026 (МСК).
