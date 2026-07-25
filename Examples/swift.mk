HEAP_SIZE      = 8388208
STACK_SIZE     = 61800

# Locate the Playdate SDK
SDK = ${PLAYDATE_SDK_PATH}
ifeq ($(SDK),)
SDK = $(shell sed -nE 's/^[[:space:]]*SDKRoot[[:space:]]+//p' ~/.Playdate/config | head -n 1)
endif

ifeq ($(SDK),)
$(error SDK path not found; set ENV value PLAYDATE_SDK_PATH)
endif

include $(SDK)/C_API/buildsupport/common.mk

# Determine the Swift toolchain by order of preference:
#
# 1. the presence of a TOOLCHAINS environment value
# 2. a Swift toolchain installed for the current user (e.g. 'Install for me only')
# 3. a Swift toolchain installed for all users (e.g. 'Install for all users on this computer')
RELATIVE_TOOLCHAIN_PATH = Library/Developer/Toolchains/swift-latest.xctoolchain
ifneq ($(TOOLCHAINS),)
else ifneq ($(wildcard $(HOME)/$(RELATIVE_TOOLCHAIN_PATH)),)
TOOLCHAINS = $(shell plutil -extract CFBundleIdentifier raw -o - $(HOME)/$(RELATIVE_TOOLCHAIN_PATH)/Info.plist)
else ifneq ($(wildcard /$(RELATIVE_TOOLCHAIN_PATH)),)
TOOLCHAINS = $(shell plutil -extract CFBundleIdentifier raw -o - /$(RELATIVE_TOOLCHAIN_PATH)/Info.plist)
else
$(error Swift toolchain not found; set ENV value TOOLCHAINS (e.g. TOOLCHAINS=org.swift.59202403121a make))
endif

# Note: paths containing spaces are not supported (make word-splits them).
GCC_INCLUDE_PATHS := $(shell $(CC) -E -Wp,-v -xc /dev/null 2>&1 | egrep '^ ' | xargs echo )
ifeq ($(GCC_INCLUDE_PATHS),)
$(error arm-none-eabi C headers not found; install the Arm GNU toolchain and ensure $(CC) is runnable)
endif

SWIFT_EXEC := "$(shell TOOLCHAINS=$(TOOLCHAINS) xcrun -f swiftc)"
# With an unknown TOOLCHAINS id, xcrun silently falls back to Xcode's swiftc,
# which lacks the Embedded ARM stdlib; fail early with a clear message.
ifeq ($(findstring .xctoolchain,$(SWIFT_EXEC)),)
$(error swiftc for toolchain "$(TOOLCHAINS)" not found (xcrun returned $(SWIFT_EXEC)); install a swift.org toolchain or set TOOLCHAINS)
endif
TOOLCHAIN_PATH := $(shell echo $(SWIFT_EXEC)|sed s'/.xctoolchain.*/.xctoolchain/')

$(info Using Swift toolchain "$(TOOLCHAINS)" (from $(TOOLCHAIN_PATH)))

# Optimization mode for Swift compiles. -Osize targets small code, which
# suits the device's flash/RAM budget (measured 15% smaller than -O on the
# HelloPlaydate example); override per-build for maximum speed instead:
# `make SWIFT_OPT=-O`. For larger games, appending
# `-Xfrontend -mergeable-symbols -Xfrontend -mergeable-traps` lets the
# linker deduplicate stdlib code specialized into both the wrapper and the
# game module.
SWIFT_OPT ?= -Osize

C_FLAGS := \
	$(addprefix -I ,$(GCC_INCLUDE_PATHS)) \

SWIFT_FLAGS := \
	$(addprefix -Xcc , $(C_FLAGS)) \
	$(SWIFT_OPT) \
	-wmo -enable-experimental-feature Embedded \
	-Xfrontend -disable-stack-protector \
	-Xfrontend -function-sections \
	-swift-version 6 \
	-Xcc -DTARGET_EXTENSION \
	-module-cache-path build/module-cache \
	-I $(SDK)/C_API \
	-I build/Modules \
	-I $(REPO_ROOT)/Sources/CPlaydate \

C_FLAGS_DEVICE := \
	-mthumb \
	-mcpu=cortex-m7 \
	-mfloat-abi=hard \
	-mfpu=fpv5-sp-d16 \
	-D__FPU_USED=1 \
	-falign-functions=16 \
	-fshort-enums \

SWIFT_FLAGS_DEVICE := \
	$(addprefix -Xcc , $(C_FLAGS_DEVICE)) \
	-target armv7em-none-none-eabi \
	-Xfrontend -experimental-platform-c-calling-convention=arm_aapcs_vfp \
	-module-alias PlaydateKit=playdate_device \

C_FLAGS_SIMULATOR := \

SWIFT_FLAGS_SIMULATOR := \
	$(addprefix -Xcc , $(C_FLAGS_SIMULATOR)) \
	-module-alias PlaydateKit=playdate_simulator \

SIMCOMPILER += \
	-nostdlib \
	-dead_strip \
	-Wl,-exported_symbol,_eventHandlerShim \
	-Wl,-exported_symbol,_eventHandler \
