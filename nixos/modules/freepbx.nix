{ config, pkgs, lib, ... }:

let
  cfg = config.services.freepbx;
  freepbxConf = pkgs.writeText "freepbx.conf" ''
    <?php
    $amp_conf['AMPDBHOST']     = '${cfg.database.host}';
    $amp_conf['AMPDBNAME']     = '${cfg.database.name}';
    $amp_conf['AMPDBUSER']     = '${cfg.database.user}';
    $amp_conf['AMPWEBROOT']    = '${cfg.webRoot}';
    $amp_conf['AMPSYSETC']     = '/etc/asterisk';
    $amp_conf['ASTETCDIR']     = '/etc/asterisk';
    $amp_conf['ASTSPOOLDIR']   = '${cfg.spoolDir}';
    $amp_conf['ASTLOGDIR']     = '${cfg.logDir}';
    $amp_conf['AMPBIN']        = '${cfg.package}/share/freepbx/bin';
    $amp_conf['AGIBIN']        = '${cfg.package}/share/freepbx/agi-bin';
    $amp_conf['AMPUSER']       = '${cfg.user}';
    $amp_conf['AMPGROUP']      = '${cfg.group}';
    ${cfg.extraConfig}
  '';
in
{
  options.services.freepbx = {
    enable = lib.mkEnableOption "FreePBX, the open-source Asterisk PBX web GUI";

    package = lib.mkPackageOption pkgs "freepbx" {
      default = [ "freepbx" ];
    };

    asteriskPackage = lib.mkPackageOption pkgs "asterisk" {
      default = [ "asterisk" ];
    };

    user = lib.mkOption {
      type    = lib.types.str;
      default = "asterisk";
      description = "System user that runs FreePBX and Asterisk.";
    };

    group = lib.mkOption {
      type    = lib.types.str;
      default = "asterisk";
      description = "System group for the FreePBX service user.";
    };

    webRoot = lib.mkOption {
      type    = lib.types.str;
      default = "/var/lib/freepbx/www";
      description = "Writable document root where FreePBX web files are deployed at runtime.";
    };

    logDir = lib.mkOption {
      type    = lib.types.str;
      default = "/var/log/asterisk";
      description = "Directory for Asterisk and FreePBX log files.";
    };

    spoolDir = lib.mkOption {
      type    = lib.types.str;
      default = "/var/spool/asterisk";
      description = "Asterisk spool directory (voicemail, recordings, etc.).";
    };

    database = {
      host = lib.mkOption {
        type    = lib.types.str;
        default = "localhost";
        description = "MariaDB/MySQL host.";
      };

      name = lib.mkOption {
        type    = lib.types.str;
        default = "asterisk";
        description = "Database name for FreePBX.";
      };

      user = lib.mkOption {
        type    = lib.types.str;
        default = "asterisk";
        description = "Database user for FreePBX.";
      };

      passwordFile = lib.mkOption {
        type    = lib.types.nullOr lib.types.path;
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
      type    = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/freepbx-admin-password";
      description = ''
        Path to a file containing the FreePBX web admin password. Set during
        first-boot initialization by the freepbx-init service.
      '';
    };

    openFirewall = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Open SIP and RTP ports in the NixOS firewall.";
    };

    sipPort = lib.mkOption {
      type    = lib.types.port;
      default = 5060;
      description = "SIP UDP/TCP signaling port.";
    };

    tlsSipPort = lib.mkOption {
      type    = lib.types.port;
      default = 5061;
      description = "SIP TLS signaling port.";
    };

    rtpPortRange = {
      from = lib.mkOption {
        type    = lib.types.port;
        default = 10000;
        description = "First port in the RTP media port range.";
      };
      to = lib.mkOption {
        type    = lib.types.port;
        default = 20000;
        description = "Last port in the RTP media port range.";
      };
    };

    extraConfig = lib.mkOption {
      type    = lib.types.lines;
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
        message   = "services.freepbx.rtpPortRange.from must be less than .to";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group        = cfg.group;
      home         = "/var/lib/freepbx";
      createHome   = false;
      description  = "FreePBX / Asterisk service user";
      extraGroups  = [ "audio" ];
    };

    users.groups.${cfg.group} = {};

    # MariaDB with FreePBX database
    services.mysql = {
      enable  = true;
      package = pkgs.mariadb;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions."${cfg.database.name}.*" = "ALL PRIVILEGES";
        }
      ];
    };

    # PHP-FPM pool for FreePBX
    services.phpfpm.pools.freepbx = {
      user  = cfg.user;
      group = cfg.group;
      phpPackage = pkgs.php82;
      settings = {
        "listen.owner"                 = config.services.httpd.user;
        "listen.group"                 = config.services.httpd.group;
        "pm"                           = "dynamic";
        "pm.max_children"              = 50;
        "pm.start_servers"             = 5;
        "pm.min_spare_servers"         = 5;
        "pm.max_spare_servers"         = 35;
        "php_value[session.save_path]" = "/var/lib/freepbx/sessions";
        "php_admin_value[error_log]"   = "${cfg.logDir}/php-fpm.log";
        "php_admin_flag[log_errors]"   = true;
        "env[FREEPBX_CONF]"            = "/etc/freepbx.conf";
      };
      phpOptions = ''
        extension = pdo_mysql
        extension = curl
        extension = gd
        extension = mbstring
        extension = openssl
        extension = xml
        extension = zip
        extension = bcmath
        extension = intl
        extension = gettext
        extension = sockets
      '';
    };

    # Apache HTTP server
    services.httpd = {
      enable      = true;
      user        = "wwwrun";
      group       = "wwwrun";
      enablePHP   = false;
      virtualHosts."freepbx" = {
        documentRoot = cfg.webRoot;
        extraConfig  = ''
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

    # freepbx-init: runs once on first boot (or after a package change) to
    # deploy writable web files and write /etc/freepbx.conf.
    systemd.services.freepbx-init = {
      description   = "FreePBX first-boot initialization";
      wantedBy      = [ "multi-user.target" ];
      after         = [ "mysql.service" "network.target" ];
      requires      = [ "mysql.service" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = "root";
        StateDirectory  = "freepbx freepbx/www freepbx/sessions freepbx/cache";
        LogsDirectory   = "asterisk";
      };
      script = ''
        set -euo pipefail

        # Deploy web root (copy store → writable state dir)
        if [ ! -f "${cfg.webRoot}/.deployed" ]; then
          echo "Deploying FreePBX web files..."
          cp -rT ${cfg.package}/share/freepbx/www ${cfg.webRoot}
          chmod -R u+w ${cfg.webRoot}
          chown -R ${cfg.user}:${cfg.group} ${cfg.webRoot}
          touch ${cfg.webRoot}/.deployed
        fi

        # Write /etc/freepbx.conf, injecting the DB password from file
        DB_PASS=""
        ${lib.optionalString (cfg.database.passwordFile != null) ''
          DB_PASS=$(cat ${cfg.database.passwordFile})
        ''}
        cat > /etc/freepbx.conf <<PHPEOF
        ${lib.fileContents freepbxConf}
        \$amp_conf['AMPDBPASS'] = '$DB_PASS';
        PHPEOF
        chmod 640 /etc/freepbx.conf
        chown root:${cfg.group} /etc/freepbx.conf

        # Spool and log dirs
        install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.spoolDir}
        install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.spoolDir}/voicemail
        install -d -o ${cfg.user} -g ${cfg.group} -m 0750 ${cfg.logDir}

        # Run FreePBX bootstrap
        ${cfg.package}/bin/fwconsole chown --quiet || true
        ${cfg.package}/bin/fwconsole reload --quiet || true

        # Set admin password if provided
        ${lib.optionalString (cfg.adminPasswordFile != null) ''
          ADMIN_PASS=$(cat ${cfg.adminPasswordFile})
          ${cfg.package}/bin/fwconsole userman --reset-admin-password "$ADMIN_PASS" || true
        ''}
      '';
    };

    # freepbx-cron: scheduled background tasks (every 5 min)
    systemd.services.freepbx-cron = {
      description   = "FreePBX scheduled tasks";
      after         = [ "freepbx-init.service" "mysql.service" ];
      requires      = [ "freepbx-init.service" "mysql.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
      };
      script = "${cfg.package}/bin/fwconsole job --quiet";
    };

    systemd.timers.freepbx-cron = {
      wantedBy    = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };

    # Asterisk systemd service (if not provided by a dedicated NixOS module)
    systemd.services.asterisk = {
      description = "Asterisk PBX";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" "mysql.service" ];
      serviceConfig = {
        Type            = "forking";
        User            = cfg.user;
        Group           = cfg.group;
        PIDFile         = "/run/asterisk/asterisk.pid";
        RuntimeDirectory = "asterisk";
        ExecStart       = "${cfg.asteriskPackage}/bin/asterisk -f -U ${cfg.user} -G ${cfg.group}";
        ExecReload      = "${cfg.asteriskPackage}/bin/asterisk -rx 'core reload'";
        ExecStop        = "${cfg.asteriskPackage}/bin/asterisk -rx 'core stop now'";
        Restart         = "on-failure";
      };
    };

    # Firewall
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts      = [ cfg.sipPort ];
      allowedTCPPorts      = [ cfg.sipPort cfg.tlsSipPort 80 443 ];
      allowedUDPPortRanges = [
        { from = cfg.rtpPortRange.from; to = cfg.rtpPortRange.to; }
      ];
    };

    environment.systemPackages = [ cfg.package ];
  };
}
