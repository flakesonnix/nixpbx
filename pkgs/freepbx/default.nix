{ lib
, stdenv
, fetchFromGitHub
, php82
, makeWrapper
, sox
, ffmpeg-full
, lame
, flac
, extraModules ? []
}:

# FreePBX ships its PHP vendor/ tree pre-bundled in the source tarball at
# amp_conf/htdocs/admin/libraries/Composer/vendor/. No composer run needed.
let
  freepbxModules = import ./modules.nix { inherit fetchFromGitHub; };
in
stdenv.mkDerivation rec {
  pname = "freepbx";
  version = "17.0.0";

  src = fetchFromGitHub {
    owner = "FreePBX";
    repo  = "framework";
    rev   = "release/17.0";
    hash  = "sha256-wkD2hr2JV4tDTI1vhzOjUoBofsAO+H+BinoDuIFrWnc=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    php82
    sox
    ffmpeg-full
    lame
    flac
  ];

  dontBuild = true;

  configurePhase = ''
    runHook preConfigure

    # bootstrap.php probes a hardcoded list of freepbx.conf locations.
    # Prepend an env-var override so the NixOS module can point it at
    # /etc/freepbx.conf without patching every PHP file that reads config.
    substituteInPlace amp_conf/htdocs/admin/bootstrap.php \
      --replace-warn \
        "require_once('/etc/freepbx.conf');" \
        "require_once(getenv('FREEPBX_CONF') ?: '/etc/freepbx.conf');"

    # The Composer autoloader path baked into fwconsole points at the
    # source tree location; redirect it to where we install it.
    substituteInPlace amp_conf/bin/fwconsole \
      --replace-warn \
        "dirname(__FILE__).'/../htdocs/admin/libraries/Composer/vendor/autoload.php'" \
        "getenv('AMPWEBROOT').'/admin/libraries/Composer/vendor/autoload.php'"

    runHook postConfigure
  '';

  installPhase = ''
    runHook preInstall

    # Web root (pre-vendored; Composer vendor is already at htdocs/admin/libraries/Composer/vendor/)
    install -d $out/share/freepbx/www
    cp -r amp_conf/htdocs/. $out/share/freepbx/www/

    # AGI scripts
    install -d $out/share/freepbx/agi-bin
    cp -r amp_conf/agi-bin/. $out/share/freepbx/agi-bin/

    # Asterisk config templates
    install -d $out/share/freepbx/astetc
    cp -r amp_conf/astetc/. $out/share/freepbx/astetc/

    # Upgrade scripts
    install -d $out/share/freepbx/upgrades
    cp -r upgrades/. $out/share/freepbx/upgrades/

    # OSS modules
    install -d $out/share/freepbx/www/admin/modules
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
      cp -r ${src}/. $out/share/freepbx/www/admin/modules/${name}/
    '') freepbxModules)}

    # User-supplied extra modules
    ${lib.concatMapStringsSep "\n" (mod: ''
      cp -r ${mod}/. $out/share/freepbx/www/admin/modules/$(basename ${mod})/
    '') extraModules}

    # fwconsole wrapper — needs a writable CWD; use /var/lib/freepbx at runtime
    install -d $out/bin
    install -Dm755 amp_conf/bin/fwconsole $out/share/freepbx/bin/fwconsole
    makeWrapper ${php82}/bin/php $out/bin/fwconsole \
      --add-flags "$out/share/freepbx/bin/fwconsole" \
      --set AMPWEBROOT "$out/share/freepbx/www" \
      --run 'cd /var/lib/freepbx 2>/dev/null || true'

    runHook postInstall
  '';

  passthru = {
    inherit freepbxModules;
    updateScript = [ "nix-update" pname ];
  };

  meta = with lib; {
    description = "Web-based open-source GUI for managing Asterisk PBX";
    longDescription = ''
      FreePBX is an open-source, web-based graphical user interface that
      controls and manages Asterisk, the open-source PBX engine. It provides
      a modular architecture allowing administrators to configure extensions,
      trunks, routes, IVRs, voicemail, and dozens of other telephony features
      through a browser-based admin panel.

      FreePBX 17 is the first release targeting PHP 8.2, with a rewritten
      dialplan using GoSub instead of the deprecated Macro application.
    '';
    homepage     = "https://www.freepbx.org";
    downloadPage = "https://github.com/FreePBX";
    changelog    = "https://github.com/FreePBX/framework/releases";
    license      = with licenses; [ agpl3Only gpl3Only ];
    maintainers  = with maintainers; [];
    platforms    = platforms.linux;
    mainProgram  = "fwconsole";
  };
}
