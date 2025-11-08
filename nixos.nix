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
    theme = "mc";
    themePackages = [ cfg.package ];
  };
}
