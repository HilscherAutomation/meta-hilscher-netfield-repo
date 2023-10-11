# Introduction

netFIELDOS is a IoT specific Yocto BSP build for dunfell.

It basically consists of:
 * u-boot bootloader
 * Microsoft azure iot-edge runtime
 * docker
 * DeviceManager/Cockpit for local device management

A hardware specific adaptation must be provided. This BSP contains following examples for such an adaptation:
 * meta-hilscher-netfield-intel: For Intel based platform that are UEFI ready
 * meta-hilscher-netfield-raspberrypi: For RPI3 based devices. See Hilscher niot-e-tpi51-en-re
 * meta-hilscher-netfield-imx8: Compulab IOT-GATE-IMX8 and ucm-imx8mm based devices

It contains the following layers (see git submodules for used revisions)

| URL                                                 | Notes                                     |
|-----------------------------------------------------|-------------------------------------------|
| https://github.com/compulab-yokneam/meta-bsp-imx8mm | Used for Compulab i.MX8MM based devices   |
| https://github.com/kraj/meta-clang                  | Required for meta-rust                    |
| https://git.yoctoproject.org/meta-freescale         | Used for NXP-based devices (e.g. i.MX8MM) |
| https://git.yoctoproject.org/meta-gplv2             | Used to avoid GPLv3 in images             |
| https://git.yoctoproject.org/meta-intel             | Used for Intel (amd64) based devices      |
| https://github.com/openembedded/meta-openembedded   | Contains recipes for most common tools    |
| https://git.yoctoproject.org/meta-raspberrypi       | Used for RaspberryPI based devices        |
| https://git.yoctoproject.org/meta-security          | Used for security application             |
| https://github.com/sbabic/meta-swupdate             | Used for providing software updates       |
| https://git.yoctoproject.org/poky                   | Base build layer                          |

# Building

## Setup build environment

It is recommended to start the environment inside docker, but you can decide to use your own yocto setup.

```
./start_dockerenv.sh
```

### Scripted/automated approach

Just call the provided setup.sh and select the appropriate platform. This will create all required keys and a build directory.
Build as used to:

```
source poky/oe-init-build-env <builddir>
MACHINE=<machine> bitbake netfield-image
```

### Manual approach

To setup a machine specific build directory use the standard yocto approach using a templateconf, provided by the following machine specific BSP layers:
 * meta-hilscher-netfield-intel
 * meta-hilscher-netfield-raspberrypi
 * meta-hilscher-netfield-imx8

Example:
```
TEMPLATECONF="../meta-hilscher-netfield-raspberrypi/conf/samples" source poky/oe-init-build-env
```

You need to generate an RSA key pair and proper certificates for your machine (one time only):

Example for RPI3 based gateways:
```
mkdir -p ../meta-hilscher-netfield-raspberrypi/keys/niot-e-tpi51-en-re/
cd ../meta-hilscher-netfield-raspberrypi/keys/niot-e-tpi51-en-re/
openssl req -new -x509 -newkey rsa:4096 -keyout boot.key -out boot.crt -days 10950 -nodes -sha256
openssl x509 -outform der -in boot.crt -out boot.crt.der
cd -
```

*NOTE:* Keep them in a secure place and have a copy and a safe place.
*NOTE2:* For intel platforms, which are using uefi you can use the provided script "meta-hilscher-netfield-intel/scripts/keygen_uefi.sh" as reference.

Adjust your build directory to:
 * Use the locally provided sources
 * Set a correct firmware version
 * Set a specific deploy directory
 * Use your generated keys

Add the following to _build/conf/local.overrides.conf_
```
FIRMWARE_VERSION="0.0.0.0"
HILSCHER_DEPLOY_ROOT_DIR="${TOPDIR}/dist"
KEYS_DIR="${TOPDIR}/keys"
BBMASK += "meta-hilscher-netfield/recipes-devtools/cockpit/cockpit_dev.bb"

# PLATFORM_KEYDIR may depend on platform
PLATFORM_KEYDIR="${KEYS_DIR}/boot"
```

## Start build
```
MACHINE=niot-e-tpi51-en-re bitbake netfield-image
```

Your final artifacts will be stored in "${TOPDIR}/dist"
