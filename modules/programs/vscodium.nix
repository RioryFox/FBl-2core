{ pkgs, ... }:

let
  wallpaper = ../../assets/vscodium-wallpapers/test.png;

  vscodiumFbl = pkgs.vscodium.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      css="$(find "$out" -name 'workbench.desktop.main.css' | head -n1)"

      cat >> "$css" <<EOF

      /* FBL VSCodium background */
      body,
      .monaco-workbench {
        background-image: url("file://${wallpaper}") !important;
        background-size: cover !important;
        background-position: center !important;
        background-attachment: fixed !important;
      }

      .part.editor,
      .editor-group-container,
      .monaco-editor,
      .monaco-editor-background,
      .margin {
        background-color: transparent !important;
      }
EOF
    '';
  });

  vscodiumFblLauncher = pkgs.writeShellScriptBin "codium-fbl" ''
    exec ${vscodiumFbl}/bin/codium \
      --user-data-dir "''${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium-FBL" \
      --extensions-dir "''${XDG_DATA_HOME:-$HOME/.local/share}/vscodium-fbl/extensions" \
      "$@"
  '';

  vscodiumFblDesktop = pkgs.makeDesktopItem {
    name = "vscodium-fbl";
    desktopName = "VSCodium FBL";
    genericName = "FBL Experimental Editor";
    comment = "Experimental FBL VSCodium build";
    exec = "codium-fbl %F";
    icon = "vscodium";
    terminal = false;
    categories = [ "Development" "IDE" ];
  };

in
{
  environment.systemPackages = [
    pkgs.vscodium
    vscodiumFblLauncher
    vscodiumFblDesktop
  ];
}