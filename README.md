# flutter engine binaries for armv7, aarch64, x64

This repo contains flutter engine binaries (in the https://github.com/ardera/flutter-engine-binaries-for-arm filesystem layout) for armv7 and aarch64.
The binaries come in variants: generic, and tuned for the Pi 3, Pi 4, and Pi 5 CPUs.

# 📦 Downloads

### **See [Releases](https://github.com/ardera/flutter_embedded/releases).**

*NOTE*: Some SDK versions, e.g. 3.19.1 are missing. In most cases, that means that SDK uses the same engine as the older release, so 3.19.0 in this case.
The SDK semantic versions are only provided because they're a bit nicer to read than the raw engine commit hashes, but the engine commits are still the "single source of truth"

# 🛠️ Build Config and Compiler Invocation
## Build Config
The engine build is configured with: [^2]
```
$ ./src/flutter/tools/gn \
  --runtime-mode <debug / profile / release> \
  [--unoptimized]
  --target-os linux \
  --linux-cpu <arm / arm64 / x64> \
  [--arm-float-abi hard] \
  --target-dir build \
  --embedder-for-target \
  --disable-desktop-embeddings \
  --no-build-glfw-shell \
  --no-build-embedder-examples \
  --no-goma
```

After that, the following args are added to the `args.gn` file for armv7/aarch64 without any CPU-specific tuning:
```
arm_cpu = "generic"
arm_tune = "generic"
```

When tuning for pi 3:
```
arm_cpu = "cortex-a53+nocrypto"
arm_tune = "cortex-a53"
```

When tuning for pi 4:
```
arm_cpu = "cortex-a72+nocrypto"
arm_tune = "cortex-a72"
```

When tuning for pi 5:
```
arm_cpu = "cortex-a76"
arm_tune = "cortex-a76"
```

For both armv7 and aarch64, the engine is built against the sysroot provided by the engine build scripts, which is some debian sid sysroot from 2020.
(See https://github.com/flutter/buildroot/blob/master/build/linux/sysroot_scripts/install-sysroot.py)

## Compiler Invocation
This will result in the clang compiler being invoked with the following args:

| artifact        | compiler arguments                                                           |
| --------------- | ---------------------------------------------------------------------------- |
| armv7-generic   | `--target=armv7-linux-gnueabihf    -mcpu=generic             -mtune=generic`    |
| pi4             | `--target=armv7-linux-gnueabihf    -mcpu=cortex-a72+nocrypto -mtune=cortex-a72`[^1] |
| pi3             | `--target=armv7-linux-gnueabihf    -mcpu=cortex-a53+nocrypto -mtune=cortex-a53`[^3] |
| aarch64-generic | `--target=aarch64-linux-gnu        -mcpu=generic             -mtune=generic`    |
| pi4-64          | `--target=aarch64-linux-gnu        -mcpu=cortex-a72+nocrypto -mtune=cortex-a72`[^1] |
| pi5-64          | `--target=aarch64-linux-gnu        -mcpu=cortex-a76          -mtune=cortex-a76`     |
| pi3-64          | `--target=aarch64-linux-gnu        -mcpu=cortex-a53+nocrypto -mtune=cortex-a53`[^3] |
| x64-generic     | `--target=x86_64-unknown-linux-gnu -mcpu=generic             -mtune=generic` |

## Debug Symbols

Some modifications are made to the engine build scripts so it's always built with `-ggdb -fdebug-default-version=4`.
The debug symbols are then split into a separate file using:
```bash
$ objcopy --only-keep-debug libflutter_engine.so libflutter_engine.so.dbgsyms
$ objcopy --strip-debug libflutter_engine.so
$ objcopy --add-gnu-debuglink=libflutter_engine.{debug/profile/release/debug_unopt}.dbgsyms libflutter_engine.so
```

That means you can just later download the debug symbols when you need them and step through the engine source code.

However, the resulting `libflutter_engine.so` is ~4MBs larger than one that has _all_ (not only debug symbols) stripped.
So, if you want to save a few more megabytes you can strip them using:
```bash
objcopy --strip-unneeded libflutter_engine.so
```

[^1]: The CPU of the Raspberry Pi 4 is a Cortex-A72. `+nocrypto` is specified for `-mcpu` because the A72 in the Pi 4 is (_apparently_) the only A72 in the world that doesn't support cryptography instructions: https://github.com/ardera/flutter-ci/issues/3#issuecomment-1272330857

[^3]: Pi 3 doesn't support cryptography extensions either.

[^2]: `--arm-float-abi hard` is only specified when building for armv7, `--unoptimized` is only specified for unoptimized debug builds.
