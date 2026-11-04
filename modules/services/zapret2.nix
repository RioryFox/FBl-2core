{ config, inputs, pkgsUnstable, ... }:

let
  httpsPort = config.fbl.ports.tcp.https;
  
  myInterface =
    if config.networking.hostName == "Cr01MS-32"
    then config.fbl.network.interfaces.cr01Lan
    else if config.networking.hostName == "GF01WS-16"
    then config.fbl.network.interfaces.gf01Lan
    else throw "Unsupported FBL host for zapret2";

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
      interfaces = [ myInterface ];

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
