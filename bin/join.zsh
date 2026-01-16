#!/usr/bin/env zsh
# dots - join.zsh
# 既存の dotfile を管理対象に追加

show_join_help() {
    cat << 'EOF'
dots join - Add a file to management

Usage: dots join <name> <path> [options]

Arguments:
  name            Group name (directory name in repository)
  path            Path to the file to add

Options:
  -f, --filename <name>   Specify filename in repository
  -h, --help              Show this help message

Description:
  Copies the specified file to the dotfiles repository under the
  given group directory, then replaces the original with a symlink.

Examples:
  dots join zsh ~/.zshrc
  dots join zsh ~/.zshrc --filename .zshrc_custom
EOF
}

cmd_join() {
    local group_name=""
    local source_path=""
    local custom_filename=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--filename)
                if [[ -z "$2" ]]; then
                    dots_error "Option --filename requires a value."
                    return 2
                fi
                custom_filename="$2"
                shift 2
                ;;
            -*)
                dots_error "Unknown option: $1"
                show_join_help
                return 2
                ;;
            *)
                if [[ -z "$group_name" ]]; then
                    group_name="$1"
                elif [[ -z "$source_path" ]]; then
                    source_path="$1"
                else
                    dots_error "Too many arguments."
                    show_join_help
                    return 2
                fi
                shift
                ;;
        esac
    done
    
    # 必須引数の確認
    if [[ -z "$group_name" ]]; then
        dots_error "Missing required argument: name"
        show_join_help
        return 2
    fi
    
    if [[ -z "$source_path" ]]; then
        dots_error "Missing required argument: path"
        show_join_help
        return 2
    fi
    
    # 設定ファイルの確認
    check_config_exists || return 1
    
    # パスを展開
    local expanded_source=$(expand_path "$source_path")
    
    # ソースファイルの存在確認
    if [[ ! -e "$expanded_source" ]]; then
        dots_error "File not found: $source_path"
        return 3
    fi
    
    # 既にシンボリックリンクの場合
    if [[ -L "$expanded_source" ]]; then
        dots_error "File is already a symlink: $source_path"
        dots_info "This file may already be managed by dots."
        return 1
    fi
    
    # ファイル名を決定
    local filename="${custom_filename:-${expanded_source:t}}"
    
    # グループディレクトリのパス
    local group_dir="${DOTS_DIR}/${group_name}"
    local dest_file="${group_dir}/${filename}"
    
    # リポジトリ内に同名ファイルが存在する場合
    if [[ -e "$dest_file" ]]; then
        dots_error "File '${group_name}/${filename}' already exists in repository."
        dots_info "Use --filename option to specify a different name."
        return 1
    fi
    
    # グループディレクトリを作成
    if [[ ! -d "$group_dir" ]]; then
        dots_folder "Created directory: ${group_name}/"
        mkdir -p "$group_dir"
    fi
    
    # ファイルをリポジトリにコピー
    cp -R "$expanded_source" "$dest_file"
    dots_success "Copied: $(shorten_path "$expanded_source") -> ${group_name}/${filename}"
    
    # 元ファイルを削除してシンボリックリンクを作成
    rm -rf "$expanded_source"
    ln -s "$dest_file" "$expanded_source"
    dots_link "Created symlink: $(shorten_path "$expanded_source") -> ${group_name}/${filename}"
    
    # 設定ファイルにエントリを追加
    add_config_entry "$group_name" "$filename" "$(shorten_path "$expanded_source")"
    dots_edit "Updated config: [${group_name}] ${filename} = $(shorten_path "$expanded_source")"
    
    dots_success "File added to management!"
    
    return 0
}
