{ pkgs, ... }:

let 
  espPython = pkgs.python3.withPackages (ps: with ps; [
    numpy 
    pillow 
    pyserial
  ]);

  espPythonCli = pkgs.writeShellScriptBin "esp-py" ''
    exec ${espPython}/bin/python3 "$@"
  '';

in
{
  environment.systemPackages = with pkgs; [
    espPythonCli

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
