{ channel, pname, version, sha256Hash }:

{ alsa-lib
, runtimeShell
, buildFHSEnv
, cacert
, coreutils
, dbus
, e2fsprogs
, expat
, fetchurl
, findutils
, file
, fontsConf
, git
, glxinfo
, gnugrep
, gnused
, gnutar
, gtk2, glib
, gtk3, cmake, ninja, pkg-config, clang, pango, gobject-introspection, harfbuzz, cairo, gdk-pixbuf, atk, pcre2, libffi
, xorgproto, xcbproto, xorgserver, libepoxy, bzip2, util-linux, brotli, libselinux, graphite2, libsepol
, fribidi, libthai, libdatrie, libXau, libXdmcp, libXft, pixman, libjpeg, libtiff, libwebp, zstd, xz
, libXinerama, wayland, egl-wayland, libglvnd, mesa, glibc
, lerc, libdeflate, xrandr
, gzip
, fontconfig
, freetype
, libbsd
, libpulseaudio
, libGL
, libdrm
, libpng
, libuuid
, libX11
, libxcb
, libxkbcommon
, xcbutilwm
, xcbutilrenderutil
, xcbutilkeysyms
, xcbutilimage
, xcbutilcursor
, libxkbfile
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXt
, libXtst
, makeWrapper
, ncurses5
, nspr
, nss_latest
, pciutils
, pkgsi686Linux
, ps
, setxkbmap
, lib
, stdenv
, systemd
, unzip
, usbutils
, which
, runCommand
, xkeyboard_config
, xorg
, zlib
, makeDesktopItem
, tiling_wm # if we are using a tiling wm, need to set _JAVA_AWT_WM_NONREPARENTING in wrapper
, androidenv
}:

let
  drvName = "android-studio-${channel}-${version}";
  filename = "android-studio-${version}-linux.tar.gz";

  androidStudio = stdenv.mkDerivation {
    name = "${drvName}-unwrapped";

    src = fetchurl {
      url = "https://dl.google.com/dl/android/studio/ide-zips/${version}/${filename}";
      sha256 = sha256Hash;
    };

    nativeBuildInputs = [
      unzip
      makeWrapper
    ];

    # Causes the shebangs in interpreter scripts deployed to mobile devices to be patched, which Android does not understand
    dontPatchShebangs = true;

    installPhase = ''
      cp -r . $out
      # wrapProgram $out/bin/studio.sh \
      #   --set-default JAVA_HOME "$out/jbr" \
      #   --set ANDROID_EMULATOR_USE_SYSTEM_LIBS 1 \
      #   --set PKG_CONFIG_PATH /usr/share/pkgconfig:/usr/lib/pkgconfig \
      #   --set QT_XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
      #   ${lib.optionalString tiling_wm "--set _JAVA_AWT_WM_NONREPARENTING 1"} \
      #   --set FONTCONFIG_FILE ${fontsConf}
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    exec = pname;
    icon = pname;
    desktopName = "Android Studio (${channel} channel)";
    comment = "The official Android IDE";
    categories = [ "Development" "IDE" ];
    startupNotify = true;
    startupWMClass = "jetbrains-studio";
  };

  # Android Studio downloads prebuilt binaries as part of the SDK. These tools
  # (e.g. `mksdcard`) have `/lib/ld-linux.so.2` set as the interpreter. An FHS
  # environment is used as a work around for that.
  fhsEnv = buildFHSEnv {
    name = "${drvName}-fhs-env";
    targetPkgs = pkgs: [
      atk.dev
      brotli.dev
      bzip2.dev
      cairo.dev
      clang
      cmake
      dbus.dev
      egl-wayland.dev
      expat.dev
      fontconfig.dev
      freetype.dev
      fribidi.dev
      gdk-pixbuf.dev
      glib.dev
      glibc.dev
      gobject-introspection.dev
      graphite2.dev
      gtk3.dev
      harfbuzz.dev
      lerc.dev
      libGL.dev
      libX11.dev
      libXau.dev
      libXcomposite.dev
      libXcursor.dev
      libXdamage.dev
      libXdmcp.dev
      libXext.dev
      libXfixes.dev
      libXft.dev
      libXi.dev
      libXinerama.dev
      libXrandr.dev
      libXrender.dev
      libXt.dev
      libXtst
      libdatrie.dev
      libdeflate
      libepoxy.dev
      libffi.dev
      libglvnd.dev
      libjpeg.dev
      libpng.dev
      libselinux.dev
      libsepol.dev
      libthai.dev
      libtiff.dev
      libwebp
      libxcb.dev
      libxkbcommon.dev
      mesa.dev
      ninja
      ncurses5
      pango.dev
      pcre2.dev
      pkgconfig
      pixman
      util-linux.dev
      wayland.dev
      xcbproto
      xorgproto
      xorgserver.dev
      xrandr
      xz.dev
      zlib.dev
      zstd.dev

      # Flutter can only search for certs Fedora-way.
      (runCommand "fedoracert" {}
        ''
        mkdir -p $out/etc/pki/tls/
        ln -s ${cacert}/etc/ssl/certs $out/etc/pki/tls/certs
        '')
    ];
  };
  mkAndroidStudioWrapper = {androidStudio, androidSdk ? null}: runCommand drvName {
    startScript = let
      hasAndroidSdk = androidSdk != null;
      androidSdkRoot = lib.optionalString hasAndroidSdk "${androidSdk}/libexec/android-sdk";
    in ''
      #!${runtimeShell}
      ${lib.optionalString hasAndroidSdk ''
        echo "=== nixpkgs Android Studio wrapper" >&2

        # Default ANDROID_SDK_ROOT to the packaged one, if not provided.
        ANDROID_SDK_ROOT="''${ANDROID_SDK_ROOT-${androidSdkRoot}}"

        if [ -d "$ANDROID_SDK_ROOT" ]; then
          export ANDROID_SDK_ROOT
          # Legacy compatibility.
          export ANDROID_HOME="$ANDROID_SDK_ROOT"
          echo "  - ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >&2

          # See if we can export ANDROID_NDK_ROOT too.
          ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk-bundle"
          if [ ! -d "$ANDROID_NDK_ROOT" ]; then
            ANDROID_NDK_ROOT="$(ls "$ANDROID_SDK_ROOT/ndk/"* 2>/dev/null | head -n1)"
          fi

          if [ -d "$ANDROID_NDK_ROOT" ]; then
            export ANDROID_NDK_ROOT
            echo "  - ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT" >&2
          else
            unset ANDROID_NDK_ROOT
          fi
        else
          unset ANDROID_SDK_ROOT
          unset ANDROID_HOME
        fi
      ''}
      exec ${fhsEnv}/bin/${drvName}-fhs-env ${androidStudio}/bin/studio.sh "$@"
    '';
    preferLocalBuild = true;
    allowSubstitutes = false;
    passthru = let
      withSdk = androidSdk: mkAndroidStudioWrapper { inherit androidStudio androidSdk; };
    in {
      inherit version;
      unwrapped = androidStudio;
      full = withSdk androidenv.androidPkgs.androidsdk;
      inherit withSdk;
      sdk = androidSdk;
      updateScript = [ ./update.sh "${channel}" ];
    };
    meta = {
      description = "Official IDE for Android (${channel} channel)";
      longDescription = ''
        Android Studio is the official IDE for Android app development, based on
        IntelliJ IDEA.
      '';
      homepage = if channel == "stable"
        then "https://developer.android.com/studio/index.html"
        else "https://developer.android.com/studio/preview/index.html";
      license = with lib.licenses; [ asl20 unfree ]; # The code is under Apache-2.0, but:
      # If one selects Help -> Licenses in Android Studio, the dialog shows the following:
      # "Android Studio includes proprietary code subject to separate license,
      # including JetBrains CLion(R) (www.jetbrains.com/clion) and IntelliJ(R)
      # IDEA Community Edition (www.jetbrains.com/idea)."
      # Also: For actual development the Android SDK is required and the Google
      # binaries are also distributed as proprietary software (unlike the
      # source-code itself).
      platforms = [ "x86_64-linux" ];
      maintainers = with lib.maintainers; rec {
        stable = [ alapshin johnrtitor numinit ];
        beta = stable;
        canary = stable;
        dev = stable;
      }."${channel}";
      mainProgram = pname;
    };
  }
  ''
    mkdir -p $out/{bin,share/pixmaps}

    echo -n "$startScript" > $out/bin/${pname}
    chmod +x $out/bin/${pname}

    ln -s ${androidStudio}/bin/studio.png $out/share/pixmaps/${pname}.png
    ln -s ${desktopItem}/share/applications $out/share/applications
  '';
in mkAndroidStudioWrapper { inherit androidStudio; }
