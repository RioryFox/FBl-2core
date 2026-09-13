{
  description = "Tabby Terminal packaged from the official AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pname = "tabby-terminal";
          version = "1.0.235";
          src = pkgs.fetchurl {
            url = "https://github.com/Eugeny/tabby/releases/download/v${version}/tabby-${version}-linux-x64.AppImage";
            hash = "sha256-DKXcAV/l7nhA8rIGhkzDfFL3w2t6c06GU6Oa6KV23O8=";
          };
          appimageContents = pkgs.appimageTools.extractType2 {
            inherit pname version src;
          };
        in {
          default = pkgs.appimageTools.wrapType2 {
            inherit pname version src;

            extraInstallCommands = ''
              # Tabby runs from an AppImage wrapper. On NixOS, privileged
              # commands must resolve through /run/wrappers/bin so that the
              # setuid sudo wrapper is used. Keep the normal system profile
              # on PATH as well; sudo still prompts for the user password.
              mv "$out/bin/tabby-terminal" "$out/bin/.tabby-terminal-real"
              cat > "$out/bin/tabby-terminal" <<'EOF'
              #!/bin/sh
              export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
              exec "$(dirname "$0")/.tabby-terminal-real" --no-sandbox "$@"
              EOF
              chmod +x "$out/bin/tabby-terminal"

              desktopFile="$(find ${appimageContents} -name '*.desktop' -print -quit)"
              if [ -n "$desktopFile" ]; then
                install -Dm444 "$desktopFile" "$out/share/applications/tabby-terminal.desktop"
                substituteInPlace "$out/share/applications/tabby-terminal.desktop" \
                  --replace-warn 'Exec=AppRun' 'Exec=tabby-terminal' \
                  --replace-warn 'Exec=tabby ' 'Exec=tabby-terminal '
              fi

              if [ -d ${appimageContents}/usr/share/icons ]; then
                mkdir -p "$out/share"
                cp -r ${appimageContents}/usr/share/icons "$out/share/"
              fi
            '';

            meta = {
              description = "Modern terminal with SSH profiles, splits and side tabs";
              homepage = "https://tabby.sh/";
              license = pkgs.lib.licenses.mit;
              mainProgram = "tabby-terminal";
              platforms = [ "x86_64-linux" ];
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/tabby-terminal";
        };
      });
    };
}
