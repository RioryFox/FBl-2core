{ pkgs, ... }:

let
  wallpaper = ../../assets/vscodium-wallpapers/test.png;

  vscodiumFbl = pkgs.vscodium.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      css="$(find "$out" -name 'workbench.desktop.main.css' -print -quit)"
      product="$(find "$out" -path '*/resources/app/product.json' -print -quit)"

      test -n "$css" || {
        echo "FBL: workbench.desktop.main.css not found"
        exit 1
      }

      test -n "$product" || {
        echo "FBL: product.json not found"
        exit 1
      }

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

      # product.json stores the path relative to resources/app/out/
      key="''${css#*/resources/app/out/}"

      digest="$(
        ${pkgs.openssl}/bin/openssl dgst -sha256 -binary "$css" \
          | ${pkgs.coreutils}/bin/base64 \
          | ${pkgs.coreutils}/bin/tr -d '=\n'
      )"

      ${pkgs.jq}/bin/jq \
        --arg key "$key" \
        --arg hash "$digest" \
        '
          if (.checksums[$key] // null) == null then
            error("FBL: checksum key missing: " + $key)
          else
            .checksums[$key] = $hash
          end
        ' \
        "$product" > "$product.tmp"

      ${pkgs.coreutils}/bin/mv "$product.tmp" "$product"

      echo "FBL: patched $key"
      echo "FBL: updated checksum to $digest"
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
