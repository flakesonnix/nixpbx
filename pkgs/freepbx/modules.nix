{ fetchFromGitHub }:

# FreePBX open-source modules — each lives in its own GitHub repo under the
# FreePBX org. The admin UI itself is bundled in the framework; only separate
# module repos are listed here.
#
# Hashes fetched from release/17.0 branch on 2026-05-27.
# Update with: nix-prefetch-url --unpack https://github.com/FreePBX/<repo>/archive/refs/heads/release/17.0.tar.gz
let
  mkModule = repo: hash: fetchFromGitHub {
    owner = "FreePBX";
    rev = "release/17.0";
    inherit repo hash;
  };
in
{
  core = mkModule "core" "sha256-5gcjbd87rvhUu5R9VnrZM/DYzrIJUbqNozlbBOhTMQo=";
  voicemail = mkModule "voicemail" "sha256-kvHqx5qAKgJ0dJyBagelqc+kHVxPgKAM2TXz//2sFmI=";
  cdr = mkModule "cdr" "sha256-uHL/N8rnRzFUcPkNBZvAgwWpAZMxkqr+MNmvt9IGipw=";
  conferences = mkModule "conferences" "sha256-+kcPpvQ0pF15gjVo5Vdi6eD5w66z+yI+/odx44x4+Xk=";
  queues = mkModule "queues" "sha256-SY9nPCrUWPNutkVVfjHVBZkT+wi8K72iJlQmWIysReY=";
  ringgroups = mkModule "ringgroups" "sha256-mZvliXOiDpMwyWCU5NNqEpAOLp8qhwnoOvr18sgdQZg=";
  recordings = mkModule "recordings" "sha256-PdLEQJt2xnYShiIKXlJ6OjodT9vK+EGlB4YmN8YyHv8=";
  ivr = mkModule "ivr" "sha256-ksDnSiecSNrvEF0+eBrVnKJ0poGvHaCJHWZrXh2X//8=";
  timeconditions = mkModule "timeconditions" "sha256-HxGPSLdiuG2hgCUu8+GkGs4SV3wZq+gneaZVBbRNRxA=";
  featurecodeadmin = mkModule "featurecodeadmin" "sha256-0Mpmx9GwlOhq23n82wgN9Ul6k1IMSi8HyxAOavebK9k=";
  infoservices = mkModule "infoservices" "sha256-aNN5XeOlQegsCOWHnZ75RNb5+1jLJy57SzdPUHrQEdE=";
  logfiles = mkModule "logfiles" "sha256-ls8x5zjUHM35SGykTqi6LOtLd8+aOwb1BqUPPgDFNDY=";
  music = mkModule "music" "sha256-GXkqxh4JLEfgY5py39D8Lx0IQytmxyVmWNgELOcGnR8=";
  parking = mkModule "parking" "sha256-r/6j3QqkoMjUGTtob8TYbPsQqemNbm29rmKPTx+ADHE=";
  paging = mkModule "paging" "sha256-9LindjggiO4Jpr5l9oxu5deS2GgPPz0FY070bycqLCs=";
  setcid = mkModule "setcid" "sha256-sZnpx/woHs8qg71jnhoEY1V1JBK33PNHty7IRVXoTwg=";
  speeddial = mkModule "speeddial" "sha256-kGSbJOYxv4ngaxKUQsowLYt1TMnpm3hJk6GkdPoWdWg=";
  announcement = mkModule "announcement" "sha256-V4gak1w+0wjAXW/ChgqaCrggjUR796FWpBQNey2N54A=";
  backup = mkModule "backup" "sha256-HrJySZwrVRFAIhKzFNpB296UYy8r7tiRP7/yOPujYhk=";
  bulkhandler = mkModule "bulkhandler" "sha256-CLX7yYPNjQsunFtUxvpBcla/x2NEtUiQCXGmf0DyJOU=";
  calendar = mkModule "calendar" "sha256-eBaTL9oinWyNiTYwq3ARtV1T4WJFUOjoI0WYvJKXGzA=";
  callforward = mkModule "callforward" "sha256-i9v5Xbkc7vUcqa+ibF9Or/rMfjnGW/lAEQywLqSTbsY=";
  callwaiting = mkModule "callwaiting" "sha256-2O2eME//KRHquN5dyxkFqZR/xNMW3RBBR/Xn7mrJrXk=";
  daynight = mkModule "daynight" "sha256-Td84y9pQxmRRhGfcZiU/ti5BeAM8ips2lQbeDWmZBIc=";
  donotdisturb = mkModule "donotdisturb" "sha256-1PLsTXe+JF9CB1kMCvtkItq2SeAfoRGDaWh+OCuqf0Y=";
  findmefollow = mkModule "findmefollow" "sha256-t9qQrZFIxcDAcV3NqmwyV31wMiH14jrupE4RhQ0cIoE=";
  phonebook = mkModule "phonebook" "sha256-Xz+CH54ipgk+YEUtbaoDXInRf4HQLayyUfUIrirz3Uc=";
  pm2 = mkModule "pm2" "sha256-pIzQjNl7Bv39MtpWFJIcxNpD1A0W64HVUHQTZ4rUAlw=";
  userman = mkModule "userman" "sha256-KajmNBMgmK1RP2jc8zfVBusVK0OFp2P7+anXudShWfI=";
}
