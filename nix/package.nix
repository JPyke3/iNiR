{
  lib,
  stdenvNoCC,
  version,
  quickshell,
  qt6,
  # Runtime dependencies (injected via PATH)
  bash,
  coreutils,
  gnused,
  gnugrep,
  findutils,
  gawk,
  grim,
  slurp,
  swappy,
  wf-recorder,
  imagemagick,
  ffmpeg,
  jq,
  curl,
  rsync,
  git,
  wl-clipboard,
  brightnessctl,
  cliphist,
  matugen,
  swayidle,
  swaylock,
  playerctl,
  socat,
  ydotool,
  wtype,
  mpv,
  yt-dlp,
  fuzzel,
  translate-shell,
  hyprpicker,
  gum,
  tesseract,
  cava,
  libnotify,
  xdg-utils,
  procps,
  killall,
  networkmanager,
  wireplumber,
  wlsunset,
  libqalculate,
  # Python environment
  python3,
  # Icon/sound path resolution
  hicolor-icon-theme,
  papirus-icon-theme,
  adw-gtk3,
  kdePackages,
}: let
  inirPython = python3.withPackages (ps:
    with ps; [
      pillow
      opencv4
      material-color-utilities
      materialyoucolor
      numpy
      psutil
      tqdm
      loguru
      click
      pygobject3
      pycairo
      python-magic
      # kde-material-you-colors  # broken in nixpkgs (missing python-magic propagated dep); matugen handles color gen
    ]);

  runtimePath = lib.makeBinPath [
    bash
    coreutils
    gnused
    gnugrep
    findutils
    gawk
    grim
    slurp
    swappy
    wf-recorder
    imagemagick
    ffmpeg
    jq
    curl
    rsync
    git
    wl-clipboard
    brightnessctl
    cliphist
    matugen
    swayidle
    swaylock
    playerctl
    socat
    ydotool
    wtype
    mpv
    yt-dlp
    fuzzel
    translate-shell
    hyprpicker
    gum
    tesseract
    cava
    libnotify
    xdg-utils
    procps
    killall
    networkmanager
    wireplumber
    wlsunset
    libqalculate
    inirPython
  ];
in
  stdenvNoCC.mkDerivation {
    pname = "inir";
    inherit version;
    src = lib.cleanSource ./..;

    nativeBuildInputs = [qt6.wrapQtAppsHook];
    buildInputs = [qt6.qtbase qt6.qtmultimedia qt6.qtsvg qt6.qtimageformats];
    dontBuild = true;

    postPatch = ''
      # =====================================================================
      # Strip /usr/bin/ prefixes — binaries will be found via PATH wrapping
      # Exclude shebangs (#!/usr/bin/env) which must remain intact
      # =====================================================================
      find . -type f \( -name "*.qml" -o -name "*.sh" -o -name "*.py" \
        -o -name "*.fish" -o -name "*.js" -o -name "*.kdl" \) \
        -exec sed -i '/^#!/!s|/usr/bin/||g' {} +

      # =====================================================================
      # Patch Python venv wrapper scripts to use Nix python directly
      # =====================================================================
      for f in scripts/thumbnails/thumbgen-venv.sh \
               scripts/images/find-regions-venv.sh \
               scripts/images/least-busy-region-venv.sh; do
        if [ -f "$f" ]; then
          substituteInPlace "$f" \
            --replace-quiet 'source "$_ii_venv/bin/activate" 2>/dev/null || true' '# Nix: venv not needed' \
            --replace-quiet '"$_ii_venv/bin/python3"' 'python3' \
            --replace-quiet 'GIO_USE_VFS=local "$_ii_venv/bin/python3"' 'GIO_USE_VFS=local python3' \
            --replace-quiet 'deactivate 2>/dev/null || true' '# Nix: no venv to deactivate'
        fi
      done

      # =====================================================================
      # Patch /usr/share/icons paths — add NixOS-compatible search paths
      # =====================================================================
      if [ -f services/IconThemeService.qml ]; then
        substituteInPlace services/IconThemeService.qml \
          --replace-quiet '"/usr/share/icons"' '"/usr/share/icons", "/run/current-system/sw/share/icons", (Quickshell.env("HOME") ?? "") + "/.nix-profile/share/icons"' \
          --replace-quiet 'file:///usr/share/icons' 'file:///run/current-system/sw/share/icons'
      fi

      # =====================================================================
      # Patch /usr/share/sounds paths
      # =====================================================================
      if [ -f services/Audio.qml ]; then
        sed -i 's|/usr/share/sounds|/run/current-system/sw/share/sounds|g' services/Audio.qml
      fi

      # =====================================================================
      # Patch mpv-mpris path (used by YtMusic service)
      # =====================================================================
      if [ -f services/YtMusic.qml ]; then
        sed -i 's|/usr/lib/mpv-mpris/mpris.so|${mpv}/lib/mpv/mpris.so|g' services/YtMusic.qml
        sed -i 's|test -f .*/mpris.so|true|g' services/YtMusic.qml
      fi

      # =====================================================================
      # Patch polkit agent path in default niri configs
      # =====================================================================
      sed -i 's|/usr/lib/mate-polkit/polkit-mate-authentication-agent-1|polkit-mate-authentication-agent-1|g' \
        defaults/niri/config.kdl dots/.config/niri/config.kdl 2>/dev/null || true

      # =====================================================================
      # Fix scripts with complex venv-activating shebangs that
      # patchShebangs can't handle (#!/usr/bin/env -S /bin/sh -c "source ...")
      # =====================================================================
      for f in scripts/hyprland/get_keybinds.py scripts/colors/generate_colors_material.py; do
        if [ -f "$f" ]; then
          sed -i '1s|^#!.*|#!/usr/bin/env python3|' "$f"
        fi
      done

      # =====================================================================
      # Also strip /usr/bin/ from non-shebang lines in other file types
      # (e.g. .service files, plain text configs)
      # =====================================================================
      find . -type f -name "*.service" \
        -exec sed -i '/^#!/!s|/usr/bin/||g' {} + 2>/dev/null || true
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/inir $out/bin
      cp -r . $out/share/inir/

      # Symlink quickshell binary as inir-shell
      ln -s ${quickshell}/bin/qs $out/bin/inir-shell

      runHook postInstall
    '';

    preFixup = ''
      qtWrapperArgs+=(
        --prefix PATH : "${runtimePath}"
        --set QS_CONFIG_PATH "$out/share/inir"
      )
    '';

    meta = {
      description = "Desktop shell for Niri built on Quickshell";
      homepage = "https://github.com/snowarch/iNiR";
      license = lib.licenses.gpl3;
      platforms = lib.platforms.linux;
      mainProgram = "inir-shell";
    };
  }
