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
            installPhase = ''
              mkdir -p $out/bin $out/share/kaname
              cp -r quickshell config matugen $out/share/kaname/
              install -Dm755 bin/kaname $out/libexec/kaname
              install -Dm755 bin/kaname-shell $out/libexec/kaname-shell
              makeWrapper $out/libexec/kaname $out/bin/kaname \
                --set KANAME_QML_DIR $out/share/kaname/quickshell \
                --prefix PATH : ${nixpkgs.lib.makeBinPath [ pkgs.coreutils ]}
              makeWrapper $out/libexec/kaname-shell $out/bin/kaname-shell \
                --set KANAME_QML_DIR $out/share/kaname/quickshell
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
            packages = [ pkgs.quickshell pkgs.shellcheck ];
          };
        });
    };
}
