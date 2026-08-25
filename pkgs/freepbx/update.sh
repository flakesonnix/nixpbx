#!/usr/bin/env bash
# Updater script for the freepbx package (nixpkgs updateScript convention).
#
# Refreshes every pinned source hash against the upstream release branches:
#   - framework source hash in default.nix
#   - all module hashes in modules.nix
#
# Usage:
#   freepbx-update             apply hash updates to the working tree
#   freepbx-update --commit    apply updates and commit them separately
#
# Environment:
#   NIXPBX_FREEPBX_BRANCH      upstream branch to track (default: 17.0)

set -euo pipefail

branch="${NIXPBX_FREEPBX_BRANCH:-17.0}"
pkg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${pkg_dir}/../.." && pwd)"
package_file="${pkg_dir}/default.nix"
modules_file="${pkg_dir}/modules.nix"

commit=false
if [[ "${1:-}" == "--commit" ]]; then
	commit=true
elif [[ -n "${1:-}" ]]; then
	echo "usage: freepbx-update [--commit]" >&2
	exit 2
fi

cd "${repo_root}"

prefetch() {
	local repo=$1
	local url="https://github.com/FreePBX/${repo}/archive/refs/heads/release/${branch}.tar.gz"
	nix store prefetch-file --unpack --json "${url}" | jq -r '.hash'
}

updated_framework=false
updated_modules=()

echo "framework: prefetching release/${branch} ..."
framework_new="$(prefetch framework)"
framework_old="$(sed -n 's/^.*hash = "\(sha256-[^"]*\)";$/\1/p' "${package_file}")"
if [[ -z "${framework_old}" ]]; then
	echo "framework: could not find src hash in default.nix" >&2
	exit 1
fi
if [[ "${framework_old}" == "${framework_new}" ]]; then
	echo "framework: up to date"
else
	sed -i "s|hash = \"${framework_old}\";|hash = \"${framework_new}\";|" "${package_file}"
	echo "framework: ${framework_old} -> ${framework_new}"
	updated_framework=true
fi

mapfile -t repos < <(awk -F'"' '/= mkModule "/ {print $2}' "${modules_file}")

for repo in "${repos[@]}"; do
	module_new="$(prefetch "${repo}")"
	module_old="$(grep -o "mkModule \"${repo}\" \"[^\"]*\"" "${modules_file}" | grep -o 'sha256-[^"]*')"
	if [[ -z "${module_old}" ]]; then
		echo "modules: no entry found for ${repo}, skipping" >&2
		continue
	fi
	if [[ "${module_old}" == "${module_new}" ]]; then
		continue
	fi
	sed -i "s|mkModule \(\"${repo}\"\) \"sha256-[^\"]*\"|mkModule \\1 \"${module_new}\"|" "${modules_file}"
	echo "modules: ${repo} updated"
	updated_modules+=("${repo}")
done

if ! ${updated_framework} && (( ${#updated_modules[@]} == 0 )); then
	echo "all sources up to date"
	exit 0
fi

if ${commit}; then
	if ${updated_framework}; then
		git add "${package_file}"
		git commit -m "freepbx: refresh framework source hash"
	fi
	if (( ${#updated_modules[@]} > 0 )); then
		git add "${modules_file}"
		git commit -m "freepbx: refresh module hashes"
	fi
fi
