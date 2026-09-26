{ pkgs, ... }:

with pkgs;
[
  #сортировка не идеальная, мб поменяется
  # ─────────────────────────────────────────────
  # SECURITY / PENTEST
  # ─────────────────────────────────────────────
  aircrack-ng
  #hashcat
  arp-scan
  lynis
  nmap
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

  # ─────────────────────────────────────────────
  # SYSTEM INFO / HARDWARE
  # ─────────────────────────────────────────────
  btop
  htop
  dmidecode
  gpufetch
  inxi
  ipfetch
  lm_sensors
  lsof
  pciutils
  usbutils

  # ─────────────────────────────────────────────
  # FILESYSTEM / STORAGE
  # ─────────────────────────────────────────────
  #file
  parted
  tree

  # ─────────────────────────────────────────────
  # CLI / SHELL UTILITIES
  # ─────────────────────────────────────────────
  curl
  fd
  jq
  ripgrep
  wget
  yq

  # ─────────────────────────────────────────────
  # ARCHIVE / TRANSFER / SYNC
  # ─────────────────────────────────────────────
  p7zip
  unzip
  rclone
  rsync

  # ─────────────────────────────────────────────
  # DEVELOPMENT
  # ─────────────────────────────────────────────
  gcc
  gh
  gnumake
  openssl
  python3
  go
  rust

  # ─────────────────────────────────────────────
  # EDITORS / FILE MANAGERS
  # ─────────────────────────────────────────────
  mc
  nano
  vim
  yazi

  # ───────────────────────────────────────────────
  # TERMINAL / SESSION MANAGEMENT
  # ─────────────────────────────────────────────
  screen
  tmux
]

