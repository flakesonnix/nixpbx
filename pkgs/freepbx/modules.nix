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
  core = mkModule "core" "sha256-+vUs5IIH8MiiJO4uLnmjUZbJ6s7ZYdzNXB20LPl54KQ=";
  voicemail = mkModule "voicemail" "sha256-kvHqx5qAKgJ0dJyBagelqc+kHVxPgKAM2TXz//2sFmI=";
  cdr = mkModule "cdr" "sha256-AIF2DD+oSkH7T9EbY9k7jUWbbQrqzp1akTpjhixMgWU=";
  conferences = mkModule "conferences" "sha256-+kcPpvQ0pF15gjVo5Vdi6eD5w66z+yI+/odx44x4+Xk=";
  queues = mkModule "queues" "sha256-SY9nPCrUWPNutkVVfjHVBZkT+wi8K72iJlQmWIysReY=";
  ringgroups = mkModule "ringgroups" "sha256-mZvliXOiDpMwyWCU5NNqEpAOLp8qhwnoOvr18sgdQZg=";
  recordings = mkModule "recordings" "sha256-YC33msgrQMzedFmdLtmtwXsnDHqe46TfTWKRgaHHdCw=";
  ivr = mkModule "ivr" "sha256-ksDnSiecSNrvEF0+eBrVnKJ0poGvHaCJHWZrXh2X//8=";
  timeconditions = mkModule "timeconditions" "sha256-HxGPSLdiuG2hgCUu8+GkGs4SV3wZq+gneaZVBbRNRxA=";
  featurecodeadmin = mkModule "featurecodeadmin" "sha256-0Mpmx9GwlOhq23n82wgN9Ul6k1IMSi8HyxAOavebK9k=";
  infoservices = mkModule "infoservices" "sha256-aNN5XeOlQegsCOWHnZ75RNb5+1jLJy57SzdPUHrQEdE=";
  logfiles = mkModule "logfiles" "sha256-ls8x5zjUHM35SGykTqi6LOtLd8+aOwb1BqUPPgDFNDY=";
  music = mkModule "music" "sha256-UOLArfvu2+AY4pz0kevkYY/q1CbqhPJ/tyOSw64/4bc=";
  parking = mkModule "parking" "sha256-q1oaS9Hpdh8C5VefjdCIn0e3k1ac8j/AXDKkUeslP+A=";
  paging = mkModule "paging" "sha256-D1hNtSWGb9AEx8T8ISfhZxZFHAZnX/vPBPZjRbpR33Q=";
  setcid = mkModule "setcid" "sha256-sZnpx/woHs8qg71jnhoEY1V1JBK33PNHty7IRVXoTwg=";
  speeddial = mkModule "speeddial" "sha256-kGSbJOYxv4ngaxKUQsowLYt1TMnpm3hJk6GkdPoWdWg=";
  announcement = mkModule "announcement" "sha256-V4gak1w+0wjAXW/ChgqaCrggjUR796FWpBQNey2N54A=";
  backup = mkModule "backup" "sha256-KeHro0/qDun6CmQ73DQniGoKrtcaFIJJHUrcRNUft38=";
  bulkhandler = mkModule "bulkhandler" "sha256-CLX7yYPNjQsunFtUxvpBcla/x2NEtUiQCXGmf0DyJOU=";
  calendar = mkModule "calendar" "sha256-eBaTL9oinWyNiTYwq3ARtV1T4WJFUOjoI0WYvJKXGzA=";
  callforward = mkModule "callforward" "sha256-i9v5Xbkc7vUcqa+ibF9Or/rMfjnGW/lAEQywLqSTbsY=";
  callwaiting = mkModule "callwaiting" "sha256-2O2eME//KRHquN5dyxkFqZR/xNMW3RBBR/Xn7mrJrXk=";
  daynight = mkModule "daynight" "sha256-Td84y9pQxmRRhGfcZiU/ti5BeAM8ips2lQbeDWmZBIc=";
  donotdisturb = mkModule "donotdisturb" "sha256-1PLsTXe+JF9CB1kMCvtkItq2SeAfoRGDaWh+OCuqf0Y=";
  findmefollow = mkModule "findmefollow" "sha256-ZmhIndYowkz9wBzwzplQ54+f536KWb1ao1/QE+yscbA=";
  phonebook = mkModule "phonebook" "sha256-Xz+CH54ipgk+YEUtbaoDXInRf4HQLayyUfUIrirz3Uc=";
  pm2 = mkModule "pm2" "sha256-pIzQjNl7Bv39MtpWFJIcxNpD1A0W64HVUHQTZ4rUAlw=";
  userman = mkModule "userman" "sha256-MzOaNQNbD+HL23rmc35SkuhqjnZZcNoZJF0SkYtljC4=";
}
