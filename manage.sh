#!/bin/bash

set -e -o pipefail -u
function die() {
  printf '%s\n' "${1}" >&2
  exit 1
}

if ! cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null; then
  die 'Failed to cd into script directory.'
fi

if [[ "$#" -eq 1 && "${1}" == 'generate' ]]; then
  if [[ ! -d 'target/.git' ]]; then
    die "Target repository has not yet been set up. Run \`${0} apply' first."
  fi
  if [[ ! -d 'patches/' ]] && ! mkdir 'patches/'; then
    die 'Failed to create patch directory.'
  fi
  cd 'target' || die 'Failed to cd into target directory.'
  if ! find '../patches/' -type 'f' -name '*.patch' -delete; then
    die 'Failed to clean up patch directory.'
  fi
  if git format-patch --zero-commit --full-index --no-signature --no-numbered --no-stat -o '../patches/' 'origin/upstream'; then
    echo 'Successfully generated patches.'
  else
    die 'Failed to generate patches. See output above for an error description.'
  fi
elif [[ "$#" -eq 1 && "${1}" == 'apply' ]]; then
  if [[ ! -d 'target/' ]]; then
    git clone "$(pwd)/upstream" 'target' || die 'Failed to clone repository.'
  fi
  cd 'target' || die 'Failed to cd into target directory.'
  git config --local 'core.whitespace' ''
  git config --local 'commit.gpgsign' 'false'
  git config --local 'advice.detachedHead' 'false'
  if ! git diff-index --quiet HEAD; then
    die "Target repository has changed. Commit or revert them first."
  fi
  if ! UPSTREAM_HEAD="$(git -C '../upstream/' rev-parse HEAD)"; then
    die 'Could not detect upstream HEAD.'
  fi
  git fetch origin && git reset --hard "${UPSTREAM_HEAD}"
  IFS=$'\n' read -rd "" -a PATCHES <<< "$(find '../patches/' -type 'f' -name '*.patch' | sort)" || [[ "$?" -le 128 ]]
  echo "Applying ${#PATCHES[@]} patches on top of $(git rev-parse --short HEAD) ($(git log -1 --format=%s))..."
  if git am --3way --whitespace=fix -- "${PATCHES[@]}"; then
    echo "Successfully applied ${#PATCHES[@]} patches. Now at commit $(git rev-parse --short HEAD) ($(git log -1 --format=%s))."
  else
    die 'Failed to apply all patches. Please resolve conflicts manually.'
  fi
else
  die "Usage: ${0} <apply|generate>"
fi
