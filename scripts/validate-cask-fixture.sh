#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/homebrew-speedns-cask-fixture.XXXXXX")"
trap 'rm -rf -- "${fixture_dir}"' EXIT

make_checkout() {
	local destination="$1"
	mkdir -p "${destination}/Casks"
	cp "${root_dir}/Casks/speedns.rb" "${destination}/Casks/speedns.rb"
	git -C "${destination}" init -q
	git -C "${destination}" config user.email fixture@example.invalid
	git -C "${destination}" config user.name fixture
	git -C "${destination}" config commit.gpgsign false
	git -C "${destination}" add .
	git -C "${destination}" commit -q -m fixture
}

clean_checkout="${fixture_dir}/clean"
make_checkout "${clean_checkout}"
VALIDATE_CASK_SKIP_BREW=1 bash "${root_dir}/scripts/validate-cask.sh" "${clean_checkout}"

set_head_tree() {
	local destination="$1"
	local mode="$2"
	local blob
	local casks_tree
	local root_tree
	local commit
	local branch

	blob="$(git -C "${destination}" hash-object -w "${destination}/Casks/speedns.rb")"
	case "${mode}" in
		legacy)
			casks_tree="$(printf '100644 blob %s\tSpeeDNS.rb\n100644 blob %s\tspeedns.rb\n' \
				"${blob}" "${blob}" | git -C "${destination}" mktree)"
			;;
		uppercase)
			casks_tree="$(printf '100644 blob %s\tSpeeDNS.rb\n' "${blob}" | git -C "${destination}" mktree)"
			;;
		*)
			echo "unknown fixture tree mode: ${mode}" >&2
			exit 2
			;;
	esac
	root_tree="$(printf '040000 tree %s\tCasks\n' "${casks_tree}" | git -C "${destination}" mktree)"
	branch="$(git -C "${destination}" symbolic-ref --short HEAD)"
	commit="$(printf '%s\n' "${mode} fixture" | git -C "${destination}" commit-tree "${root_tree}")"
	git -C "${destination}" update-ref "refs/heads/${branch}" "${commit}"
}

legacy_checkout="${fixture_dir}/legacy"
make_checkout "${legacy_checkout}"
set_head_tree "${legacy_checkout}" legacy
if VALIDATE_CASK_SKIP_BREW=1 bash "${root_dir}/scripts/validate-cask.sh" "${legacy_checkout}"; then
	echo "case-insensitive cask collision was unexpectedly accepted" >&2
	exit 1
fi

uppercase_checkout="${fixture_dir}/uppercase"
make_checkout "${uppercase_checkout}"
set_head_tree "${uppercase_checkout}" uppercase
if VALIDATE_CASK_SKIP_BREW=1 bash "${root_dir}/scripts/validate-cask.sh" "${uppercase_checkout}"; then
	echo "uppercase-only cask path was unexpectedly accepted" >&2
	exit 1
fi

echo "Homebrew cask fixture passed"
