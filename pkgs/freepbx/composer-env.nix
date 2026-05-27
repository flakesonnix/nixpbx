# Fixed-Output Derivation (FOD) for FreePBX PHP composer dependencies.
# The entire vendor/ tree is fetched as a single FOD, which is the most
# pragmatic approach for complex PHP apps with many transitive deps.
#
# To update: delete vendorHash, run `nix build .#freepbx`, and paste the
# correct hash printed by Nix into the vendorHash attribute below.
{ lib
, stdenv
, fetchFromGitHub
, php82
, php82Packages
}:

stdenv.mkDerivation rec {
  pname = "freepbx-vendor";
  version = "17.0.0";

  src = fetchFromGitHub {
    owner = "FreePBX";
    repo  = "framework";
    rev   = "release/17.0";
    # Must match the hash in default.nix
    hash  = "sha256-wkD2hr2JV4tDTI1vhzOjUoBofsAO+H+BinoDuIFrWnc=";
  };

  nativeBuildInputs = [
    php82
    php82Packages.composer
  ];

  buildPhase = ''
    runHook preBuild
    export COMPOSER_HOME=$(mktemp -d)
    composer install \
      --no-dev \
      --optimize-autoloader \
      --no-interaction \
      --no-progress
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r vendor $out
    runHook postInstall
  '';

  # FOD: Nix trusts this hash and skips network checks on rebuild.
  # run: nix build .#freepbx 2>&1 | grep 'got:' to get the real hash.
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash     = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = {
    description = "Vendored PHP dependencies for FreePBX ${version}";
    license = lib.licenses.agpl3Only;
  };
}
