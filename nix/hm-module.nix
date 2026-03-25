self: {
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.inir;
  inir = self.packages.${pkgs.system}.default;
in {
  options.programs.inir = {
    enable = lib.mkEnableOption "iNiR desktop shell for Niri";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inir

      # Fonts iNiR expects
      pkgs.material-symbols
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.noto-fonts-color-emoji

      # Icon themes
      pkgs.papirus-icon-theme
      pkgs.adw-gtk3
      pkgs.hicolor-icon-theme
      pkgs.kdePackages.breeze-icons

      # Cursor theme
      pkgs.capitaine-cursors

      # Qt theming
      pkgs.qt6Packages.qtstyleplugin-kvantum

      # Runtime tools (also in PATH via wrapper, but user may want them directly)
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.brightnessctl
      pkgs.matugen
      pkgs.fuzzel
      pkgs.grim
      pkgs.slurp
      pkgs.playerctl
      pkgs.imagemagick
    ];

    # Symlink shell source so Quickshell can find it via `qs -c ii`
    # Read-only is fine — iNiR stores mutable state in XDG_STATE_HOME/XDG_CACHE_HOME
    xdg.configFile."quickshell/ii".source = "${inir}/share/inir";
  };
}
