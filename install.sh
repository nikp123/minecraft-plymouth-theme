#!/usr/bin/env bash

PLYMOUTH_THEME_BASEDIR=${PLYMOUTH_THEME_BASEDIR:=/usr/share/plymouth/themes/mc}
FONTS_BASEDIR=${FONTS_BASEDIR:=/usr/share/fonts}
FONT_PATH=${FONT_PATH:=/etc/fonts}
FONTCONFIG_PATH=${FONTCONFIG_PATH:=${FONT_PATH}/conf.d}

# Check for ImageMagick
which magick >/dev/null 2>&1
[[ $? -ne 0 ]] && \
	echo "Please install ImageMagick ('magick' command)" && \
	exit 1

# Copy font config
cp -v ./font/config/* ${FONTCONFIG_PATH}
# Copy font
install -v -d -m 0755 /usr/share/fonts/OTF/
install -v -m 0644 ./font/Minecraft.otf /usr/share/fonts/OTF/

# Copy plymouth theme
install -v -d -m 0755 ${PLYMOUTH_THEME_BASEDIR}
install -v -m 0644 ./plymouth/mc.script ${PLYMOUTH_THEME_BASEDIR}
install -v -m 0644 ./plymouth/mc.plymouth ${PLYMOUTH_THEME_BASEDIR}
install -v -m 0644 ./plymouth/progress_bar.png ${PLYMOUTH_THEME_BASEDIR}
install -v -m 0644 ./plymouth/progress_box.png ${PLYMOUTH_THEME_BASEDIR}

# Create smaller versions of assets
for j in "padlock" "bar"; do
	for i in $(seq 1 6); do
		magick ./plymouth/${j}.png -interpolate Nearest -filter point -resize "$i"00% ${PLYMOUTH_THEME_BASEDIR}/${j}-"${i}".png
	done
done	

for i in $(seq 1 12); do
	magick ./plymouth/dirt.png -channel R -evaluate multiply .2509803922 -channel G -evaluate multiply .2509803922 -channel B -evaluate multiply .2509803922 -interpolate Nearest -filter point -resize "$i"00% ${PLYMOUTH_THEME_BASEDIR}/dirt-"${i}".png
done

# Install dracut config
PLYMOUTHLIBS_PATH=${PLYMOUTHLIBS_PATH:=/usr/lib/plymouth/}

if [ ! -d ${PLYMOUTHLIBS_PATH} ]; then
    PLYMOUTHLIBS_PATH=/usr/lib64/plymouth
fi

if [ ! -d ${PLYMOUTHLIBS_PATH} ]; then
    echo "Please install Plymouth (On Fedora, plymouth-plugin-script)" && \
    exit 1
fi

PLYMOUTHLABELLIB=${PLYMOUTHLABELLIB:=label.so}

if [ ! -e ${PLYMOUTHLIBS_PATH}/${PLYMOUTHLABELLIB} ]; then
    PLYMOUTHLABELLIB=label-pango.so
fi

echo -e "install_items+=\" ${PLYMOUTHLIBS_PATH}/script.so ${PLYMOUTHLIBS_PATH}/${PLYMOUTHLABELLIB} ${PLYMOUTHLIBS_PATH}/text.so ${FONTS_BASEDIR}/OTF/Minecraft.otf ${FONT_PATH}/fonts.conf ${FONTCONFIG_PATH}/00-minecraft.conf \"\n" > ./dracut/99-minecraft-plymouth.conf

install -v -d -m 0755 /etc/dracut.conf.d
install -v -m 0644 ./dracut/* /etc/dracut.conf.d/99-minecraft-plymouth.conf

# Install mkinitcpio config
install -v -d -m 0755 /etc/mkinitcpio.conf.d
install -v -m 0644 ./mkinitcpio/* /etc/mkinitcpio.conf.d/99-minecraft-plymouth.conf
