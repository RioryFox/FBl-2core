{ ... }:

{
  # Cr01 is a server first and a build machine second. Keep headroom for the
  # management plane while large Nix/Python/CUDA derivations are compiling.
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };

  # Absorb short memory spikes before the host reaches hard OOM pressure.
  # With 32 GiB RAM this creates roughly 8 GiB of compressed swap capacity.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    priority = 100;
  };

  # Build work should yield CPU/IO to interactive and management services.
  # OOMScoreAdjust is inherited by daemon children, making build processes
  # preferable OOM victims instead of the remote-management plane.
  systemd.services.nix-daemon.serviceConfig = {
    Nice = 10;
    CPUWeight = 25;
    IOWeight = 25;
    OOMScoreAdjust = 500;
  };

  # SSH is the primary remote recovery path and should survive pressure.
  # Upstream NixOS already configures sshd with Restart=always.
  systemd.services.sshd.serviceConfig = {
    CPUWeight = 1000;
    IOWeight = 1000;
    OOMScoreAdjust = -900;
  };

  # Keep Grafana responsive where possible, but below SSH in protection level.
  systemd.services.grafana.serviceConfig = {
    CPUWeight = 500;
    IOWeight = 500;
    OOMScoreAdjust = -500;
  };
}
