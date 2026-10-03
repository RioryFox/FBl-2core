{ pkgs, ... }:

with pkgs;
[
  #сортировка не идеальная, мб поменяется
  # ─────────────────────────────────────────────
  # SECURITY / PENTEST
  # ─────────────────────────────────────────────
  aircrack-ng
  hashcat
  arp-scan
  lynis
  testssl

  # ─────────────────────────────────────────────
  # NETWORK / DIAGNOSTICS
  # ─────────────────────────────────────────────
  dig
  httpie
  inetutils
  iperf3
  iw
  mtr
  netcat-openbsd
  tcpdump
  traceroute
  wavemon
  whois
]

