{ config, inputs, pkgsUnstable, ... }:

let
  httpsPort = config.fbl.ports.tcp.https;
  egressInterface = config.fbl.network.interfaces.gf01Lan;
in {
  imports = [
    (inputs.nixpkgsUnstable.outPath
      + "/nixos/modules/services/networking/zapret2.nix")
  ];

  networking.nftables.enable = true;

  services.zapret2 = {
    enable = true;
    package = pkgsUnstable.zapret2;

    firewall = {
      configureAutomatically = true;
      interfaces = [ egressInterface ];

      tcpPorts = [ httpsPort ];
      udpPorts = [];

      maxPackets = 16;
      queue = 200;
    };

    profiles.https = {
      priority = 100;

      hosts.include = [
        "youtube.com"
        "youtu.be"
        "googlevideo.com"
        "ytimg.com"
        "youtubei.googleapis.com"

        "discord.com"
        "discord.gg"
        "discordapp.com"
        "discordapp.net"
        "discord.media"
      ];

      parameters = [
        "--filter-tcp=${toString httpsPort}"
        "--payload=tls_client_hello"
        "--lua-desync=fake:blob=fake_default_tls:tcp_ts=-1000:repeats=1"
        "--lua-desync=fakedsplit:pos=1,midsld:tcp_ts=-1000"
      ];
    };
  };
}
