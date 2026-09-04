#!/usr/bin/env zsh
# dots - pull.zsh
# ターゲット側の内容をリポジトリへ取り込み直す

show_pull_help() {
    cat << 'EOF'
dots pull - Sync repository file from target

Usage: dots pull <name> <file>

Arguments:
  name            Group name (directory name in repository)
  file            Filename in repository

Options:
  -h, --help      Show this help message

Description:
  Some applications (e.g. Karabiner-Elements) save their config by
  writing a new file and renaming it into place, which replaces a
  symlinked target with a regular file. This command copies the
  current content at the target path back into the repository, then
  restores the target according to the entry's mode:
    - mode=symlink (default): re-creates the symlink to the repository file
    - mode=copy: leaves the target as-is (it's already a plain copy)

  If the repository file and the target already differ, you will be
  asked to confirm before the repository file is overwritten.

Examples:
  dots pull karabiner karabiner.json
EOF
}

cmd_pull() {
    local group_name=""
    local filename=""

    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                dots_error "Unknown option: $1"
                show_pull_help
                return 2
                ;;
            *)
                if [[ -z "$group_name" ]]; then
                    group_name="$1"
                elif [[ -z "$filename" ]]; then
                    filename="$1"
                else
                    dots_error "Too many arguments."
                    show_pull_help
                    return 2
                fi
                shift
                ;;
        esac
    done

    # 必須引数の確認
    if [[ -z "$group_name" ]]; then
        dots_error "Missing required argument: name"
        show_pull_help
        return 2
    fi

    if [[ -z "$filename" ]]; then
        dots_error "Missing required argument: file"
        show_pull_help
        return 2
    fi

    # 設定ファイルを解析
    parse_config || return 1

    # エントリを検索
    local found_entry=""
    local target_path=""
    local mode="symlink"

    for entry in "${DOTS_ENTRIES[@]}"; do
        local entry_section=$(get_entry_section "$entry")
        local entry_filename=$(get_entry_filename "$entry")

        if [[ "$entry_section" == "$group_name" && "$entry_filename" == "$filename" ]]; then
            found_entry="$entry"
            target_path=$(get_entry_target "$entry")
            mode=$(get_entry_mode "$entry")
            break
        fi
    done

    if [[ -z "$found_entry" ]]; then
        dots_error "Entry not found: [${group_name}] ${filename}"
        return 1
    fi

    # パス
    local repo_file="${DOTS_DIR}/${group_name}/${filename}"
    local expanded_target=$(expand_path "$target_path")

    # リポジトリ内のファイルが存在するか確認
    if [[ ! -e "$repo_file" ]]; then
        dots_error "Repository file not found: ${group_name}/${filename}"
        return 3
    fi

    # ターゲットが存在するか確認
    if [[ ! -e "$expanded_target" ]]; then
        dots_error "Target does not exist: $(shorten_path "$expanded_target")"
        return 3
    fi

    # 既にリポジトリファイルへ正しくリンクされている場合は何もすることがない
    if [[ -L "$expanded_target" ]]; then
        local current_link=$(readlink "$expanded_target")
        if [[ "${current_link:A}" == "${repo_file:A}" ]]; then
            dots_info "Already linked to repository file: ${group_name}/${filename}"
            return 0
        fi
    fi

    # 内容が同じなら確認なしで進める（symlink 再構築のみ必要な場合など）
    if ! cmp -s "$expanded_target" "$repo_file" 2>/dev/null; then
        if ! prompt_pull_confirm "$expanded_target" "$repo_file"; then
            dots_info "Cancelled."
            return 0
        fi
    fi

    # ターゲットの内容をリポジトリへ取り込む（一時ファイル経由で安全に）
    local tmp_repo_file="${repo_file}.tmp.$$"
    if cp -RL "$expanded_target" "$tmp_repo_file"; then
        rm -rf "$repo_file"
        mv "$tmp_repo_file" "$repo_file"
        dots_edit "Updated repository file: ${group_name}/${filename} from $(shorten_path "$expanded_target")"
    else
        rm -rf "$tmp_repo_file"
        dots_error "Failed to pull from: $(shorten_path "$expanded_target")"
        return 3
    fi

    # mode=symlink の場合はターゲットをシンボリックリンクに戻す
    # mode=copy の場合はターゲットはそのまま（既に通常ファイルとして同期済み）
    if [[ "$mode" != "copy" ]]; then
        rm -rf "$expanded_target"
        ln -s "$repo_file" "$expanded_target"
        dots_link "Restored symlink: $(shorten_path "$expanded_target") -> ${group_name}/${filename}"
    fi

    dots_success "Pulled: ${group_name}/${filename}"

    return 0
}
