# iAF01T-8 — Azure Fox Workstation MicroVM

Назначение: отдельная рабочая/экспериментальная MicroVM на `Cr01MS-32`.
AI models/Ollama в этой VM не размещаются.

## Ресурсы

- 2 vCPU;
- 8 GiB RAM;
- persistent `/var`: 10 GiB;
- read-only `/nix/store` с Cr01;
- autostart принадлежит Cr01.

## Сеть

Адреса и интерфейсы — из `modules/registry/network.nix`:

- LAN: `192.168.3.8/24`;
- gateway: `192.168.3.1`;
- host-only broker link: `10.253.8.1/30 <-> 10.253.8.2/30`;
- SSH listener port — из `modules/registry/ports.nix`.

SSH во всём FBL key-only; парольная SSH-аутентификация отключена общим модулем.

## Cyber profile

```nix
cyber.enable = true;
cyber.role = "student";
```

Используется штатный FBL student-набор `modules/cyber/roles/student.nix`.

## Monitoring

Локальный node_exporter собирается Prometheus agent внутри VM и отправляется
remote_write на `iHF02T-6`. Destination address/port берутся из network/port
registry. Метрики используют `fbl_host=iAF01T-8`, job `iaf01-node`.

## Validation

```bash
nix build --no-link \
  .#nixosConfigurations.iAF01T-8-VM.config.system.build.toplevel
```

Production autostart/definition проверяется через `Cr01MS-32`.
