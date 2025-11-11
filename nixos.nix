{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.plymouth.plymouth-minecraft-theme;

  inherit (lib)
    mkEnableOption
    mkOption
    ;

  inherit (lib.types) package;
in
{
  options.boot.plymouth.plymouth-minecraft-theme = {
    enable = mkEnableOption "minecraft theme for plymouth";
    package = mkOption {
      type = package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./default.nix { }";
      description = "The plymouth-minecraft-theme package to use.";
    };
  };

  config.boot.plymouth = lib.mkIf cfg.enable {
    font = "${cfg.package}/share/fonts/OTF/Minecraft.otf";
    theme = "mc";
    themePackages = [ cfg.package ];
  };

  # Required so that the Minecraft font also appears during shutdown.
  # The issue is that Plymouth NixOS module only includes the font
  # inside of the initram and not on the rootfs.
  config.fonts.packages = lib.mkIf cfg.enable [ cfg.package ];
}
