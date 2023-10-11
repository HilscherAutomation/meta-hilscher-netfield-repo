#!/bin/bash -e

get_machine_detail() {
	if grep -q "^#@${2}: " "${1}"; then
		grep "^#@${2}: " "${1}" | cut -d ':' -f2- | sed -e 's/^[ ]*//g'
	else
		echo "${3}"
	fi
}

# Parse netfield-machines
doListMachines() {
	for bsplayer in meta-hilscher-netfield-*/; do
		bsplayer=$(echo "$bsplayer" | sed -e 's@/$@@')
		platform=$(echo "$bsplayer" | rev | cut -d '-' -f1 | rev)
		for machine_conf in $(find -L "$bsplayer"/conf/machine -maxdepth 1 -name '*.conf' -type f); do
			machine=$(basename "$machine_conf" | sed -e 's/.conf//g')
			machineList="${platform}:${machine} $machineList"
		done
	done
	machineList="$(echo "$machineList" | sed -s 's/ /\n/g')"
	machineList="$(echo "$machineList" | sort)"

	echo "$machineList"
}

# Query user which machine to prepare
machines=$(doListMachines)

while [ -z "$machine_nr" ]; do
	idx=0
	for mach in $machines; do
		platform=$(echo "$mach" | cut -d ':' -f1)
		machine=$(echo "$mach" | cut -d ':' -f2)
		machine_conf="meta-hilscher-netfield-${platform}/conf/machine/${machine}.conf"

		name=$(get_machine_detail "$machine_conf" "NAME" "$machine")
		descr=$(get_machine_detail "$machine_conf" "DESCRIPTION" "")
		echo "$((idx+1)): $machine - $name"
		[ -n "$descr" ] && echo "   $descr"
		idx=$((idx + 1))
	done

	read -r -p "Please select a machine from list [1-$idx]: " machine_nr
	if [ "$machine_nr" -ne 0 ]; then
		if [ "$machine_nr" -gt $idx ]; then
			out of range
			machine_nr=""
		fi
	else
		# not an integer
		machine_nr=""
	fi
done

selected_machine=$(echo "$machines" | tr ' ' '\n' | head -n "$machine_nr" | tail -1)
platform=$(echo "$selected_machine" | cut -d ':' -f1)
machine=$(echo "$selected_machine" | cut -d ':' -f2)

echo "---------------------------"
echo "Selection:"
echo "  Platform: $platform"
echo "  Machine:  $machine"
builddir="build_${platform}_${machine}"
templateconf="../meta-hilscher-netfield-$platform/conf/samples"

# Adjust local.overrides.conf
TEMPLATECONF="$templateconf" source ./poky/oe-init-build-env "${builddir}"
cd ..

sed -i '/^#?MACHINE/d' "${builddir}"/conf/local.conf

cat <<EOF>"${builddir}"/conf/local.overrides.conf

MACHINE ?= "${machine}"
FIRMWARE_VERSION="0.0.0.0"
HILSCHER_DEPLOY_ROOT_DIR="\${TOPDIR}/dist"
BBMASK += "meta-hilscher-netfield/recipes-devtools/cockpit/cockpit_dev.bb"
EOF

keys_dir="${builddir}/keys/${machine}/boot"
mkdir -p "${keys_dir}"

# Generate platform keys
echo "*** Generating platform keys ***"
if [ "$platform" = "intel" ]; then
	echo 'KEYS_DIR="${TOPDIR}/keys"' >> "${builddir}"/conf/local.overrides.conf
	if ! which sign-efi-sig-list cert-to-efi-sig-list; then
		echo "!!! Error generating platform keys !!!"
		echo "EFI tools (sign-efi-sig-list cert-to-efi-sig-list) needed to UEFI key generation are missing on the system"
		echo "Please install them or create required keys and UEFI auth files manually"
		echo ""
		echo "Example: sudo apt install efitools"
		exit 1
	fi

	echo "Calling 'meta-hilscher-netfield-intel/scripts/keygen_uefi.sh' to generate UEFI keys"
	meta-hilscher-netfield-intel/scripts/keygen_uefi.sh
	mv uefi/*.key uefi/*.crt* "${keys_dir}"
	ln -s boot ${builddir}/keys/${machine}/uefi

	mkdir -p meta-hilscher-netfield-intel/recipes-core/initrdscripts/initramfs-netfield/"$machine"
	mv uefi/*.auth meta-hilscher-netfield-intel/recipes-core/initrdscripts/initramfs-netfield/"$machine"
	rmdir uefi

	echo "NOTE: .auth files have been placed in folder meta-hilscher-netfield-intel/recipes-core/initrdscripts/initramfs-netfield/$machine/"
	echo "NOTE2: You may need to add a platform_init in the same folder"
else
	if [ "$platform" = "imx8" ]; then
		echo 'PLATFORM_KEYDIR="${KEYS_DIR}"' >> "${builddir}"/conf/local.overrides.conf
		echo 'KEYS_DIR="${TOPDIR}/keys/${MACHINE}/boot"' >> "${builddir}"/conf/local.overrides.conf
		keyname="boot"
	else
		echo 'PLATFORM_KEYDIR="${KEYS_DIR}/boot"' >> "${builddir}"/conf/local.overrides.conf
		echo 'KEYS_DIR="${TOPDIR}/keys"' >> "${builddir}"/conf/local.overrides.conf
		keyname="db"
	fi

	openssl req -new -x509 -newkey rsa:4096 -keyout "${keys_dir}"/${keyname}.key \
		-out "${keys_dir}"/${keyname}.crt -days 10950 -nodes -sha256 \
		-subj '/CN=Debug keys'
	openssl x509 -outform der -in "${keys_dir}"/${keyname}.crt -out "${keys_dir}"/${keyname}.crt.der
fi

if [ "$platform" = "imx8" ]; then
	echo "If you want to use high assurance boot (HAB) you need to manually adopt 'meta-hilscher-netfield-imx8/meta-hab'"
	echo " and add hab to MACHINE_FEATURES"
	echo ""
	echo " See 'meta-hilscher-netfield-imx8/meta-hab/recipes-hab/cst/hab-signature.bb' for an example"
fi
