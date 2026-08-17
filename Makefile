ARCHS = arm64 arm64e

TARGET := iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FilzaApplySandboxExt

# --- Tweak + sandbox escape ---
FilzaApplySandboxExt_FILES = Tweak.m sandbox_escape.m apfs_own.m
FilzaApplySandboxExt_FILES += FilzaInjectionPanel.m FFH4XSession.m FFH4XSecureClient.m FFH4XCrypto.m FFH4XKeychain.m
FilzaApplySandboxExt_FILES += FileReplacementService.m PatchTransaction.m

# --- mbed TLS minimal crypto subset: AES, GCM, SHA-256, MD and HKDF ---
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/aes.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/cipher.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/cipher_wrap.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/constant_time.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/gcm.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/hkdf.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/md.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/platform_util.c
FilzaApplySandboxExt_FILES += third_party/mbedtls/library/sha256.c

# --- kexploit ---
FilzaApplySandboxExt_FILES += kexploit/kexploit_opa334.m kexploit/krw.m kexploit/kutils.m kexploit/offsets.m kexploit/vnode.m

# --- utils ---
FilzaApplySandboxExt_FILES += utils/file.c utils/hexdump.c utils/process.c

# --- kpf ---
FilzaApplySandboxExt_FILES += kpf/patchfinder.m

# --- XPF ---
FilzaApplySandboxExt_FILES += XPF/src/xpf.c XPF/src/common.c XPF/src/decompress.c XPF/src/bad_recovery.c XPF/src/non_ppl.c XPF/src/ppl.c

# --- ChOma ---
FilzaApplySandboxExt_FILES += XPF/external/ChOma/src/arm64.c XPF/external/ChOma/src/Base64.c XPF/external/ChOma/src/BufferedStream.c XPF/external/ChOma/src/CodeDirectory.c XPF/external/ChOma/src/CSBlob.c XPF/external/ChOma/src/DER.c XPF/external/ChOma/src/DyldSharedCache.c XPF/external/ChOma/src/Entitlements.c XPF/external/ChOma/src/Fat.c XPF/external/ChOma/src/FileStream.c XPF/external/ChOma/src/Host.c XPF/external/ChOma/src/MachO.c XPF/external/ChOma/src/MachOLoadCommand.c XPF/external/ChOma/src/MemoryStream.c XPF/external/ChOma/src/PatchFinder.c XPF/external/ChOma/src/PatchFinder_arm64.c XPF/external/ChOma/src/Util.c

# --- Flags ---
# Build funcional: exploit somente sob demanda; hooks permanecem desativados.
FilzaApplySandboxExt_CFLAGS = -fvisibility=hidden -I$(CURDIR) -I$(CURDIR)/include -I$(CURDIR)/XPF/src -I$(CURDIR)/XPF/external/ChOma/include -I$(CURDIR)/third_party/mbedtls/include -I$(CURDIR)/third_party/mbedtls/library \
    -Wno-unused-function -Wno-unused-variable \
    -Wno-incompatible-pointer-types -Wno-incompatible-pointer-types-discards-qualifiers \
    -Wno-deprecated-declarations -Wno-nonportable-include-path -Wno-format -Wno-error=unguarded-availability-new

FilzaApplySandboxExt_CCFLAGS = $(FilzaApplySandboxExt_CFLAGS)
FilzaApplySandboxExt_LDFLAGS = -Wl,-x -Wl,-S
FilzaApplySandboxExt_OBJCFLAGS = $(FilzaApplySandboxExt_CFLAGS)
FilzaApplySandboxExt_OBJCCFLAGS = $(FilzaApplySandboxExt_CFLAGS)

FilzaApplySandboxExt_FRAMEWORKS = UIKit Foundation IOKit CoreFoundation Security
FilzaApplySandboxExt_PRIVATE_FRAMEWORKS = IOSurface
FilzaApplySandboxExt_LIBRARIES = z sandbox

FilzaApplySandboxExt_INSTALL_TARGET_PROCESSES = Filza

include $(THEOS_MAKE_PATH)/tweak.mk
