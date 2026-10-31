{ pkgsUnstable, config, ... }:
let  
  httpsPort = toString config.fbl.ports.tcp.https;
  quicPort = toString config.fbl.ports.udp.quic;
  discordVoice = config.fbl.ports.udpRanges.discordVoice;
  discordMedia = config.fbl.ports.udpRanges.discordMedia;

  queueRange = r:"${toString r.from}:${toString r.to}";
  filterRange = r:"${toString r.from}-${toString r.to}";

in {
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
      quicPort
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
      "--filter-udp=${quicPort}"
      "--filter-l7=quic"
      "--hostlist-domains=youtube.com,googlevideo.com,ytimg.com,youtu.be"
      "--dpi-desync=fake"
      "--dpi-desync-repeats=6"
      "--new"
      "--filter-tcp=${httpsPort}"
      "--dpi-desync=fake,disorder2"
      "--dpi-desync-ttl=1"
      "--dpi-desync-autottl=2"
    ];
  };
}
