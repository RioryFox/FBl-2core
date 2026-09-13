{ config, pkgs, ... }:

let
  targets = config.fbl.monitoring.externalSites;
  targetsJson = builtins.toJSON targets;
  textfileDir = "/var/lib/prometheus-node-exporter-text-files";
  metricsFile = "${textfileDir}/fbl-network-diagnostics.prom";
  stateDir = "/var/lib/fbl-network-diagnostics";
  stateFile = "${stateDir}/last-known-ip.json";
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
    "d ${stateDir} 0750 root root -"
  ];

  systemd.services.fbl-network-diagnostics = {
    description = "Resolve FBL external sites and probe their primary IPv4 TCP endpoint";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";

    script = ''
      ${pkgs.python3}/bin/python3 <<'PY'
      import json
      import os
      import socket
      import time

      TARGETS = ${targetsJson}
      METRICS_FILE = "${metricsFile}"
      STATE_FILE = "${stateFile}"

      try:
          with open(STATE_FILE, "r", encoding="utf-8") as handle:
              last_known_ips = json.load(handle)
          if not isinstance(last_known_ips, dict):
              last_known_ips = {}
      except (OSError, ValueError):
          last_known_ips = {}

      def esc(value):
          return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

      def labelset(**labels):
          return ",".join(f'{key}="{esc(value)}"' for key, value in labels.items())

      lines = [
          "# HELP fbl_dns_resolution_success 1 when the Cr01 system resolver returned at least one IPv4 address.",
          "# TYPE fbl_dns_resolution_success gauge",
          "# HELP fbl_dns_resolution_duration_seconds Time spent resolving the hostname through the Cr01 system resolver.",
          "# TYPE fbl_dns_resolution_duration_seconds gauge",
          "# HELP fbl_dns_resolved_ip_info Primary IPv4 address selected from the Cr01 system resolver result.",
          "# TYPE fbl_dns_resolved_ip_info gauge",
          "# HELP fbl_ip_tcp_success 1 when a direct TCP connection to the primary resolved IPv4 address succeeds without another DNS lookup.",
          "# TYPE fbl_ip_tcp_success gauge",
          "# HELP fbl_ip_tcp_duration_seconds Time spent opening the direct TCP connection to the primary resolved IPv4 address.",
          "# TYPE fbl_ip_tcp_duration_seconds gauge",
          "# HELP fbl_network_probe_timestamp_seconds Unix timestamp of the latest local DNS/IP diagnostic run.",
          "# TYPE fbl_network_probe_timestamp_seconds gauge",
      ]

      for target in TARGETS:
          host = target["host"]
          url = target["url"]
          group = target["group"]
          port = int(target["port"])
          base_labels = {
              "site": host,
              "host": host,
              "url": url,
              "probe_group": group,
          }

          started = time.monotonic()
          ips = []
          try:
              answers = socket.getaddrinfo(host, port, family=socket.AF_INET, type=socket.SOCK_STREAM)
              for answer in answers:
                  ip = answer[4][0]
                  if ip not in ips:
                      ips.append(ip)
          except OSError:
              ips = []
          dns_duration = time.monotonic() - started
          dns_success = 1 if ips else 0

          lines.append(
              f'fbl_dns_resolution_success{{{labelset(**base_labels)}}} {dns_success}'
          )
          lines.append(
              f'fbl_dns_resolution_duration_seconds{{{labelset(**base_labels)}}} {dns_duration:.6f}'
          )

          primary_ip = ips[0] if ips else ""
          remembered_ip = str(last_known_ips.get(host, ""))
          if primary_ip:
              last_known_ips[host] = primary_ip
              lines.append(
                  f'fbl_dns_resolved_ip_info{{{labelset(**base_labels, resolved_ip=primary_ip)}}} 1'
              )

          # Preserve the last successful IPv4 so the IP path can still be
          # tested during a DNS outage. This is the key separation between
          # resolver failure and routing/TCP failure in the Grafana matrix.
          probe_ip = primary_ip or remembered_ip
          ip_source = "dns-current" if primary_ip else ("last-known" if remembered_ip else "none")

          tcp_started = time.monotonic()
          tcp_success = 0
          if probe_ip:
              try:
                  with socket.create_connection((probe_ip, port), timeout=3.0):
                      tcp_success = 1
              except OSError:
                  tcp_success = 0
          tcp_duration = time.monotonic() - tcp_started

          ip_labels = dict(base_labels)
          ip_labels["resolved_ip"] = probe_ip
          ip_labels["ip_source"] = ip_source
          ip_labels["port"] = str(port)
          lines.append(
              f'fbl_ip_tcp_success{{{labelset(**ip_labels)}}} {tcp_success}'
          )
          lines.append(
              f'fbl_ip_tcp_duration_seconds{{{labelset(**ip_labels)}}} {tcp_duration:.6f}'
          )
          lines.append(
              f'fbl_network_probe_timestamp_seconds{{{labelset(**base_labels)}}} {time.time():.3f}'
          )

      os.makedirs(os.path.dirname(STATE_FILE), mode=0o750, exist_ok=True)
      state_temp = STATE_FILE + ".tmp"
      with open(state_temp, "w", encoding="utf-8") as handle:
          json.dump(last_known_ips, handle, sort_keys=True)
          handle.write("\n")
      os.chmod(state_temp, 0o600)
      os.replace(state_temp, STATE_FILE)

      os.makedirs(os.path.dirname(METRICS_FILE), mode=0o755, exist_ok=True)
      temp_file = METRICS_FILE + ".tmp"
      with open(temp_file, "w", encoding="utf-8") as handle:
          handle.write("\n".join(lines) + "\n")
      os.chmod(temp_file, 0o644)
      os.replace(temp_file, METRICS_FILE)
      PY
    '';
  };

  systemd.timers.fbl-network-diagnostics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      AccuracySec = "5s";
      Persistent = true;
    };
  };
}

# [GPT-5.6 Sol] создал в 23:53 05.09.2026 (МСК).

# [GPT-5.6 Sol] изменил в 23:20 08.09.2026 (МСК).

# [GPT-5.6 Sol] прочитал в 00:52 13.09.2026 (МСК).
