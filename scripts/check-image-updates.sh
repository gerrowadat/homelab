#!/usr/bin/env bash
#
# Compare the docker image tags pinned in nomad/ HCL job files against the
# tags the running diun instance has seen, and print a recommendation for
# each image reference.
#
# Requires: nomad CLI (with cluster access), jq, and the diun job running.
# diun only learns about newer tags when watchRepo is enabled (see the
# defaults block in nomad/infra/diun/diun.hcl) and after a watch cycle has
# run since deploy; until then everything shows as UNWATCHED or OK.

set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

# stdin redirected so exec calls inside the read loop don't eat its input
diun_exec() {
  nomad alloc exec -t=false -job diun diun "$@" < /dev/null
}

# Normalise an image name the way diun stores it: registry-qualified, with
# docker.io/library/ for official images ("postgres", "docker.io/redis").
normalise() {
  local name=$1 first=${1%%/*}
  if [[ $name != */* ]]; then
    name="docker.io/library/${name}"
  elif [[ $first != *.* && $first != *:* && $first != localhost ]]; then
    name="docker.io/${name}"
  fi
  if [[ $name == docker.io/* && ${name#docker.io/} != */* ]]; then
    name="docker.io/library/${name#docker.io/}"
  fi
  echo "$name"
}

echo "Querying diun image database..." >&2
diun_list=$(diun_exec image list --raw)

declare -A tags_cache
updates=0

while IFS=$'\t' read -r file image; do
  # References built from HCL variables/interpolation can't be checked.
  if [[ $image == *'${'* ]]; then
    printf 'SKIP      %-55s %s: not a literal image reference\n' "$image" "$file"
    continue
  fi

  ref=${image%%@*}   # drop any digest pin
  tag=latest
  base=$ref
  if [[ ${ref##*/} == *:* ]]; then
    tag=${ref##*:}
    base=${ref%:*}
  fi
  repo=$(normalise "$base")

  if ! jq -e --arg n "$repo" '.images[] | select(.name == $n)' <<<"$diun_list" >/dev/null; then
    printf 'UNWATCHED %-55s %s: diun has no record (job not running, or no watch cycle yet?)\n' "$repo:$tag" "$file"
    continue
  fi

  if [[ $tag == latest || $tag == stable || $tag == nightly || $tag == edge ]]; then
    printf 'MUTABLE   %-55s %s: mutable tag; diun tracks digest changes only\n' "$repo:$tag" "$file"
    continue
  fi

  if [[ ! -v tags_cache[$repo] ]]; then
    tags_cache[$repo]=$(diun_exec image inspect --image "$repo" --raw \
      | jq -r '.image.manifests[].tag')
  fi

  # Candidate tags: same shape as the pinned tag — identical non-version
  # suffix, so "16" never gets recommended "16-alpine" and "-rc1" tags are
  # only considered when the pinned tag is itself a prerelease. Sort on the
  # version with any leading "v" stripped so v-tags and bare tags compare
  # correctly, and ignore date/CI-build tags (6+ digit first component)
  # unless the pinned tag is itself one.
  suffix=$(printf '%s' "$tag" | sed -E 's/^v?[0-9]+(\.[0-9]+)*//')
  newest=$( { printf '%s\n' "${tags_cache[$repo]}"; echo "$tag"; } \
    | awk -v suf="$suffix" -v cfg="$tag" '
        {
          t = $0; sub(/^v?[0-9]+(\.[0-9]+)*/, "", t)
          if (t != suf) next
          key = $0; sub(/^v/, "", key)
          ckey = cfg; sub(/^v/, "", ckey)
          if (key ~ /^[0-9]{6}/ && ckey !~ /^[0-9]{6}/) next
          print key "\t" $0
        }' \
    | sort -uV -k1,1 | tail -1 | cut -f2)

  if [[ -z $newest || ${newest#v} == "${tag#v}" ]]; then
    printf 'OK        %-55s %s: up to date as far as diun knows\n' "$repo:$tag" "$file"
  else
    printf 'UPDATE    %-55s %s: bump %s -> %s\n' "$repo:$tag" "$file" "$tag" "$newest"
    updates=$((updates + 1))
  fi
done < <(grep -rHoE 'image[[:space:]]*=[[:space:]]*"[^"]+"' nomad --include='*.hcl' \
           | sed -E 's/^([^:]+):image[[:space:]]*=[[:space:]]*"([^"]+)"$/\1\t\2/' \
           | sort -u)

echo >&2
echo "${updates} update(s) recommended." >&2
