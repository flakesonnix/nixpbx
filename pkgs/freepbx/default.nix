{ lib
, stdenv
, fetchFromGitHub
, php82
, makeWrapper
, sox
, ffmpeg-full
, lame
, flac
, extraModules ? [ ]
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
    repo = "framework";
    rev = "release/17.0";
    hash = "sha256-d6oTM8D8ceOqMNkanJytBKrpMwYRryJaHDZCi0hRH8Y=";
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

        # bootstrap_include_hooks crashes during first boot (Modulelist unavailable).
        # Wrap in a silent try-catch — hooks are non-critical for CLI operations.
        substituteInPlace amp_conf/htdocs/admin/bootstrap.php \
          --replace-warn \
            "bootstrap_include_hooks('pre_module_load', 'all_mods');" \
            "try { bootstrap_include_hooks('pre_module_load', 'all_mods'); } catch(\Throwable \$e) {}"

        # Cache->init() line 247 tries $this->freepbx->Notifications->add_error()
        # which triggers a circular autoload chain on first boot. Protect the call.
        substituteInPlace amp_conf/htdocs/admin/libraries/BMO/Cache.class.php \
          --replace-warn \
            '$this->freepbx->Notifications->add_error('"'"'framework'"'"', '"'"'CACHEPATCH'"'"', _('"'"'Cache path is not writable!'"'"'), sprintf(_("The cache path of %s is not writable, caching is not enabled as a result the system might be slower. Please fix this by running '"'"'fwconsole chown'"'"' from the CLI."),$cachePath), "", true, true);' \
            'try { $this->freepbx->Notifications->add_error('"'"'framework'"'"', '"'"'CACHEPATCH'"'"', _('"'"'Cache path is not writable!'"'"'), sprintf(_("The cache path of %s is not writable, caching is not enabled as a result the system might be slower. Please fix this by running '"'"'fwconsole chown'"'"' from the CLI."),$cachePath), "", true, true); } catch(\Exception $e) {}'

        # Modulelist->get() calls Cache->contains() which triggers a circular
        # dependency chain on first boot. Replace the method body to short-circuit
        # when no modules are cached yet.
        substituteInPlace amp_conf/htdocs/admin/libraries/BMO/Modulelist.class.php \
          --replace-warn \
            'public function get() {
    		if(!empty($this->modules)) {
    			return $this->modules;
    		}
    		if ($this->FreePBX->Cache->contains('"'"'modulelist_modules'"'"')) {
    			$this->modules = $this->FreePBX->Cache->fetch('"'"'modulelist_modules'"'"');
    			return $this->modules;
    		}
    		return array();
    	}' \
            'public function get() {
    		return $this->modules;
    	}'

        # fwconsole:75 needs Modulelist and Modules. Wrap in try-catch since they
        # may not be registered in a fresh DB.
        substituteInPlace amp_conf/bin/fwconsole \
          --replace-warn \
            '$list = FreePBX::Modulelist()->get();' \
            'try { $list = FreePBX::Modulelist()->get(); } catch(\Exception $e) { $list = array(); }'
        substituteInPlace amp_conf/bin/fwconsole \
          --replace-warn \
            '$amodules = FreePBX::Modules()->getActiveModules();' \
            'try { $amodules = FreePBX::Modules()->getActiveModules(); } catch(\Exception $e) { $amodules = array(); }'
        substituteInPlace amp_conf/bin/fwconsole \
          --replace-warn \
            '$brand = \FreePBX::Config()->get('"'"'DASHBOARD_FREEPBX_BRAND'"'"');' \
            'try { $brand = \FreePBX::Config()->get('"'"'DASHBOARD_FREEPBX_BRAND'"'"'); } catch(\Exception $e) { $brand = '"'"'FreePBX'"'"'; }'
        # Register job command as a default (normally provided by framework module
        # module.xml which is not installed in a fresh DB).
        substituteInPlace amp_conf/bin/fwconsole \
          --replace-warn \
            "'chown' => function () { return new \\FreePBX\\Console\\Command\\Chown; }" \
            "'chown' => function () { return new \\FreePBX\\Console\\Command\\Chown; },
            'job' => function () { return new \\FreePBX\\Console\\Command\\Job; },
            'reload' => function () { return new \\FreePBX\\Console\\Command\\Reload; },
            'restart' => function () { return new \\FreePBX\\Console\\Command\\Restart; },
            'start' => function () { return new \\FreePBX\\Console\\Command\\Start; },
            'stop' => function () { return new \\FreePBX\\Console\\Command\\Stop; }"

        # GPG.class.php only checks hardcoded paths — add a PATH fallback for NixOS.
        substituteInPlace amp_conf/htdocs/admin/libraries/BMO/GPG.class.php \
          --replace-warn \
            "if (!\$this->gpg) {" \
            "\$which = trim(shell_exec('command -v gpg 2>/dev/null') ?: '''); if (\$which) { \$this->gpg = \$which; } if (!\$this->gpg) {"

        # fwconsole does not load the Composer autoloader by itself in FreePBX 17.
        # bootstrap.php loads it, but fwconsole includes freepbx.conf directly
        # instead of going through bootstrap.php. Inject a placeholder that we
        # fill with the store path during installPhase.
        sed -i '3a require_once "__FREEPBX_AUTOLOADER__";' amp_conf/bin/fwconsole
        # Also make the config file path use FREEPBX_CONF env var so the NixOS
        # module can control the location.
        substituteInPlace amp_conf/bin/fwconsole \
          --replace-warn \
            "include_once '/etc/freepbx.conf';" \
            "include_once getenv('FREEPBX_CONF') ?: '/etc/freepbx.conf';"

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
    substituteInPlace $out/share/freepbx/bin/fwconsole \
      --replace "__FREEPBX_AUTOLOADER__" \
        "$out/share/freepbx/www/admin/libraries/Composer/vendor/autoload.php"
    makeWrapper ${php82}/bin/php $out/bin/fwconsole \
      --add-flags "$out/share/freepbx/bin/fwconsole" \
      --set AMPWEBROOT "$out/share/freepbx/www" \
      --set FREEPBX_CONF "/etc/freepbx.conf" \
      --run 'cd /var/lib/freepbx 2>/dev/null || true'

    runHook postInstall
  '';

  passthru = {
    inherit freepbxModules;
    # nixpkgs updateScript convention: runnable via
    # maintainers/scripts/update.nix-style runners, or directly:
    #   nix run .#update
    updateScript = [ ./update.sh ];
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
    homepage = "https://www.freepbx.org";
    downloadPage = "https://github.com/FreePBX";
    changelog = "https://github.com/FreePBX/framework/releases";
    license = with licenses; [ agpl3Only gpl3Only ];
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "fwconsole";
  };
}
