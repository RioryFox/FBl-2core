{ pkgsUnstable, config, ... }:
let 
  httpsPort
  quicPort = toString config.fbl.ports.udp.quic;
  discordVoice = config.fbl.ports.udpRanges.discordVoice;
  discordMedia = config.fbl.ports.udpRanges.discordMedia;

{
  services.zapret = {
    enable = true;
    package = pkgsUnstable.zapret;

    configureFirewall = true;
    httpSupport = false;

    whitelist = [
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

    udpSupport = true;

    udpPorts = [
      quicPort;
      (queueRange discordVoice)
      (queueRange discordMedia)
    ];

    params = [
      "--filter-udp=${filterRange discordVoice},${filterRange discordMedia}"
      "--filter-l7=discord,stun"
      "--dpi-desync=fake"
      "--dpi-desync-repeats=6"
      "--dpi-desync-any-protocol"
      "--new"
      "--filter-udp=${httpsPort}"
      "--filter-l7=${quicPort}"
      "--hostlist-domains=youtube.com,googlevideo.com,ytimg.com,youtu.be"
      "--dpi-desync=fake"
      "--dpi-desync-repeats=6"
      "--new"
      "--filter-tcp=${quicPort}"
      "--dpi-desync=fake,disorder2"
      "--dpi-desync-ttl=1"
      "--dpi-desync-autottl=2"
    ];

    networking.firewall = {
                enable = true;
                allowedTCPPorts =
                        if config.services.zapret.enable
                        then [ ]
                        else [ ];
                allowedUDPPorts =
                        if config.services.zapret.enable
                        then [  ]
                        else [ ];     
        };   
  };
}
