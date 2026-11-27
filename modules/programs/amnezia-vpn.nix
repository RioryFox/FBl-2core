{ pkgs, pkgsUnstable, ... }:

let
  amnezia = pkgs.symlinkJoin {
  name = "amnezia-vpn-wrapped";

  paths = [ pkgsUnstable.amnezia-vpn ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/AmneziaVPN" \
      --unset QML_IMPORT_PATH \
      --unset QML2_IMPORT_PATH \
      --unset QT_PLUGIN_PATH \
      --unset QT_QPA_PLATFORMTHEME \
      --unset QT_STYLE_OVERRIDE \
      --set QT_QPA_PLATFORM xcb
  '';

  };
in
{
  programs.amnezia-vpn = {
    enable = true;
    package = amnezia;
  };

  systemd.services.AmneziaVPN.path = with pkgs; [
    gawk
    iptables
  ];
}