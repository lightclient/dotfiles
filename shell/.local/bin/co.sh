co() {
    set -euo pipefail

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
        CO_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "error: not inside a git repository" >&2; return 1; }
        CO_PARENT="$(dirname "$CO_GIT_ROOT")"
        CO_ORIGIN="$(git -C "$CO_GIT_ROOT" remote get-url origin 2>/dev/null)" || { echo "error: no 'origin' remote" >&2; return 1; }
    }

    _co_find_default() {
        local dir
        for dir in "$CO_PARENT"/*/; do
            [[ -d "$dir/.git" ]] || continue
            local o b
            o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
            [[ "$o" == "$CO_ORIGIN" ]] || continue
            b="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || continue
            if [[ "$b" == "main" || "$b" == "master" ]]; then
                echo "${dir%/}"
                return
            fi
        done
        echo "$CO_PARENT"
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

            echo "cloning into $target ..."
            git clone --reference "$CO_GIT_ROOT" --no-checkout "$CO_ORIGIN" "$target"
            git -C "$target" fetch origin

            if [[ -z "$ref" ]]; then
                local default_branch
                default_branch="$(git -C "$target" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')" || default_branch="main"
                git -C "$target" checkout "$default_branch"
            elif [[ "$ref" == pr:* ]]; then
                local pr_num="${ref#pr:}"
                echo "fetching PR #$pr_num ..."
                git -C "$target" fetch origin "pull/$pr_num/head:pr-$pr_num"
                git -C "$target" checkout "pr-$pr_num"
            else
                echo "checking out $ref ..."
                git -C "$target" checkout "$ref"
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
            local current_name
            current_name="$(basename "$CO_GIT_ROOT")"

            local dir
            for dir in "$CO_PARENT"/*/; do
                [[ -d "$dir/.git" ]] || continue
                local o
                o="$(git -C "$dir" remote get-url origin 2>/dev/null)" || continue
                [[ "$o" == "$CO_ORIGIN" ]] || continue

                local name branch marker=" "
                name="$(basename "$dir")"
                branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
                [[ "$name" == "$current_name" ]] && marker="*"
                printf "%s %-20s %s\n" "$marker" "$name" "$branch"
            done
            ;;
        *)
            _co_usage
            ;;
    esac
}
