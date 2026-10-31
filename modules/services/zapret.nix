{ pkgsUnstable, ... }:

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
      "443"
      "19294:19344"
      "50000:50100"
    ];

    params = [
      "--filter-udp=19294-19344,50000-50100"
      "--filter-l7=discord,stun"
      "--dpi-desync=fake"
      "--dpi-desync-repeats=6"
      "--dpi-desync-any-protocol"
      "--new"
      "--filter-udp=443"
      "--filter-l7=quic"
      "--hostlist-domains=youtube.com,googlevideo.com,ytimg.com,youtu.be"
      "--dpi-desync=fake"
      "--dpi-desync-repeats=6"
      "--new"
      "--filter-tcp=443"
      "--dpi-desync=fake,disorder2"
      "--dpi-desync-ttl=1"
      "--dpi-desync-autottl=2"
    ];
  };
}
