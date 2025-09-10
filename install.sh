#!/usr/bin/env bash

set -euo pipefail



# Default configuration
readonly DEFAULT_PLYMOUTH_THEME_BASEDIR="/usr/share/plymouth/themes/mc"
readonly DEFAULT_FONTS_BASEDIR="/usr/share/fonts"
readonly DEFAULT_FONT_PATH="/etc/fonts"

# Environment variables with defaults
PLYMOUTH_THEME_BASEDIR=${PLYMOUTH_THEME_BASEDIR:-$DEFAULT_PLYMOUTH_THEME_BASEDIR}
FONTS_BASEDIR=${FONTS_BASEDIR:-$DEFAULT_FONTS_BASEDIR}
FONT_PATH=${FONT_PATH:-$DEFAULT_FONT_PATH}
FONTCONFIG_PATH=${FONTCONFIG_PATH:-${FONT_PATH}/conf.d}

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
VERBOSE=false

# Logging functions
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1" >&2
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1" >&2
}

log_warn() {
    echo -e "\033[1;33m[WARNING]\033[0m $1" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[0;34m[VERBOSE]\033[0m $1" >&2
    fi
}

# Show usage information
show_usage() {
    cat << 'EOF'
Minecraft Plymouth Theme

USAGE:
    sudo ./install.sh           # Install theme
    sudo ./install.sh --uninstall  # Remove theme
    ./install.sh --dry-run      # Preview (no root needed)

OPTIONS:
    -v, --verbose       Detailed output
    -h, --help          This help

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --uninstall)
                uninstall_theme
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if running as root (skip for dry-run)
check_root() {
    if [[ $EUID -ne 0 && "$DRY_RUN" == "false" ]]; then
        show_usage
        exit 1
    fi
}

# Verify required commands are available
check_dependencies() {
    local missing=()
    
    command -v magick >/dev/null || missing+=("imagemagick")
    command -v plymouth >/dev/null || missing+=("plymouth")
    command -v install >/dev/null || missing+=("coreutils")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        
        # Show install command for current distro
        if command -v apt >/dev/null; then
            log_info "Install with: sudo apt install ${missing[*]}"
        elif command -v dnf >/dev/null; then
            log_info "Install with: sudo dnf install ${missing[*]} plymouth-plugin-script"
        elif command -v pacman >/dev/null; then
            log_info "Install with: sudo pacman -S ${missing[*]}"
        elif command -v zypper >/dev/null; then
            log_info "Install with: sudo zypper install ${missing[*]}"
        fi
        
        exit 1
    fi
}

# Validate source files exist
validate_source_files() {
    local files=(
        "font/Minecraft.otf" "font/config/00-minecraft.conf"
        "plymouth/mc.script" "plymouth/mc.plymouth" 
        "plymouth/progress_bar.png" "plymouth/progress_box.png"
        "plymouth/bar.png" "plymouth/padlock.png" "plymouth/dirt.png"
        "mkinitcpio/minecraft-plymouth.conf"
    )
    
    local missing=()
    for file in "${files[@]}"; do
        [[ -f "$SCRIPT_DIR/$file" ]] || missing+=("$file")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing files:"
        printf '  %s\n' "${missing[@]}"
        exit 1
    fi
    
    log_verbose "All source files found"
}

# Safely execute command with dry-run support
safe_execute() {
    local cmd="$1"
    local description="$2"
    
    log_verbose "$description"
    log_verbose "Command: $cmd"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log_verbose "✓ $description completed successfully"
        return 0
    else
        log_error "✗ Failed: $description"
        return 1
    fi
}

# Install font files
install_fonts() {
    log_info "Installing fonts..."
    
    safe_execute "install -d -m 0755 '${FONTS_BASEDIR}/OTF/'" "Creating font directory"
    safe_execute "install -m 0644 '${SCRIPT_DIR}/font/Minecraft.otf' '${FONTS_BASEDIR}/OTF/'" "Installing font"
    safe_execute "install -d -m 0755 '${FONTCONFIG_PATH}'" "Creating font config directory"
    safe_execute "install -m 0644 '${SCRIPT_DIR}/font/config/'* '${FONTCONFIG_PATH}/'" "Installing font config"
    
    if command -v fc-cache >/dev/null; then
        safe_execute "fc-cache -fv" "Updating font cache"
    else
        log_warn "fc-cache not found"
    fi
}

# Install Plymouth theme files
install_plymouth_theme() {
    log_info "Installing Plymouth theme..."
    
    safe_execute "install -d -m 0755 '${PLYMOUTH_THEME_BASEDIR}'" "Creating theme directory"
    
    local files=("mc.script" "mc.plymouth" "progress_bar.png" "progress_box.png")
    for file in "${files[@]}"; do
        safe_execute "install -m 0644 '${SCRIPT_DIR}/plymouth/${file}' '${PLYMOUTH_THEME_BASEDIR}/'" "Installing $file"
    done
}

# Generate scaled assets
generate_scaled_assets() {
    log_info "Generating scaled assets..."
    
    # Check if assets already exist and are newer than source
    local assets_current=true
    local source_files=("${SCRIPT_DIR}/plymouth/padlock.png" "${SCRIPT_DIR}/plymouth/bar.png" "${SCRIPT_DIR}/plymouth/dirt.png")
    
    for source_file in "${source_files[@]}"; do
        local base_name
        base_name=$(basename "$source_file" .png)
        
        for i in $(seq 1 6); do
            local target_file="${PLYMOUTH_THEME_BASEDIR}/${base_name}-${i}.png"
            if [[ ! -f "$target_file" ]] || [[ "$source_file" -nt "$target_file" ]]; then
                assets_current=false
                break 2
            fi
        done
    done
    
    # Special check for dirt assets (goes up to 12)
    for i in $(seq 1 12); do
        local target_file="${PLYMOUTH_THEME_BASEDIR}/dirt-${i}.png"
        if [[ ! -f "$target_file" ]] || [[ "${SCRIPT_DIR}/plymouth/dirt.png" -nt "$target_file" ]]; then
            assets_current=false
            break
        fi
    done
    
    if [[ "$assets_current" == "true" ]]; then
        log_info "Scaled assets are up to date, skipping generation"
        return 0
    fi
    
    log_verbose "Generating padlock and bar assets (1x-6x scale)..."
    for asset in "padlock" "bar"; do
        for scale in $(seq 1 6); do
            safe_execute "magick '${SCRIPT_DIR}/plymouth/${asset}.png' -interpolate Nearest -filter point -resize '${scale}00%' '${PLYMOUTH_THEME_BASEDIR}/${asset}-${scale}.png'" \
                "Generating ${asset} at ${scale}x scale"
        done
    done
    
    log_verbose "Generating dirt background assets (1x-12x scale)..."
    for scale in $(seq 1 12); do
        safe_execute "magick '${SCRIPT_DIR}/plymouth/dirt.png' -channel R -evaluate multiply .2509803922 -channel G -evaluate multiply .2509803922 -channel B -evaluate multiply .2509803922 -interpolate Nearest -filter point -resize '${scale}00%' '${PLYMOUTH_THEME_BASEDIR}/dirt-${scale}.png'" \
            "Generating dirt background at ${scale}x scale"
    done
}

# Detect Plymouth library paths
detect_plymouth_paths() {
    local paths=("/usr/lib/plymouth" "/usr/lib64/plymouth" "/usr/lib/x86_64-linux-gnu/plymouth" "/usr/lib/aarch64-linux-gnu/plymouth")
    
    PLYMOUTHLIBS_PATH=""
    for path in "${paths[@]}"; do
        if [[ -d "$path" ]]; then
            PLYMOUTHLIBS_PATH="$path"
            log_verbose "Found Plymouth at: $path"
            break
        fi
    done
    
    if [[ -z "$PLYMOUTHLIBS_PATH" ]]; then
        log_error "Plymouth libraries not found"
        exit 1
    fi
    
    # Detect label library
    PLYMOUTHLABELLIB="label.so"
    [[ -f "${PLYMOUTHLIBS_PATH}/label-pango.so" ]] && PLYMOUTHLABELLIB="label-pango.so"
    
    log_verbose "Using: $PLYMOUTHLABELLIB"
}

# Install initrd configurations
# Check if theme is currently active
check_active_theme() {
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        local current_theme
        current_theme=$(plymouth-set-default-theme 2>/dev/null || echo "unknown")
        
        if [[ "$current_theme" == "mc" ]]; then
            log_warn "The Minecraft theme is currently active!"
            log_info "You should set a different theme before uninstalling:"
            log_info "  plymouth-set-default-theme -R <other-theme>"
            
            # List available themes
            if command -v plymouth-set-default-theme >/dev/null 2>&1; then
                log_info ""
                log_info "Available themes:"
                plymouth-set-default-theme --list 2>/dev/null | grep -v "^mc$" | sed 's/^/  /' || true
            fi
            
            log_info ""
            read -p "Continue with uninstallation anyway? [y/N]: " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Uninstallation cancelled"
                exit 0
            fi
        fi
    fi
}

# Uninstall theme
uninstall_theme() {
    log_info "Uninstalling Minecraft Plymouth theme..."
    log_info "Target directories:"
    log_info "  Plymouth theme: $PLYMOUTH_THEME_BASEDIR"
    log_info "  Fonts: $FONTS_BASEDIR"
    log_info "  Font config: $FONTCONFIG_PATH"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    check_root
    check_active_theme
    
    # Remove theme directory
    if [[ -d "$PLYMOUTH_THEME_BASEDIR" ]]; then
        log_verbose "Found theme directory: $PLYMOUTH_THEME_BASEDIR"
        safe_execute "rm -rf '$PLYMOUTH_THEME_BASEDIR'" \
            "Removing Plymouth theme directory"
    else
        log_verbose "Theme directory not found: $PLYMOUTH_THEME_BASEDIR"
    fi
    
    # Remove font files
    if [[ -f "${FONTS_BASEDIR}/OTF/Minecraft.otf" ]]; then
        safe_execute "rm -f '${FONTS_BASEDIR}/OTF/Minecraft.otf'" \
            "Removing Minecraft font"
    else
        log_verbose "Font file not found: ${FONTS_BASEDIR}/OTF/Minecraft.otf"
    fi
    
    # Remove font configuration
    if [[ -f "${FONTCONFIG_PATH}/00-minecraft.conf" ]]; then
        safe_execute "rm -f '${FONTCONFIG_PATH}/00-minecraft.conf'" \
            "Removing font configuration"
    else
        log_verbose "Font config not found: ${FONTCONFIG_PATH}/00-minecraft.conf"
    fi
    
    # Remove initrd configurations
    local config_files=(
        "/etc/dracut.conf.d/99-minecraft-plymouth.conf"
        "/etc/mkinitcpio.conf.d/99-minecraft-plymouth.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            safe_execute "rm -f '$config_file'" \
                "Removing $(basename "$config_file")"
        else
            log_verbose "Config file not found: $config_file"
        fi
    done
    
    # Update font cache
    if command -v fc-cache >/dev/null 2>&1; then
        safe_execute "fc-cache -fv >/dev/null 2>&1" \
            "Updating font cache"
    else
        log_verbose "fc-cache not available, skipping font cache update"
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Theme uninstalled successfully!"
        log_info ""
        log_info "The theme has been removed from your system."
        log_info "You may need to regenerate your initrd if you haven't already:"
        
        if command -v dracut >/dev/null 2>&1; then
            log_info "  dracut -f"
        elif command -v mkinitcpio >/dev/null 2>&1; then
            log_info "  mkinitcpio -P"
        elif command -v update-initramfs >/dev/null 2>&1; then
            log_info "  update-initramfs -u"
        fi
    else
        log_info "=== DRY RUN COMPLETED ==="
    fi
}

install_initrd_configs() {
    log_info "Installing initrd configurations..."
    
    detect_plymouth_paths
    
    # Generate and install dracut configuration
    if command -v dracut >/dev/null 2>&1; then
        log_verbose "Installing dracut configuration..."
        
        local dracut_config_content
        dracut_config_content="install_items+=\" ${PLYMOUTHLIBS_PATH}/script.so ${PLYMOUTHLIBS_PATH}/${PLYMOUTHLABELLIB} ${PLYMOUTHLIBS_PATH}/text.so ${FONTS_BASEDIR}/OTF/Minecraft.otf ${FONT_PATH}/fonts.conf ${FONTCONFIG_PATH}/00-minecraft.conf \""
        
        safe_execute "install -d -m 0755 '/etc/dracut.conf.d'" \
            "Creating dracut config directory"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would write dracut config with content:"
            log_info "  $dracut_config_content"
        else
            echo "$dracut_config_content" > "/etc/dracut.conf.d/99-minecraft-plymouth.conf"
            log_verbose "✓ Dracut configuration installed"
        fi
    else
        log_verbose "Dracut not found, skipping dracut configuration"
    fi
    
    # Install mkinitcpio configuration
    if command -v mkinitcpio >/dev/null 2>&1; then
        log_verbose "Installing mkinitcpio configuration..."
        
        safe_execute "install -d -m 0755 '/etc/mkinitcpio.conf.d'" \
            "Creating mkinitcpio config directory"
            
        safe_execute "install -m 0644 '${SCRIPT_DIR}/mkinitcpio/minecraft-plymouth.conf' '/etc/mkinitcpio.conf.d/99-minecraft-plymouth.conf'" \
            "Installing mkinitcpio configuration"
    else
        log_verbose "Mkinitcpio not found, skipping mkinitcpio configuration"
    fi
}

# Main installation function
install_theme() {
    log_info "Installing Minecraft Plymouth theme..."
    log_info "Target directories:"
    log_info "  Plymouth theme: $PLYMOUTH_THEME_BASEDIR"
    log_info "  Fonts: $FONTS_BASEDIR"
    log_info "  Font config: $FONTCONFIG_PATH"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    validate_source_files
    install_fonts
    install_plymouth_theme
    generate_scaled_assets
    install_initrd_configs
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_success "Installation completed successfully!"
        log_info ""
        log_info "To activate the theme, run:"
        log_info "  plymouth-set-default-theme -R mc"
        log_info ""
        log_info "Then reboot to see the new boot screen."
    else
        log_info "=== DRY RUN COMPLETED ==="
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    # If no arguments and no sudo, show usage
    if [[ $# -eq 0 && $EUID -ne 0 ]]; then
        show_usage
        exit 1
    fi
    
    log_info "Minecraft Plymouth Theme Installer"
    log_info "=================================="
    
    check_root
    check_dependencies
    install_theme
}

# Run main function with all arguments
main "$@"
