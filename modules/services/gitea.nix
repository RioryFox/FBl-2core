{ config, ... }:

let
  address = config.fbl.network.hosts.cr01;
  port = config.fbl.ports.tcp.gitea;
  sshPort = config.fbl.ports.tcp.giteaSsh;
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

        # Keep Git transport isolated from Cr01 system OpenSSH: Gitea owns a
        # dedicated built-in SSH listener, while host administration stays on :22.
        DISABLE_SSH = false;
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_USER = "git";
        SSH_DOMAIN = address;
        SSH_PORT = sshPort;
        SSH_LISTEN_HOST = address;
        SSH_LISTEN_PORT = sshPort;
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
    then [ port sshPort ]
    else [ ];
}