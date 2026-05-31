{ config, pkgs, lib, ... }:

let
  cfg = config.services.freepbx;
in
{
  options.services.freepbx = {
    enable = lib.mkEnableOption "FreePBX, the open-source Asterisk PBX web GUI";

    package = lib.mkOption {
      type = lib.types.package;
      description = "FreePBX package to use. Must be set when using this module outside of the nixpbx flake.";
    };

    asteriskPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.asterisk.overrideAttrs (o: {
        postInstall = (o.postInstall or "") + ''
          make -j$NIX_BUILD_CORES install-docs || true
        '';
      });
      defaultText = lib.literalMD "`pkgs.asterisk` with `make install-docs` added to postInstall (Asterisk 22's stasis module needs XML documentation at runtime)";
      description = "Asterisk PBX package. The default includes documentation needed by `stasis` at runtime.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "asterisk";
      description = "System user that runs FreePBX and Asterisk.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "asterisk";
      description = "System group for the FreePBX service user.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/freepbx";
      description = ''
        Root directory for all writable FreePBX runtime state. Subdirectories
        (www/, sessions/, cache/) are created automatically. Changing this
        also shifts the defaults for webRoot and related paths.
      '';
    };

    webRoot = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/www";
      defaultText = lib.literalExpression ''"''${config.services.freepbx.dataDir}/www"'';
      description = "Writable document root where FreePBX web files are deployed at runtime.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/asterisk";
      description = "Directory for Asterisk and FreePBX log files.";
    };

    spoolDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/spool/asterisk";
      description = "Asterisk spool directory (voicemail, recordings, etc.).";
    };

    database = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "MariaDB/MySQL host.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "asterisk";
        description = "Database name for FreePBX.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "asterisk";
        description = "Database user for FreePBX.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/freepbx-db-password";
        description = ''
          Path to a file containing the database password. The file must be
          readable by the FreePBX service user. Never set the password inline
          in your NixOS configuration.
        '';
      };
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/freepbx-admin-password";
      description = ''
        Path to a file containing the FreePBX web admin password. Set during
        first-boot initialization by the freepbx-init service.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open SIP and RTP ports in the NixOS firewall.";
    };

    sipPort = lib.mkOption {
      type = lib.types.port;
      default = 5060;
      description = "SIP UDP/TCP signaling port.";
    };

    tlsSipPort = lib.mkOption {
      type = lib.types.port;
      default = 5061;
      description = "SIP TLS signaling port.";
    };

    rtpPortRange = {
      from = lib.mkOption {
        type = lib.types.port;
        default = 10000;
        description = "First port in the RTP media port range.";
      };
      to = lib.mkOption {
        type = lib.types.port;
        default = 20000;
        description = "Last port in the RTP media port range.";
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        $amp_conf['AMPDISABLELOG'] = 'false';
      '';
      description = "Extra PHP lines appended verbatim to freepbx.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.rtpPortRange.from < cfg.rtpPortRange.to;
        message = "services.freepbx.rtpPortRange.from must be less than .to";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = false;
      description = "FreePBX / Asterisk service user";
      extraGroups = [ "audio" ];
    };

    users.groups.${cfg.group} = { };

    services = {
      # MariaDB (via services.mysql which can run either MySQL or MariaDB).
      # The DB user is created with password auth in freepbx-init (not via
      # ensureUsers, which creates unix_socket-only users on MariaDB).
      mysql = {
        enable = true;
        package = pkgs.mariadb;
        ensureDatabases = [ cfg.database.name ];
      };

      # PHP-FPM pool for FreePBX
      phpfpm.pools.freepbx = {
        inherit (cfg) user group;
        phpPackage = pkgs.php82.withExtensions ({ enabled, all }: enabled ++ (with all; [
          pdo_mysql
          curl
          gd
          mbstring
          openssl
          xml
          zip
          bcmath
          intl
          gettext
          sockets
        ]));
        settings = {
          "listen.owner" = config.services.httpd.user;
          "listen.group" = config.services.httpd.group;
          "pm" = "dynamic";
          "pm.max_children" = 50;
          "pm.start_servers" = 5;
          "pm.min_spare_servers" = 5;
          "pm.max_spare_servers" = 35;
          "php_value[session.save_path]" = "${cfg.dataDir}/sessions";
          "php_admin_value[error_log]" = "${cfg.logDir}/php-fpm.log";
          "php_admin_flag[log_errors]" = true;
          "env[FREEPBX_CONF]" = "/etc/freepbx.conf";
        };
        # Extensions are compiled statically by withExtensions above.
        # The extension = directives are NOT needed — they cause warnings
        # because PHP's extension_dir points at the base (unwrapped) php
        # which has no .so files. The modules are already in the binary.
        phpOptions = "";
      };

      # Apache HTTP server — web root deployed by freepbx-init
      httpd = {
        enable = true;
        user = "wwwrun";
        group = "wwwrun";
        enablePHP = false;
        virtualHosts."freepbx" = {
          documentRoot = cfg.webRoot;
          extraConfig = ''
            <Directory "${cfg.webRoot}">
              AllowOverride All
              Options -Indexes +FollowSymLinks
              Require all granted
            </Directory>

            <FilesMatch \.php$>
              SetHandler "proxy:unix:${config.services.phpfpm.pools.freepbx.socket}|fcgi://localhost"
            </FilesMatch>
          '';
        };
      };


    };

    systemd = {
      services = {
        # freepbx-init: deploys files, sets up DB user, installs modules.
        # Runs once on first boot (or when package changes).
        freepbx-init = {
          description = "FreePBX first-boot initialization";
          wantedBy = [ "multi-user.target" ];
          before = [ "httpd.service" "phpfpm-freepbx.service" ];
          after = [ "mysql.service" "network.target" ];
          requires = [ "mysql.service" ];
          path = [ config.services.mysql.package pkgs.gnupg ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
            StateDirectory = "freepbx freepbx/www freepbx/sessions freepbx/cache";
            LogsDirectory = "asterisk";
          };
          script = ''
            set -euo pipefail

            # Write /etc/freepbx.conf. DB password read from file at runtime
            # (never appears in Nix store).
            DB_PASS=""
            ${lib.optionalString (cfg.database.passwordFile != null) ''
              DB_PASS=$(cat ${lib.escapeShellArg cfg.database.passwordFile})
            ''}
            cat > /etc/freepbx.conf <<PHPEOF
            <?php
            \$amp_conf['AMPDBHOST']  = '${cfg.database.host}';
            \$amp_conf['AMPDBNAME']  = '${cfg.database.name}';
            \$amp_conf['AMPDBUSER']  = '${cfg.database.user}';
            \$amp_conf['AMPDBPASS']  = '$DB_PASS';
            \$amp_conf['AMPWEBROOT'] = '${cfg.webRoot}';
            \$amp_conf['AMPSYSETC']  = '/etc/asterisk';
            \$amp_conf['ASTETCDIR']  = '/etc/asterisk';
            \$amp_conf['ASTSPOOLDIR']= '${cfg.spoolDir}';
            \$amp_conf['ASTLOGDIR']  = '${cfg.logDir}';
            \$amp_conf['AMPBIN']     = '${cfg.package}/share/freepbx/bin';
            \$amp_conf['AGIBIN']     = '${cfg.package}/share/freepbx/agi-bin';
            \$amp_conf['FWCONSOLE']  = '${lib.getExe cfg.package}';
            \$amp_conf['AMPUSER']    = '${cfg.user}';
            \$amp_conf['AMPGROUP']   = '${cfg.group}';
            ${cfg.extraConfig}
            \$bootstrap_settings['skip_astman'] = true;
            require_once '${cfg.webRoot}/admin/bootstrap.php';
            PHPEOF
            chmod 640 /etc/freepbx.conf
            chown root:${cfg.group} /etc/freepbx.conf

            # Deploy web root (copy store → writable state dir)
            if [ ! -f "${cfg.webRoot}/.deployed" ]; then
              echo "Deploying FreePBX web files..."
              mkdir -p ${cfg.webRoot}
              cp -rT ${cfg.package}/share/freepbx/www ${cfg.webRoot}
              chmod -R u+w ${cfg.webRoot}
              chown -R ${cfg.user}:${cfg.group} ${cfg.webRoot}
              touch ${cfg.webRoot}/.deployed
            fi

            # Spool and log dirs
            install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.spoolDir}
            install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.spoolDir}/voicemail
            install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.spoolDir}/cache
            install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.logDir}

            # Deploy Asterisk var skeleton (docs, scripts, keys, etc.) to
            # /var/lib/asterisk. The runtime-vardirs.patch in nixpkgs makes
            # Asterisk look here at runtime instead of the Nix store path.
            if [ ! -d /var/lib/asterisk/documentation ]; then
              mkdir -p /var/lib/asterisk
              cp -rT ${cfg.asteriskPackage}/var/lib/asterisk /var/lib/asterisk
              chown -R ${cfg.user}:${cfg.group} /var/lib/asterisk
            fi

            # Set up DB user with password auth (ensureUsers uses unix_socket
            # on MariaDB, which FreePBX cannot use over TCP).
            if [ -n "$DB_PASS" ]; then
              mysql -u root -e "
                CREATE USER IF NOT EXISTS '${cfg.database.user}'@'localhost';
                ALTER USER '${cfg.database.user}'@'localhost' IDENTIFIED BY '$DB_PASS';
                GRANT ALL PRIVILEGES ON \`${cfg.database.name}\`.* TO '${cfg.database.user}'@'localhost';
                FLUSH PRIVILEGES;
              "
            fi

            # Bootstrap FreePBX schema. Core tables must exist before any
            # fwconsole command runs (Config reads freepbx_settings,
            # module_functions queries modules).
            mysql -u root "${cfg.database.name}" -e "
              CREATE TABLE IF NOT EXISTS \`freepbx_settings\` (
                \`keyword\` varchar(50) default NULL,
                \`value\` varchar(255) default NULL,
                \`name\` varchar(80) default NULL,
                \`level\` tinyint(1) default 0,
                \`description\` text default NULL,
                \`type\` varchar(25) default NULL,
                \`options\` text default NULL,
                \`defaultval\` varchar(255) default NULL,
                \`readonly\` tinyint(1) default 0,
                \`hidden\` tinyint(1) default 0,
                \`category\` varchar(50) default NULL,
                \`module\` varchar(25) default NULL,
                \`emptyok\` tinyint(1) default 1,
                \`sortorder\` int(11) default 0,
                PRIMARY KEY (\`keyword\`)
              ) ENGINE=MyISAM DEFAULT CHARSET=latin1;
              CREATE TABLE IF NOT EXISTS \`modules\` (
                \`id\` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                \`modulename\` VARCHAR(50) NOT NULL,
                \`version\` VARCHAR(20) NOT NULL,
                \`enabled\` TINYINT NOT NULL
              ) ENGINE=MyISAM;
              CREATE TABLE IF NOT EXISTS \`featurecodes\` (
                \`modulename\` varchar(50) NOT NULL,
                \`featurename\` varchar(50) NOT NULL,
                \`description\` varchar(200) NOT NULL,
                \`defaultcode\` varchar(20) default NULL,
                \`customcode\` varchar(20) default NULL,
                \`enabled\` tinyint(4) NOT NULL default '0',
                PRIMARY KEY (\`modulename\`,\`featurename\`),
                KEY \`enabled\` (\`enabled\`)
              ) ENGINE=MyISAM;
              CREATE TABLE IF NOT EXISTS \`notifications\` (
                \`module\` varchar(24) NOT NULL default ''',
                \`id\` varchar(24) NOT NULL default ''',
                \`level\` int(11) NOT NULL default '0',
                \`display_text\` varchar(255) NOT NULL default ''',
                \`extended_text\` blob NOT NULL,
                \`link\` varchar(255) NOT NULL default ''',
                \`reset\` tinyint(4) NOT NULL default '0',
                \`candelete\` tinyint(4) NOT NULL default '0',
                \`timestamp\` int(11) NOT NULL default '0',
                PRIMARY KEY (\`module\`,\`id\`)
              ) ENGINE=MyISAM;
              CREATE TABLE IF NOT EXISTS \`cronmanager\` (
                \`module\` varchar(24) NOT NULL default ''',
                \`id\` varchar(24) NOT NULL default ''',
                \`time\` varchar(5) default NULL,
                \`freq\` int(11) NOT NULL default '0',
                \`lasttime\` int(11) NOT NULL default '0',
                \`command\` varchar(255) NOT NULL default ''',
                PRIMARY KEY (\`module\`,\`id\`)
              ) ENGINE=MyISAM;
              CREATE TABLE IF NOT EXISTS \`module_xml\` (
                \`id\` varchar(20) NOT NULL default 'xml',
                \`time\` int(11) NOT NULL default '0',
                \`data\` blob NOT NULL,
                PRIMARY KEY (\`id\`)
              ) ENGINE=MyISAM;
              CREATE TABLE IF NOT EXISTS \`admin\` (
                \`variable\` varchar(100) NOT NULL default ''',
                \`value\` varchar(255) NOT NULL default ''',
                PRIMARY KEY (\`variable\`)
              ) ENGINE=MyISAM;
              INSERT IGNORE INTO \`admin\` (\`variable\`, \`value\`) VALUES ('version', '${cfg.package.version}')
            "
            # Seed essential config that bootstrap/php-asmanager.php needs.
            # These are normally set by the installer or amportal.conf, but
            # bootstrap's parse_amportal_conf() filters $amp_conf to only DB
            # keys, so ASTETCDIR/ASTSPOOLDIR must survive in freepbx_settings.
            mysql -u root "${cfg.database.name}" -e "
              INSERT IGNORE INTO \`freepbx_settings\` (\`keyword\`, \`value\`, \`name\`, \`level\`, \`type\`, \`defaultval\`, \`readonly\`, \`hidden\`, \`category\`, \`module\`, \`emptyok\`, \`sortorder\`)
              VALUES
                ('ASTETCDIR', '/etc/asterisk', 'Asterisk Config Dir', 0, 'dir', '/etc/asterisk', 1, 0, 'Asterisk Settings', 'framework', 0, 0),
                ('ASTSPOOLDIR', '${cfg.spoolDir}', 'Asterisk Spool Dir', 0, 'dir', '${cfg.spoolDir}', 1, 0, 'Asterisk Settings', 'framework', 0, 0),
                ('AMPWEBROOT', '${cfg.webRoot}', 'Asterisk Web Root', 0, 'dir', '${cfg.webRoot}', 1, 0, 'Asterisk Settings', 'framework', 0, 0)
            "

            # GPG.class.php only checks /usr/local/bin/ and /usr/bin/ for gpg
            # (not PATH), so symlink it there for module signature verification.
            mkdir -p /usr/local/bin
            ln -sf ${pkgs.gnupg}/bin/gpg /usr/local/bin/gpg

            # Install core + framework modules (creates remaining schema).
            # The module installers handle module-specific tables (trunks,
            # devices, users, etc.) and populate freepbx_settings defaults.
            ${lib.getExe cfg.package} ma install core --quiet || true
            ${lib.getExe cfg.package} ma install framework --quiet || true

            # Fix ownership
            ${lib.getExe cfg.package} chown --quiet || true

            # Set admin password if provided
            ${lib.optionalString (cfg.adminPasswordFile != null) ''
              ADMIN_PASS=$(cat ${cfg.adminPasswordFile})
              ${lib.getExe cfg.package} userman --reset-admin-password "$ADMIN_PASS" || true
            ''}
          '';
        };

        # freepbx-reload: (re)generate Asterisk config from FreePBX DB.
        # Runs after any service start; safe to call repeatedly.
        freepbx-reload = {
          description = "FreePBX config reload (Asterisk config generation)";
          after = [ "freepbx-init.service" "asterisk.service" ];
          requires = [ "freepbx-init.service" ];
          wantedBy = [ "asterisk.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = cfg.user;
            Group = cfg.group;
          };
          script = ''
            ${lib.getExe cfg.package} reload --quiet || true
          '';
        };

        # freepbx-cron: scheduled background tasks (every 5 min)
        freepbx-cron = {
          description = "FreePBX scheduled tasks";
          after = [ "freepbx-init.service" "mysql.service" ];
          requires = [ "freepbx-init.service" "mysql.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
          };
          script = "${lib.getExe cfg.package} job --quiet";
        };

        # Asterisk systemd service
        asterisk = {
          description = "Asterisk PBX";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" "freepbx-init.service" ];
          requires = [ "freepbx-init.service" ];
          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            RuntimeDirectory = "asterisk";
            StateDirectory = "asterisk";
            ExecStart = "${lib.getExe cfg.asteriskPackage} -f -U ${cfg.user} -G ${cfg.group}";
            ExecReload = "${lib.getExe cfg.asteriskPackage} -rx 'core reload'";
            ExecStop = "${lib.getExe cfg.asteriskPackage} -rx 'core stop now'";
            Restart = "on-failure";
          };
        };

        # httpd must wait for freepbx-init to deploy the web root
        httpd = {
          after = [ "freepbx-init.service" ];
        };
      };

      timers.freepbx-cron = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/5";
          Persistent = true;
        };
      };
    };

    # Firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ cfg.sipPort ];
      allowedTCPPorts = [ cfg.sipPort cfg.tlsSipPort 80 443 ];
      allowedUDPPortRanges = [
        { from = cfg.rtpPortRange.from; to = cfg.rtpPortRange.to; }
      ];
    };

    environment.systemPackages = [ cfg.package ];
  };
}
