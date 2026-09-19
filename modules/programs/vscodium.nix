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


in

{
        programs.vscodium = {
                enable = true;
                package = vscodiumFbl;
        };
}