{ ... }:

{
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 30;
    priority = 100;
  };

  systemd.services.nix-daemon.serviceConfig = {
    Nice = 10;
    CPUWeight = 25;
    IOWeight = 25;
    OOMScoreAdjust = 500;
  };

  systemd.services.sshd.serviceConfig = {
    CPUWeight = 1000;
    IOWeight = 1000;
    OOMScoreAdjust = -900;
  };

  systemd.services.grafana.serviceConfig = {
    CPUWeight = 500;
    IOWeight = 500;
    OOMScoreAdjust = -500;
  };
}
