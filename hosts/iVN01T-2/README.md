# iVN01T-2 — remote-access / VPN MicroVM

`iVN01T-2` — отдельная QEMU MicroVM на `Cr01MS-32` для remote-access/VPN
функций, отделённых от прикладного Cr01.

## VM profile

- 2 vCPU;
- 4 GiB RAM;
- persistent `/var`: 10 GiB;
- `/nix/store`: read-only share с Cr01;
- autostart принадлежит Cr01;
- LAN attachment: macvtap на физический Cr01 LAN;
- адрес/шлюз/DNS/interface берутся из `modules/registry/network.nix`.

Текущие registry values: `192.168.3.9/24`, gateway `192.168.3.1`.

## SSH

Общая политика FBL — key-only SSH через `modules/services/ssh.nix`.
Парольная SSH-аутентификация отключена. Local console recovery — отдельный
механизм и не означает разрешение SSH password login.

## WireGuard

`hosts/iVN01T-2/vpn.nix` использует registry:

- interface `wg0`;
- server subnet `10.66.0.0/24`;
- server address `10.66.0.1/24`;
- UDP listener берётся только из `fbl.ports.udp.wireguard`; числовое значение не дублируется в host-документации;
- private key создаётся локально в `/var/lib/wireguard/iVN01T-2.key` и не
  хранится в Drive/Nix source.

Первоначальный peer list может быть пуст. Public keys клиентов добавляются
декларативно; private keys клиентов не копируются в FBL source.

## Tailscale

Tailscale обсуждается как возможный второй remote-access механизм именно на
`iVN01T-2`. Он пока не считается внедрённым и не должен подменять существующий
WireGuard без отдельного решения по маршрутизации/ACL.

## Validation

Guest-only:

```bash
nix build --no-link \
  .#nixosConfigurations.iVN01T-2-VM.config.system.build.toplevel
```

Production definition/autostart:

```bash
sudo nixos-rebuild build --flake .#Cr01MS-32
sudo nixos-rebuild dry-activate --flake .#Cr01MS-32
```

Internet port-forwarding до iVN не считать настроенным без отдельной проверки
edge NAT/CGNAT.
