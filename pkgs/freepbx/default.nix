{ lib
, stdenv
, fetchFromGitHub
, php82
, php82Packages
, nodejs_20
, makeWrapper
, sox
, ffmpeg-full
, lame
, flac
, callPackage
, extraModules ? []
}:

let
  freepbxModules = callPackage ./modules.nix { inherit fetchFromGitHub; };
  vendorDir = callPackage ./composer-env.nix { inherit php82 php82Packages fetchFromGitHub; };
in
stdenv.mkDerivation rec {
  pname = "freepbx";
  version = "17.0.0";

  src = fetchFromGitHub {
    owner = "FreePBX";
    repo  = "framework";
    rev   = "release/17.0";
    # run: nix-prefetch-url --unpack https://github.com/FreePBX/framework/archive/release/17.0.tar.gz
    hash  = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [
    nodejs_20
    php82
    php82Packages.composer
    makeWrapper
  ];

  buildInputs = [
    php82
    sox
    ffmpeg-full
    lame
    flac
  ];

  patches = [
    ./patches/0001-fix-hardcoded-paths.patch
  ];

  configurePhase = ''
    runHook preConfigure

    # Remaining runtime path references that can't be patched at source level
    substituteInPlace install \
      --replace '/var/www/html'          "$out/share/freepbx/www" \
      --replace '/etc/freepbx.conf'      "$out/etc/freepbx.conf" \
      --replace '/etc/asterisk'          "$out/etc/asterisk" \
      --replace '/var/spool/asterisk'    "/var/spool/asterisk" \
      --replace '/var/log/asterisk'      "/var/log/asterisk"

    substituteInPlace amp_conf/htdocs/admin/bootstrap.php \
      --replace '/etc/freepbx.conf' "$out/etc/freepbx.conf"

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # Use pre-vendored composer dependencies (FOD)
    cp -r ${vendorDir} vendor
    chmod -R u+w vendor

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -d $out/share/freepbx/www
    install -d $out/share/freepbx/agi-bin
    install -d $out/share/freepbx/bin
    install -d $out/etc/freepbx
    install -d $out/bin

    cp -r amp_conf/htdocs/.  $out/share/freepbx/www/
    cp -r amp_conf/bin/.     $out/share/freepbx/bin/
    cp -r agi-bin/.          $out/share/freepbx/agi-bin/
    cp -r vendor/            $out/share/freepbx/www/vendor/

    # Install OSS modules into www
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
      cp -r ${src}/. $out/share/freepbx/www/admin/modules/${name}/
    '') freepbxModules)}

    # Extra user-supplied modules
    ${lib.concatMapStringsSep "\n" (mod: ''
      cp -r ${mod}/. $out/share/freepbx/www/admin/modules/$(basename ${mod})/
    '') extraModules}

    install -Dm755 amp_conf/bin/fwconsole $out/share/freepbx/bin/fwconsole

    makeWrapper ${php82}/bin/php $out/bin/fwconsole \
      --add-flags "$out/share/freepbx/bin/fwconsole" \
      --set AMPWEBROOT "$out/share/freepbx/www" \
      --set AMPSYTETC "$out/etc/freepbx" \
      --run 'cd /var/lib/freepbx 2>/dev/null || true'

    makeWrapper ${php82}/bin/php $out/bin/freepbx-php \
      --set AMPWEBROOT "$out/share/freepbx/www"

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

      FreePBX 17 is the first release targeting Debian Linux and PHP 8.2,
      with a rewritten dialplan using GoSub instead of the deprecated Macro
      application.
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
