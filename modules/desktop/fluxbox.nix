{ pkgs, ... }:

{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    windowManager.fluxbox.enable = true;
    xkb = {
      layout = "us,ru";
      options = "grp:alt_shift_toggle";
    };
  };

  environment.systemPackages = with pkgs; [
    chromium
    feh
    firefox
    fluxbox
    kitty
    pavucontrol
    rofi
    vscodium
    wezterm
    xterm
  ];
}
