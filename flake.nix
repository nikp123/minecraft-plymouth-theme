{
  description = "Minecraft plymouth theme";

  outputs = { self, nixpkgs }:
    let
      systems =
        [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });
    in rec {
      overlay = final: prev: {
        plymouth-minecraft-theme = final.stdenvNoCC.mkDerivation {
          name = "plymouth-minecraft-theme";
          version = "unstable";
          description = "Minecraft plymouth theme";

          src = self;

          nativeBuildInputs = with final; [ 
            imagemagick
            bash
          ];

          # Slightly modified compared to ./install.sh
          installPhase = ''
            # Change outpaths from /usr to the path in the nix store
            sed -i "s@\/usr\/@$out\/@" ./plymouth/mc.plymouth
            PLYMOUTH_THEME_BASEDIR=$out/share/plymouth/themes/mc
            FONTCONFIG_PATH=$out/fonts/conf.d/

            # Copy font
            install -v -d -m 0755 $out/share/fonts/OTF/
            install -v -m 0644 ./font/Minecraft.otf $out/share/fonts/OTF/

            # Copy plymouth theme
            install -v -d -m 0755 $PLYMOUTH_THEME_BASEDIR
            install -v -m 0644 ./plymouth/mc.script $PLYMOUTH_THEME_BASEDIR
            install -v -m 0644 ./plymouth/mc.plymouth $PLYMOUTH_THEME_BASEDIR
            install -v -m 0644 ./plymouth/progress_bar.png $PLYMOUTH_THEME_BASEDIR
            install -v -m 0644 ./plymouth/progress_box.png $PLYMOUTH_THEME_BASEDIR

            # Create smaller versions of assets
            for j in "padlock" "bar"; do
              for i in $(seq 1 6); do
                convert ./plymouth/$j.png -interpolate Nearest -filter point -resize "$i"00% $PLYMOUTH_THEME_BASEDIR/$j-"$i".png
              done
            done

            for i in $(seq 1 12); do
              magick ./plymouth/dirt.png -channel R -evaluate multiply .2509803922 -channel G -evaluate multiply .2509803922 -channel B -evaluate multiply .2509803922 -interpolate Nearest -filter point -resize "$i"00% $PLYMOUTH_THEME_BASEDIR/dirt-"$i".png
            done
          '';
        };
      };

      packages =
        forAllSystems (system: { inherit (nixpkgsFor.${system}) plymouth-minecraft-theme; });

      defaultPackage = forAllSystems (system: self.packages.${system}.plymouth-minecraft-theme);

      defaultApp = forAllSystems (system: self.apps.${system}.plymouth-minecraft-theme);

      devShell = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.mkShell {
          inputsFrom = builtins.attrValues (packages.${system});
        });
    };
}
