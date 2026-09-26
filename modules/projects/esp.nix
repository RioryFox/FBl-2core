{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps: with ps; [ numpy pillow ]))
    esptool
    ffmpeg
    platformio
    v4l-utils
  ];
}
