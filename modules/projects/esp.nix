{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (python3.withPackages (ps: with ps; [ 
      numpy 
      pillow 
      pyserial
    ]))
    arduino-cli
    esptool
    ffmpeg
    platformio
    v4l-utils
    picocom
    dfu-util
    #opencod
    #gcc-arm-embadded
  ];
}
