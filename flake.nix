{
  description = "Kaname - a Quickshell radial dmenu for Niri";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      homeManagerModules = {
        default = import ./nix/home-manager.nix { inherit self; };
        kaname = self.homeManagerModules.default;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          app = pkgs.stdenvNoCC.mkDerivation {
            pname = "kaname";
            version = "0.1.0";
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ pkgs.qt6.qtimageformats ];
            dontWrapQtApps = true;
            installPhase = ''
              mkdir -p $out/bin $out/share/kaname
              cp -r quickshell config matugen $out/share/kaname/
              install -Dm755 bin/kaname $out/libexec/kaname
              makeWrapper $out/libexec/kaname $out/bin/kaname \
                --set KANAME_QML_DIR $out/share/kaname/quickshell \
                --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtimageformats}/lib/qt-6/plugins \
                --prefix PATH : ${nixpkgs.lib.makeBinPath [ pkgs.coreutils pkgs.quickshell ]}
              makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/kaname-shell \
                --add-flags "-p $out/share/kaname/quickshell" \
                --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtimageformats}/lib/qt-6/plugins
            '';
            meta = {
              mainProgram = "kaname";
              license = pkgs.lib.licenses.mit;
            };
          };
        in {
          default = app;
          kaname = app;
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.quickshell pkgs.qt6.qtdeclarative pkgs.qt6.qtimageformats pkgs.shellcheck ];
            shellHook = ''
              actual="$(quickshell --version 2>/dev/null || true)"
              case "$actual" in *"0.3.0"*) ;; *)
                echo "kaname: expected Quickshell 0.3.0, got: $actual" >&2
                return 1
              esac
            '';
          };
        });
    };
}
