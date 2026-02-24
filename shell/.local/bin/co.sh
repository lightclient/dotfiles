co() {

    _co_usage() {
        cat <<'EOF'
Usage: co <command> [args]

Commands:
  new <name> [ref]    Create sibling checkout and cd into it
  rm <name>           Remove a sibling checkout and cd to default
  ls                  List sibling checkouts

ref can be:
  (empty)             default branch (main/master)
  <branch>            branch, tag, or commit
  pr:<number>         GitHub/GitLab pull request

Examples:
  co new agent-1
  co new fix-foo feature-branch
  co new review pr:456
  co rm agent-1
  co ls
EOF
    }

    _co_resolve() {
        if CO_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
            # Inside a checkout — parent is one level up
            CO_PARENT="$(dirname "$CO_GIT_ROOT")"
            CO_ORIGIN="$(git -C "$CO_GIT_ROOT" remote get-url origin 2>/dev/null)" || { echo "error: no 'origin' remote" >&2; return 1; }
        else
            # Not in a repo — look for checkouts in current directory
            CO_PARENT="$(pwd)"
            CO_GIT_ROOT=""
            CO_ORIGIN=""

            # Collect unique origins
            local origins=() dir o found existing
            for dir in "$CO_PARENT"/*/; do
                [[ -d "$dir/.git" ]] || continue
                o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
                found=0
                for existing in "${origins[@]+"${origins[@]}"}"; do
                    [[ "$existing" == "$o" ]] && { found=1; break; }
                done
                (( found )) || origins+=("$o")
                [[ -z "$CO_ORIGIN" ]] && { CO_ORIGIN="$o"; CO_GIT_ROOT="$dir"; }
            done

            [[ -n "$CO_ORIGIN" ]] || { echo "error: no git checkouts found in $(pwd)" >&2; return 1; }

            if (( ${#origins[@]} > 1 )); then
                echo "error: multiple repos in $(pwd) — cd into a checkout first" >&2
                for o in "${origins[@]}"; do
                    echo "  $o" >&2
                done
                return 1
            fi
        fi
    }

    _co_find_default() {
        local dir fallback="" o b name
        for dir in "$CO_PARENT"/*/; do
            [[ -d "$dir/.git" ]] || continue
            o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
            [[ "$o" == "$CO_ORIGIN" ]] || continue
            name="$(basename "$dir")"
            b="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || continue
            if [[ "$name" == "main" || "$name" == "master" ]]; then
                echo "${dir%/}"
                return
            fi
            if [[ -z "$fallback" && ("$b" == "main" || "$b" == "master") ]]; then
                fallback="${dir%/}"
            fi
        done
        echo "${fallback:-$CO_PARENT}"
    }

    _co_resolve_url() {
        local url="$1" longest_match="" longest_base="" line key val base
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            key="${line%% *}"
            val="${line#* }"
            base="${key#url.}"
            base="${base%.insteadof}"
            if [[ "$url" == "$val"* && ${#val} -gt ${#longest_match} ]]; then
                longest_match="$val"
                longest_base="$base"
            fi
        done < <(git config --get-regexp 'url\..*\.insteadof' 2>/dev/null)
        if [[ -n "$longest_match" ]]; then
            echo "${longest_base}${url#"$longest_match"}"
        else
            echo "$url"
        fi
    }

    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        new)
            local name="${1:?usage: co new <name> [ref]}"
            local ref="${2:-}"
            _co_resolve || return 1

            local target="$CO_PARENT/$name"
            [[ -d "$target" ]] && { echo "error: $target already exists" >&2; return 1; }

            local ref_repo
            ref_repo="$(_co_find_default)"
            [[ "$ref_repo" == "$CO_PARENT" ]] && ref_repo="$CO_GIT_ROOT"

            local _clone_url
            _clone_url="$(_co_resolve_url "$CO_ORIGIN")"

            echo "cloning into $target ..."
            git clone --reference "$ref_repo" --no-checkout "$_clone_url" "$target"

            # Copy non-origin remotes from source checkout
            local _remote _rurl
            while IFS= read -r _remote; do
                [[ "$_remote" == "origin" || -z "$_remote" ]] && continue
                _rurl="$(git -C "$ref_repo" remote get-url "$_remote" 2>/dev/null)" || continue
                _rurl="$(_co_resolve_url "$_rurl")"
                git -C "$target" remote add "$_remote" "$_rurl" 2>/dev/null || true
            done < <(git -C "$ref_repo" remote 2>/dev/null)

            git -C "$target" fetch origin

            local _track_remote="" _track_branch=""

            if [[ -z "$ref" ]]; then
                local default_branch
                default_branch="$(git -C "$target" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')" || default_branch="main"
                git -C "$target" checkout "$default_branch"
                _track_remote="origin"
                _track_branch="$default_branch"
            elif [[ "$ref" == pr:* ]]; then
                local pr_num="${ref#pr:}"
                echo "fetching PR #$pr_num ..."

                local _pr_owner="" _pr_branch=""
                if command -v gh &>/dev/null; then
                    local _pr_info
                    _pr_info="$(cd "$ref_repo" && gh pr view "$pr_num" --json headRefName,headRepositoryOwner --jq '"\(.headRepositoryOwner.login) \(.headRefName)"' 2>/dev/null)" || true
                    if [[ -n "$_pr_info" ]]; then
                        _pr_owner="${_pr_info%% *}"
                        _pr_branch="${_pr_info#* }"
                    fi
                fi

                if [[ -n "$_pr_owner" && -n "$_pr_branch" ]]; then
                    local _pr_remote_url
                    _pr_remote_url="$(echo "$_clone_url" | sed -E 's|(github\.com[:/])[^/]+|\1'"$_pr_owner"'|')"
                    git -C "$target" remote add "$_pr_owner" "$_pr_remote_url" 2>/dev/null || true
                    git -C "$target" fetch "$_pr_owner" "+refs/heads/$_pr_branch:refs/remotes/$_pr_owner/$_pr_branch"
                    git -C "$target" checkout -b "pr-$pr_num" "$_pr_owner/$_pr_branch"
                    _track_remote="$_pr_owner"
                    _track_branch="$_pr_branch"
                else
                    git -C "$target" fetch origin "pull/$pr_num/head:pr-$pr_num"
                    git -C "$target" checkout "pr-$pr_num"
                fi
            else
                echo "checking out $ref ..."
                git -C "$target" checkout "$ref"
                _track_remote="origin"
                _track_branch="$ref"
            fi

            # Set upstream tracking
            if [[ -n "$_track_remote" && -n "$_track_branch" ]]; then
                local _local_branch
                _local_branch="$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)"
                if [[ -n "$_local_branch" && "$_local_branch" != "HEAD" ]]; then
                    git -C "$target" branch --set-upstream-to="$_track_remote/$_track_branch" "$_local_branch" 2>/dev/null || true
                fi
            fi

            echo "ready: $target"
            cd "$target"
            ;;
        rm)
            local name="${1:?usage: co rm <name>}"
            _co_resolve || return 1

            local target="$CO_PARENT/$name"
            [[ -d "$target" ]] || { echo "error: $target does not exist" >&2; return 1; }
            [[ -d "$target/.git" ]] || { echo "error: $target is not a git checkout" >&2; return 1; }

            if ! git -C "$target" diff --quiet HEAD 2>/dev/null; then
                read -rp "$name has uncommitted changes. Remove anyway? [y/N] " answer
                [[ "$answer" == [yY]* ]] || return 0
            fi

            local landing
            landing="$(_co_find_default)"
            [[ "${landing%/}" == "${target%/}" ]] && landing="$CO_PARENT"

            rm -rf "$target"
            echo "removed: $target"
            cd "$landing"
            ;;
        ls)
            _co_resolve || return 1
            local current_name="" default_branch="" dir o name branch label
            [[ -n "$CO_GIT_ROOT" ]] && current_name="$(basename "$CO_GIT_ROOT")"

            # Determine the default branch name
            for dir in "$CO_PARENT"/*/; do
                [[ -d "$dir/.git" ]] || continue
                o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
                [[ "$o" == "$CO_ORIGIN" ]] || continue
                default_branch="$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')" && break
            done
            [[ -z "$default_branch" ]] && default_branch="main"

            for dir in "$CO_PARENT"/*/; do
                [[ -d "$dir/.git" ]] || continue
                o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
                [[ "$o" == "$CO_ORIGIN" ]] || continue

                name="$(basename "$dir")"
                branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"

                if [[ "$name" == "$current_name" ]]; then
                    label="* $name"
                else
                    label="  $name"
                fi

                if [[ "$branch" != "$default_branch" ]]; then
                    printf "%-27s %s\n" "$label" "$branch"
                else
                    printf "%s\n" "$label"
                fi
            done
            ;;
        *)
            _co_usage
            ;;
    esac
}
