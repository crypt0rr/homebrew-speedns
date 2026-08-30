#!/usr/bin/env bash
set -euo pipefail

root_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
canonical_path="Casks/speedns.rb"
cd "${root_dir}"

if [[ ! -d .git ]]; then
	echo "not a Git checkout: ${root_dir}" >&2
	exit 2
fi

tracked_paths="$(git ls-tree -r --name-only HEAD)"
duplicate_paths="$(printf '%s\n' "${tracked_paths}" | awk '
	NF {
		key = tolower($0)
		paths[key] = paths[key] (paths[key] ? "\n" : "") $0
		counts[key]++
	}
	END {
		for (key in counts) {
			if (counts[key] > 1) {
				print paths[key]
			}
		}
	}
')"
if [[ -n "${duplicate_paths}" ]]; then
	echo "case-insensitive duplicate paths found:" >&2
	printf '%s\n' "${duplicate_paths}" >&2
	exit 1
fi

case_variant_paths="$(printf '%s\n' "${tracked_paths}" | awk -v expected="${canonical_path}" \
	'tolower($0) == tolower(expected) && $0 != expected { print }')"
if [[ -n "${case_variant_paths}" ]]; then
	echo "case-variant SpeeDNS cask path found:" >&2
	printf '%s\n' "${case_variant_paths}" >&2
	exit 1
fi
if ! printf '%s\n' "${tracked_paths}" | grep -Fqx -- "${canonical_path}"; then
	echo "missing canonical cask path: ${canonical_path}" >&2
	exit 1
fi

if [[ ! -f "${canonical_path}" ]]; then
	echo "canonical cask file is missing from the checkout: ${canonical_path}" >&2
	exit 1
fi
if [[ "${VALIDATE_CASK_SKIP_BREW:-0}" != 1 ]]; then
	if ! command -v brew >/dev/null 2>&1; then
		echo "brew is required for cask validation" >&2
		exit 1
	fi
	brew_tap_name="${BREW_TAP_NAME:-crypt0rr/speedns}"
	brew_cask_name="${brew_tap_name}/speedns"
	brew style --cask "${brew_cask_name}"
	brew audit --cask "${brew_cask_name}"
	brew_tap_dir="$(brew --repo "${brew_tap_name}")"
	if [[ -n "$(git -C "${brew_tap_dir}" status --porcelain)" ]]; then
		echo "Homebrew tap checkout is dirty: ${brew_tap_dir}" >&2
		git -C "${brew_tap_dir}" status --short >&2
		exit 1
	fi
fi

if [[ -n "$(git status --porcelain)" ]]; then
	echo "checkout is dirty after validation" >&2
	git status --short >&2
	exit 1
fi

echo "Homebrew cask validated: ${canonical_path}"
