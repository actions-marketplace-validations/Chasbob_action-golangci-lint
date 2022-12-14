#!/bin/bash

function golangci-multi-module() {
    FILES=$(git diff-tree --no-commit-id --name-only -r "${GITHUB_SHA}" | grep 'go$')
    MODULES=$(find . -type f -name 'go.mod' -exec dirname {} \; 2>/dev/null | cut -c 3- | sort | uniq)
    for m in $MODULES; do
      PKGs=$(echo "$FILES" | grep "^$m" | cut -d '/' -f2- | xargs -I ff dirname ff | sort | uniq | tr '\n' ' ')
      if [[ ! "$PKGs" == '' ]]; then
        pushd "${GITHUB_WORKSPACE}/$m" >/dev/null 2>&1 || continue
        # shellcheck disable=SC2086
        golangci-lint run --out-format line-number ${GOLANGCI_LINT_FLAGS} --path-prefix="$m" $PKGs
        popd >/dev/null 2>&1 || continue
      fi
    done
}

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo '::group:: Installing golangci-lint ... https://github.com/golangci/golangci-lint'
curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${GOLANGCI_LINT_VERSION}" 2>&1
echo '::endgroup::'

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

echo '::group:: Running golangci-lint with reviewdog 🐶 ...'
# shellcheck disable=SC2086
golangci-multi-module \
  | reviewdog -f=golangci-lint \
      -name="${INPUT_TOOL_NAME}" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE:-added}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR:-false}" \
      -level="${INPUT_LEVEL}" \
      -diff="${INPUT_DIFF}" \
      ${INPUT_REVIEWDOG_FLAGS}
echo '::endgroup::'
