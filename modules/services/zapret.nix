{ config, ... }:

{
  services.zapret = {
    enable = true;

    whitelist = [
      "youtube.com"
      "googlevideo.com"
      "ytimg.com"
      "discord.com"
    ];

    params = [
      "--dpi-desync=fake,disorder2"
      "--dpi-desync-ttl=1"
      "--dpi-desync-autottl=2"
    ];

    udpSupport = false;
  };
} 