#!/usr/bin/env bash

PLYMOUTH_THEME_BASEDIR=/usr/share/plymouth/themes/mc
FONTCONFIG_PATH=/etc/fonts/conf.d/

# Check for ImageMagick
which convert >/dev/null 2>&1
[[ $? -ne 0 ]] && \
	echo "Please install ImageMagick ('convert' command)" && \
	exit 1

# Copy font config
cp -v ./font/config/* ${FONTCONFIG_PATH}
# Copy font
cp -v ./font/Minecraft.otf /usr/share/fonts/OTF/

# Copy plymouth theme
mkdir ${PLYMOUTH_THEME_BASEDIR}
cp -vr ./plymouth/mc.script ${PLYMOUTH_THEME_BASEDIR}
cp -vr ./plymouth/mc.plymouth ${PLYMOUTH_THEME_BASEDIR}
cp -vr ./plymouth/progress_bar.png ${PLYMOUTH_THEME_BASEDIR}
cp -vr ./plymouth/progress_box.png ${PLYMOUTH_THEME_BASEDIR}

# Create smaller versions of assets
for j in "padlock" "bar"; do
	mkdir ${PLYMOUTH_THEME_BASEDIR}/${j}
	for i in $(seq 1 6); do
		convert ./plymouth/${j}.png -interpolate Nearest -filter point -resize "$i"00% ${PLYMOUTH_THEME_BASEDIR}/${j}/"${i}".png
	done
done	

mkdir ${PLYMOUTH_THEME_BASEDIR}/dirt
for i in $(seq 1 12); do
	convert -channel R -evaluate multiply .2509803922 -channel G -evaluate multiply .2509803922 -channel B -evaluate multiply .2509803922 ./plymouth/dirt.png -interpolate Nearest -filter point -resize "$i"00% ${PLYMOUTH_THEME_BASEDIR}/dirt/"${i}".png
done

# Install dracut config
cp -v ./dracut/* /etc/dracut.conf.d/99-minecraft-plymouth.conf
