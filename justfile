default:
    @just --list

# Install, set as default theme and rebuild the initramfs
install:
    sudo ./install.sh
    sudo plymouth-set-default-theme -R mc

# Remove installed files (then pick another theme and rebuild the initramfs)
uninstall:
    sudo rm -rf /usr/share/plymouth/themes/mc
    sudo rm -f /usr/share/fonts/OTF/Minecraft.otf /etc/fonts/conf.d/00-minecraft.conf
    sudo rm -f /etc/dracut.conf.d/99-minecraft-plymouth.conf /etc/mkinitcpio.conf.d/99-minecraft-plymouth.conf
    sudo rm -f /usr/share/initramfs-tools/hooks/minecraft-font-hook

# Build the Nix package
build:
    nix build
