#!/usr/bin/env zsh
# dots - rename.zsh
# リポジトリ内のファイル名を変更し、シンボリックリンクを再設定

show_rename_help() {
    cat << 'EOF'
dots rename - Rename a managed file

Usage: dots rename <name> <old_file> <new_file>

Arguments:
  name            Group name (directory name in repository)
  old_file        Current filename in repository
  new_file        New filename

Options:
  -h, --help      Show this help message

Description:
  Renames a file in the dotfiles repository and updates the symlink
  at the target location to point to the new filename.

Examples:
  dots rename zsh .zshrc .zshrc_new
EOF
}

cmd_rename() {
    local group_name=""
    local old_filename=""
    local new_filename=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                dots_error "Unknown option: $1"
                show_rename_help
                return 2
                ;;
            *)
                if [[ -z "$group_name" ]]; then
                    group_name="$1"
                elif [[ -z "$old_filename" ]]; then
                    old_filename="$1"
                elif [[ -z "$new_filename" ]]; then
                    new_filename="$1"
                else
                    dots_error "Too many arguments."
                    show_rename_help
                    return 2
                fi
                shift
                ;;
        esac
    done
    
    # 必須引数の確認
    if [[ -z "$group_name" ]]; then
        dots_error "Missing required argument: name"
        show_rename_help
        return 2
    fi
    
    if [[ -z "$old_filename" ]]; then
        dots_error "Missing required argument: old_file"
        show_rename_help
        return 2
    fi
    
    if [[ -z "$new_filename" ]]; then
        dots_error "Missing required argument: new_file"
        show_rename_help
        return 2
    fi
    
    # 同じ名前の場合
    if [[ "$old_filename" == "$new_filename" ]]; then
        dots_error "Old and new filenames are the same."
        return 1
    fi
    
    # 設定ファイルを解析
    parse_config || return 1
    
    # エントリを検索
    local found_entry=""
    local target_path=""
    
    for entry in "${DOTS_ENTRIES[@]}"; do
        local entry_section=$(get_entry_section "$entry")
        local entry_filename=$(get_entry_filename "$entry")
        
        if [[ "$entry_section" == "$group_name" && "$entry_filename" == "$old_filename" ]]; then
            found_entry="$entry"
            target_path=$(get_entry_target "$entry")
            break
        fi
    done
    
    if [[ -z "$found_entry" ]]; then
        dots_error "Entry not found: [${group_name}] ${old_filename}"
        return 1
    fi
    
    # パス
    local old_repo_file="${DOTS_DIR}/${group_name}/${old_filename}"
    local new_repo_file="${DOTS_DIR}/${group_name}/${new_filename}"
    local expanded_target=$(expand_path "$target_path")
    
    # 古いファイルが存在するか確認
    if [[ ! -e "$old_repo_file" ]]; then
        dots_error "Repository file not found: ${group_name}/${old_filename}"
        return 3
    fi
    
    # 新しいファイル名が既に存在する場合
    if [[ -e "$new_repo_file" ]]; then
        dots_error "File already exists: ${group_name}/${new_filename}"
        return 1
    fi
    
    # リポジトリ内のファイルをリネーム
    mv "$old_repo_file" "$new_repo_file"
    dots_success "Renamed: ${group_name}/${old_filename} -> ${group_name}/${new_filename}"
    
    # シンボリックリンクを更新
    if [[ -L "$expanded_target" ]]; then
        rm "$expanded_target"
        ln -s "$new_repo_file" "$expanded_target"
        dots_link "Updated symlink: $(shorten_path "$expanded_target") -> ${group_name}/${new_filename}"
    else
        dots_warning "Target is not a symlink: $(shorten_path "$expanded_target")"
        dots_info "Run 'dots deploy' to create the symlink."
    fi
    
    # 設定ファイルを更新
    update_config_entry_filename "$group_name" "$old_filename" "$new_filename"
    dots_edit "Updated config: [${group_name}] ${old_filename} -> ${new_filename}"
    
    dots_success "File renamed successfully!"
    
    return 0
}
