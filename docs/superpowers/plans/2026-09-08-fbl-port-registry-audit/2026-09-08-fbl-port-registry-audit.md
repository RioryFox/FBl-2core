# FBl-2core Port Registry Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `modules/registry/ports.nix` the only active FBl-2core source of numeric TCP/UDP port values, including host, container, backend, proxy, monitoring, protocol and auxiliary ports.

**Architecture:** Keep numeric port allocation in the typed `fbl.ports.tcp` / `fbl.ports.udp` registry. Every host/service module consumes semantic registry keys and never embeds an assigned TCP/UDP port literal. Standard protocol ports used by policy code (HTTP/HTTPS/DNS/QUIC) are registry entries too. Sentinel values that are not allocated/listening ports (for example Squid ICP `0`) are not treated as port allocations.

**Tech Stack:** NixOS modules, Nix expressions, nftables/Squid/Xray generated configuration, Podman OCI container mappings, Google Drive canonical FBl-2core tree.

**Spec:** User architectural invariant in RF_lab conversation on 08.09.2026: `registry/ports.nix` owns host ports, container ports and auxiliary ports; no explicit numeric TCP/UDP port values elsewhere.

## Global Constraints

- Canonical source is Google Drive `FBL/FBl-2core`; `/etc/nixos` is not source of truth.
- Modify only active FBl-2core files; do not rewrite archived/superseded snapshots.
- Do not delete Drive content.
- Preserve current runtime port values unless centralization itself requires a semantic key split.
- Every read/changed Drive file gets a model/timestamp signature.
- Re-run static port-literal audit after edits and re-fetch changed Drive files before claiming completion.

---

### Task 1: Extend the typed port registry

**Files:**
- Modify: `modules/registry/ports.nix`

**Interfaces:**
- Produces TCP keys: `dns`, `http`, `https`, `metubeContainer`, `jellyfinRuntime`.
- Produces UDP keys: `dns`, `quic`.
- Existing keys and numeric assignments remain unchanged.

- [ ] Add the semantic keys with current values: DNS 53, HTTP 80, HTTPS 443, MeTube internal 8081, Jellyfin runtime 8096, QUIC 443.
- [ ] Add a comment documenting that assigned TCP/UDP literals are forbidden outside this registry.
- [ ] Parse/check the resulting Nix syntax where tooling is available.

### Task 2: Remove service-level port literals

**Files:**
- Modify: `modules/services/metube.nix`
- Modify: `modules/services/jellyfin.nix`
- Modify: `modules/services/prometheus.nix`
- Modify: `modules/services/network-diagnostics.nix`

**Interfaces:**
- MeTube consumes `fbl.ports.tcp.metubeContainer`.
- Jellyfin compares public registry port to `fbl.ports.tcp.jellyfinRuntime` until its upstream runtime listener is managed declaratively.
- Prometheus external DNS probes consume `fbl.ports.udp.dns`.
- Network diagnostics trust the typed `externalSites[].port` field and provide no local numeric fallback.

- [ ] Replace MeTube `containerPort = 8081` with the registry key.
- [ ] Replace Jellyfin `== 8096` and numeric explanatory text with a registry-to-registry constraint.
- [ ] Replace Prometheus `:53` DNS target strings with interpolation of registry DNS port.
- [ ] Remove `target.get("port", 443)` fallback from network diagnostics in favor of `target["port"]`.

### Task 3: Remove policy/gateway protocol literals

**Files:**
- Modify: `hosts/iHF02T-6/hf-proxy.nix`
- Modify: `hosts/iHF02T-6/hf-gateway-test.nix`
- Modify: `hosts/iHF02T-6/vpn-gateway.nix`

**Interfaces:**
- Squid ACLs consume registry HTTP/HTTPS ports.
- Transparent gateway rules consume registry TCP HTTP/HTTPS and UDP QUIC ports.
- VPN/Tor gateway consumes separate registry TCP/UDP DNS ports and propagates them into generated Xray JSON and nftables rules.

- [ ] Replace Squid ACL literal 80/443 values with registry variables.
- [ ] Replace transparent HTTP/HTTPS/QUIC nftables literal ports with registry variables.
- [ ] Export DNS TCP/UDP ports into the Xray generator; replace `rewritePort` and routing literals.
- [ ] Split mixed DNS matching where necessary so TCP and UDP registry values remain independently configurable.

### Task 4: Remove monitoring registry duplication

**Files:**
- Modify: `modules/registry/monitoring.nix`

**Interfaces:**
- `externalSiteType.port.default` consumes `config.fbl.ports.tcp.https`.
- Default external site rows rely on that field default instead of repeating 443.

- [ ] Add `config` module argument.
- [ ] Replace numeric default 443 with registry reference.
- [ ] Remove redundant `port = 443` entries from each default monitored site.

### Task 5: Active documentation and invariant

**Files:**
- Review/modify when duplicated active FBL-owned port numbers are present: `README.md` and service docs such as `QBITTORRENT_CR01.md`.

**Interfaces:**
- Human documentation identifies semantic registry keys instead of duplicating assignable numeric FBL port values.

- [ ] Replace active service-port tables/endpoints that duplicate registry allocations with registry-key references where this avoids drift.
- [ ] Do not rewrite historical/archive documents or external reference material.

### Task 6: Verification and handoff

**Files:**
- Re-read every modified Drive file.
- Create/update a brief `AI_HANDOFF` entry describing the invariant and changed files.

- [ ] Run a static audit for assigned port literals outside `modules/registry/ports.nix`, specifically covering `dport`, `acl ... port`, container mappings, listener/port assignments, protocol fallback values and `host:port` targets.
- [ ] Confirm known former violations (53, 80, 443, 8081, 8096) are absent from active implementation files outside the registry where they represent network ports.
- [ ] Run `nix-instantiate --parse` / equivalent if available; otherwise record that only static verification was possible here and require a Cr01 flake build before deployment.
- [ ] Re-fetch all modified files from Google Drive and verify expected registry references exist.
- [ ] Leave an AI_HANDOFF summary; do not claim runtime deployment because Drive edits alone do not rebuild Cr01/iHF.


## Execution result — 23:40 08.09.2026 МСК

- Drive edits completed for registry, MeTube/Jellyfin, iHF proxy/gateway/VPN, monitoring/diagnostics/Prometheus and active port-facing documentation.
- Static literal audit: PASS.
- Embedded vpn-gateway Python compile check: PASS.
- Post-write Drive searches found no remaining active literals for the audited service/protocol values in service/iHF/iVN scopes.
- Nix evaluation/build is **not** claimed here because this execution environment has no `nix`/`nix-instantiate`; Cr01 flake check/build remains the rollout gate.
- Historical CHANGELOG entries and archive/stage snapshots are intentionally not rewritten.
