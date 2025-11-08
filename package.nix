{ imagemagick, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  name = "plymouth-minecraft-theme";
  version = "0";

  src = ./.;

  nativeBuildInputs = [
    imagemagick
  ];

  # Slightly modified compared to ./install.sh
  # TODO: write install.sh in a portable way
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
        magick ./plymouth/$j.png -interpolate Nearest -filter point -resize "$i"00% $PLYMOUTH_THEME_BASEDIR/$j-"$i".png
      done
    done

    for i in $(seq 1 12); do
      magick ./plymouth/dirt.png -channel R -evaluate multiply .2509803922 -channel G -evaluate multiply .2509803922 -channel B -evaluate multiply .2509803922 -interpolate Nearest -filter point -resize "$i"00% $PLYMOUTH_THEME_BASEDIR/dirt-"$i".png
    done
  '';
}
