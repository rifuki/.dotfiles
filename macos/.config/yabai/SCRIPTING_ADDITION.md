# yabai Scripting Addition on macOS Sequoia

Notes on why `yabai --load-sa` fails on macOS Sequoia (15.x) on Apple Silicon and how `patch_sa.sh` fixes it.

---

## Symptoms

- Window animations do not work (`window_animation_duration` is ignored, windows snap instantly).
- Window opacity does not work (`active_window_opacity` remains 1.0).
- Running `sudo yabai --load-sa` outputs:
  ```
  could not spawn remote thread: (os/kern) protection failure
  yabai: scripting-addition failed to inject payload into Dock.app!
  ```

---

## Root Cause

This is an upstream issue in yabai v7.1.16+ running on macOS Sequoia on Apple Silicon (see [asmvik/yabai #2686](https://github.com/asmvik/yabai/issues/2686)).

Apple Silicon uses Pointer Authentication (PAC) on `arm64e` binaries. The Mach-O headers define the PAC ABI version in CPU capabilities:

- `Dock.app` on macOS Sequoia is built with PAC ABI v0 (`capabilities 0x80`).
- The `loader` binary shipped in recent yabai releases is built with a newer Clang defaulting to PAC ABI v1 (`capabilities 0x81`).

Verify with `otool`:
```bash
otool -f /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | grep capabilities
# architecture 1: capabilities 0x80

otool -f /Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader | grep capabilities
# architecture 1: capabilities 0x81
```

The macOS kernel strictly prevents an ABI v1 binary from creating a remote thread inside an ABI v0 process, resulting in `(os/kern) protection failure` even with SIP fully disabled.

---

## System Requirements

Before patching `loader`, macOS must allow injection into system processes:

1. **SIP Disabled**: Boot to Recovery Mode (hold power button on boot -> Options -> Utilities -> Terminal) and run:
   ```bash
   csrutil disable
   ```
   Note: Partial SIP (`csrutil enable --without ...`) is rejected by Sequoia for Dock injection.

2. **NVRAM boot-args**:
   ```bash
   sudo nvram boot-args="-arm64e_preview_abi"
   ```
   Requires a reboot after setting.

3. **Privacy Permissions** (System Settings -> Privacy & Security):
   - **Screen Recording**: `yabai` (required for window frame animations).
   - **Accessibility**: `yabai`.

---

## Fix: `patch_sa.sh`

The workaround modifies the Fat and Mach-O header capability bytes of `/Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader` from `0x81` to `0x80`, then applies an ad-hoc code signature.

Location: `macos/.config/yabai/patch_sa.sh`

Run once:
```bash
sudo ~/.config/yabai/patch_sa.sh
```

What the script does:
```bash
# Locate capabilities 0x81 and patch byte to 0x80
read I O <<< $(otool -f "$LOADER" | awk '/architecture/{i=$2} /capabilities 0x81/{f=1} f&&/offset/{print i, $2; exit}')
printf '\x80' | dd of="$LOADER" bs=1 seek=$((8 + I*20 + 4)) count=1 conv=notrunc 2>/dev/null
printf '\x80' | dd of="$LOADER" bs=1 seek=$((O + 11)) count=1 conv=notrunc 2>/dev/null

codesign -f -s - "$LOADER"
yabai --load-sa
```

---

## Persistence

- **Standard reboots**: No action required. The patched `loader` remains on disk at `/Library/ScriptingAdditions/yabai.osax/Contents/MacOS/loader`. `yabairc` calls `sudo yabai --load-sa` on startup, which checks version numbers and reuses the existing binary.
- **After `brew upgrade yabai`**: The brew upgrade replaces `yabai.osax` with upstream binaries. Re-run `sudo ~/.config/yabai/patch_sa.sh` once after upgrading.
