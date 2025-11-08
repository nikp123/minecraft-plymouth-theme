{
  stdenvNoCC,
  imagemagick,
}:
stdenvNoCC.mkDerivation {
  name = "plymouth-minecraft-theme";
  version = "0";

  src = ./.;

  nativeBuildInputs = [
    imagemagick
  ];

  installPhase = ''
    patchShebangs .

    # Change outpaths from /usr to the path in the nix store
    sed -i -e "s@\/usr\/@$out\/@g" ./plymouth/mc.plymouth

    # configure install.sh
    export FONTCONFIG_PATH=$out/fonts/conf.d
    export FONTS_BASEDIR=$out/share/fonts
    export FONT_PATH=$out/fonts
    export NO_IMPURE=1
    export PLYMOUTH_THEME_BASEDIR=$out/share/plymouth/themes/mc

    ./install.sh
  '';
}
