{ fetchFromGitHub }:

let
  mkModule = repo: rev: hash: fetchFromGitHub {
    owner = "FreePBX";
    inherit repo rev hash;
  };
  # All modules target release/17.0 branch.
  # Hashes are placeholders — fill in with:
  #   nix-prefetch-url --unpack https://github.com/FreePBX/<repo>/archive/release/17.0.tar.gz
  rev = "release/17.0";
in {
  core        = mkModule "core"        rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  admin       = mkModule "admin"       rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  voicemail   = mkModule "voicemail"   rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  cdr         = mkModule "cdr"         rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  conferences = mkModule "conferences" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  queues      = mkModule "queues"      rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  ringgroups  = mkModule "ringgroups"  rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  recordings  = mkModule "recordings"  rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  ivr         = mkModule "ivr"         rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  timeconditions = mkModule "timeconditions" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  featurecodeadmin = mkModule "featurecodeadmin" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  infoservices = mkModule "infoservices" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  logfiles    = mkModule "logfiles"    rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  music       = mkModule "music"       rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  parking     = mkModule "parking"     rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  paging      = mkModule "paging"      rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  setcid      = mkModule "setcid"      rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  speeddial   = mkModule "speeddial"   rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  announcement = mkModule "announcement" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  backup      = mkModule "backup"      rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  bulkhandler = mkModule "bulkhandler" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  calendar    = mkModule "calendar"    rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  callforward = mkModule "callforward" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  callwaiting = mkModule "callwaiting" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  daynight    = mkModule "daynight"    rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  donotdisturb = mkModule "donotdisturb" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  findmefollow = mkModule "findmefollow" rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  phonebook   = mkModule "phonebook"   rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  pm2         = mkModule "pm2"         rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  userman     = mkModule "userman"     rev "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
