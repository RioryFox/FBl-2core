{ config, ... }:

{
  # FBL-wide SSH policy: remote authentication is key-only. Local passwords
  # remain available for sudo/local console recovery where the host permits it.
  # SSH uses host-specific interfaces, so each host owns its firewall rule.
  # That rule must be gated by config.services.openssh.enable.
  services.openssh = {
    enable = true;
    openFirewall = false;
    ports = [ config.fbl.ports.tcp.ssh ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}

# GPT-5.6 Sol создал в 18:15 05.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:14 06.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 01:58 06.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:30 10.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 00:48 13.09.2026 (МСК).
