#!/usr/bin/env zsh
# dots - init.zsh
# 設定ファイルの初期化

show_init_help() {
    cat << 'EOF'
dots init - Initialize dots.conf

Usage: dots init [options]

Options:
  --force, -f     Overwrite existing dots.conf
  -h, --help      Show this help message

Description:
  Creates a new dots.conf configuration file in the dotfiles directory.
  If dots.conf already exists, use --force to overwrite it.
EOF
}

cmd_init() {
    local force=0
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                force=1
                shift
                ;;
            *)
                dots_error "Unknown option: $1"
                show_init_help
                return 2
                ;;
        esac
    done
    
    # DOTS_DIR の確認
    if [[ -z "$DOTS_DIR" ]]; then
        dots_error "DOTS_DIR is not set."
        dots_info "Please set DOTS_DIR environment variable to your dotfiles directory."
        return 1
    fi
    
    # ディレクトリが存在するか確認
    if [[ ! -d "$DOTS_DIR" ]]; then
        dots_folder "Creating directory: $DOTS_DIR"
        mkdir -p "$DOTS_DIR"
    fi
    
    # 設定ファイルのパス
    local config_file="${DOTS_DIR}/dots.conf"
    
    # 既存ファイルの確認
    if [[ -f "$config_file" ]]; then
        if [[ $force -eq 0 ]]; then
            dots_error "Config file already exists: $config_file"
            dots_info "Use --force to overwrite."
            return 1
        fi
        dots_warning "Overwriting existing config file."
    fi
    
    # テンプレートを作成
    cat > "$config_file" << 'EOF'
# dots.conf - dotfiles configuration
# Format: filename = target_path
#
# Example:
# [zsh]
# .zshrc = ~/.zshrc
# .zprofile = ~/.zprofile
#
# [vim]
# .vimrc = ~/.vimrc
#
# [git]
# .gitconfig = ~/.gitconfig
EOF
    
    dots_success "Created config file: $config_file"
    
    # DOTS_DIR が環境変数として設定されているか確認
    if ! grep -q "DOTS_DIR" ~/.zshrc 2>/dev/null && \
       ! grep -q "DOTS_DIR" ~/.zprofile 2>/dev/null && \
       ! grep -q "DOTS_DIR" ~/.zshenv 2>/dev/null; then
        echo ""
        dots_info "Consider adding DOTS_DIR to your shell configuration:"
        echo "  export DOTS_DIR=\"$DOTS_DIR\""
        echo "  export PATH=\"\$DOTS_DIR/bin:\$PATH\""
    fi
    
    return 0
}
