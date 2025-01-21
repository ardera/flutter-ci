const kRunnerImage = 'os';
const kRunnerImageNice = 'os-nice';
const kBuildEngine = 'build-engine';
const kBuildUniversal = 'build-universal';
const kFlavor = 'flavor';
const kRuntimeMode = 'runtime-mode';
const kUnoptimized = 'unoptimized';
const kNoStripped = 'nostripped';
const kSplitDebugSymbols = 'split-debug-symbols';
const kArtifactName = 'artifact-name';
const kCPU = 'cpu';
const kArmCPU = 'arm-cpu';
const kArmTune = 'arm-tune';
const kBuildX64GenSnapshot = 'build-x64-gen-snapshot';
const kBuildARMGenSnapshot = 'build-arm-gen-snapshot';
const kBuildARM64GenSnapshot = 'build-arm64-gen-snapshot';
const kBuildRISCV64GenSnapshot = 'build-riscv64-gen-snapshot';
const kX64GenSnapshotPath = 'x64-gen-snapshot-path';
const kARMGenSnapshotPath = 'arm-gen-snapshot-path';
const kARM64GenSnapshotPath = 'arm64-gen-snapshot-path';
const kRISCV64GenSnapshotPath = 'riscv64-gen-snapshot-path';
const kJobName = 'job-name';

enum GithubRunner {
  ubuntuLatest('ubuntu-latest', 'Linux', OS.linux),
  macosLatest('macos-latest', 'MacOS', OS.macOS, arch: Arch.arm64),
  macos13('macos-13', 'MacOS', OS.macOS, arch: Arch.x64),
  windowsLatest('windows-latest', 'Windows', OS.windows);

  const GithubRunner(this.name, this.nice, this.os, {this.arch = Arch.x64});

  final String name;
  final String nice;
  final OS os;
  final Arch arch;

  @override
  String toString() => name;
}

enum OS {
  macOS,
  linux,
  windows;

  @override
  String toString() {
    return name;
  }
}

enum Bitness {
  bits32('32-bits'),
  bits64('64-bits');

  const Bitness(this.name);

  final String name;

  @override
  String toString() {
    return name;
  }
}

enum Arch {
  riscv64.bits64('RISCV64', 'riscv64', 'riscv64'),
  x64.bits64('X64', 'x64', 'x64'),
  arm.bits32('ARM', 'arm', 'armv7'),
  arm64.bits64('ARM64', 'arm64', 'aarch64');

  const Arch.bits32(this.ghActionsName, this.flutterCpu, this.ciName)
      : bitness = Bitness.bits32;

  const Arch.bits64(this.ghActionsName, this.flutterCpu, this.ciName)
      : bitness = Bitness.bits64;

  final String ghActionsName;
  final String flutterCpu;
  final String ciName;
  final Bitness bitness;

  @override
  String toString() => ciName;
}

enum CPU {
  generic('generic', 'generic'),
  pi3('cortex-a53+nocrypto', 'cortex-a53'),
  pi4('cortex-a72+nocrypto', 'cortex-a72');

  const CPU(this.compilerCpu, this.cmopilerTune);

  final String compilerCpu;
  final String cmopilerTune;

  @override
  String toString() => name;
}

enum Target {
  armv7Generic(
    arch: Arch.arm,
    name: 'armv7-generic',
    triple: 'armv7-linux-gnueabihf',
  ),
  aarch64Generic(
    arch: Arch.arm64,
    name: 'aarch64-generic',
    triple: 'aarch64-linux-gnu',
  ),
  x64Generic(
    arch: Arch.x64,
    name: 'x64-generic',
    triple: 'x86_64-linux-gnu',
  ),
  pi3(
    arch: Arch.arm,
    cpu: CPU.pi3,
    name: 'pi3',
    triple: 'armv7-linux-gnueabihf',
  ),
  pi3_64(
    arch: Arch.arm64,
    cpu: CPU.pi3,
    name: 'pi3-64',
    triple: 'aarch64-linux-gnu',
  ),
  pi4(
    arch: Arch.arm,
    cpu: CPU.pi4,
    name: 'pi4',
    triple: 'armv7-linux-gnueabihf',
  ),
  pi4_64(
    arch: Arch.arm64,
    cpu: CPU.pi4,
    name: 'pi4-64',
    triple: 'aarch64-linux-gnu',
  ),
  riscv64(
    arch: Arch.riscv64,
    name: 'riscv64-generic',
    triple: 'riscv64-linux-gnu',
  );

  const Target({
    this.os = OS.linux,
    required this.arch,
    this.cpu = CPU.generic,
    required this.name,
    required this.triple,
  });

  final OS os;
  final Arch arch;
  final CPU cpu;
  final String name;

  final String triple;
  String get compilerCpu => cpu.compilerCpu;

  @override
  String toString() => name;
}

enum RuntimeMode {
  debug(false),
  profile(true),
  release(true);

  const RuntimeMode(this.isAOT);

  final bool isAOT;

  @override
  String toString() => name;
}

enum Flavor {
  debugUnopt('debug_unopt', RuntimeMode.debug, true),
  debug('debug', RuntimeMode.debug, false),
  profile('profile', RuntimeMode.profile, false),
  release('release', RuntimeMode.release, false);

  const Flavor(
    this.name,
    this.runtimeMode,
    this.unoptimized,
  );

  final String name;
  final RuntimeMode runtimeMode;
  final bool unoptimized;

  bool get buildGenSnapshot => runtimeMode.isAOT;

  @override
  String toString() => name;
}

Map<String, Object> genTargetConfig(Target target) {
  return {
    kArtifactName: target.toString(),
    kCPU: target.arch.flutterCpu,

    /// TODO: add arm64_cpu and arm64_tune
    if (target.arch == Arch.arm || target.arch == Arch.arm64) ...{
      kArmCPU: target.cpu.compilerCpu,
      kArmTune: target.cpu.cmopilerTune,
    }
  };
}

Map<String, Object> genEngineConfig(Flavor flavor) {
  return {
    kBuildEngine: true,
    kFlavor: flavor.toString(),
    kRuntimeMode: flavor.runtimeMode.toString(),
    kUnoptimized: flavor.unoptimized,
    kSplitDebugSymbols: true,
    kNoStripped: true,
  };
}

Map<String, Object> genRunnerConfig(GithubRunner runner) {
  return {
    kRunnerImage: runner.name,
    kRunnerImageNice: runner.nice,
  };
}

Map<String, Object> genGenSnapshotConfig(
  RuntimeMode mode, {
  required GithubRunner runner,
  required Target target,
}) {
  assert(mode.isAOT);

  return {
    kFlavor: switch (mode) {
      RuntimeMode.profile => Flavor.profile,
      RuntimeMode.release => Flavor.release,
      _ => throw StateError('Invalid runtime mode: $mode')
    }
        .toString(),
    kRuntimeMode: mode.toString(),

    // We can only cross-compile the gen_snapshots on linux right now.
    // MacOS still supports building the gen_snapshot for the host only.

    // Normally, gen_snapshot can only compile code for architectures that
    // match the host "bitness" (e.g. 32-bit or 64-bit).
    //
    // However, there's an exception for arm (32-bit), so all 64-bit architectures
    // can generate code for arm (32-bit).
    //
    // See: https://github.com/dart-lang/sdk/blob/main/runtime/platform/globals.h#L340
    //
    // There's no exception for arm (32-bit) targetting aarch64 or x64 though.
    // So the ARM (32-bit) host gen_snapshot can only be built when targetting
    // armv7 as well.
    kBuildARMGenSnapshot: (runner.os == OS.linux && target.arch == Arch.arm) ||
        runner.arch == Arch.arm,
    kBuildARM64GenSnapshot: runner.os == OS.linux || runner.arch == Arch.arm64,
    kBuildX64GenSnapshot: runner.os == OS.linux || runner.arch == Arch.x64,
    kBuildRISCV64GenSnapshot:
        runner.os == OS.linux || runner.arch == Arch.riscv64,

    kARMGenSnapshotPath: runner.os == OS.linux && target.arch == Arch.arm
        ? 'gen_snapshot'
        : runner.os == OS.windows
            ? 'gen_snapshot/gen_snapshot.exe'
            : 'clang_arm/gen_snapshot',
    kARM64GenSnapshotPath: runner.os == OS.linux && target.arch == Arch.arm64
        ? 'gen_snapshot'
        : runner.os == OS.windows
            ? 'gen_snapshot/gen_snapshot.exe'
            : 'clang_arm64/gen_snapshot',
    kX64GenSnapshotPath: runner.os == OS.linux && target.arch == Arch.x64
        ? 'gen_snapshot'
        : runner.os == OS.windows
            ? 'gen_snapshot/gen_snapshot.exe'
            : 'clang_x64/gen_snapshot',
    kRISCV64GenSnapshotPath:
        runner.os == OS.linux && target.arch == Arch.riscv64
            ? 'gen_snapshot'
            : runner.os == OS.windows
                ? 'gen_snapshot/gen_snapshot.exe'
                : 'clang_riscv64/gen_snapshot',
  };
}

Object generateMatrix() {
  final jobs = <Map<String, dynamic>>[];

  void addJob(Map<String, dynamic> job) {
    jobs.add(job);
  }

  final targets = Target.values;

  final flavors = Flavor.values;
  final runtimeModes = RuntimeMode.values;
  final aotRuntimeModes = runtimeModes.where((mode) => mode.isAOT).toList();
  final runners = {
    GithubRunner.ubuntuLatest,
    GithubRunner.macos13,
    GithubRunner.windowsLatest
  };

  for (final target in targets) {
    final targetConfig = genTargetConfig(target);

    // For the tuned targets, we only build the profile and release mode engine.
    // Doesn't make sense to have a tuned version for a debug build.
    final flavorsToBuild =
        target.cpu == CPU.generic ? flavors : [Flavor.profile, Flavor.release];

    for (final flavor in flavorsToBuild) {
      // add the engine build job for that target

      // if we're building for generic CPUs, additionally build the gen_snapshot.
      final buildGenSnapshot =
          target.cpu == CPU.generic && flavor.buildGenSnapshot;

      if (buildGenSnapshot) {
        // win => risc-v gen_snapshot is currently not working, so exclude that.
        final selectedRunners = switch (target.arch) {
          Arch.riscv64 => runners.where((r) => r.os != OS.windows),
          _ => runners,
        };

        for (final runner in selectedRunners) {
          // Only build the engine on the linux runner.
          final buildEngine = runner.os == OS.linux;

          if (buildEngine) {
            addJob({
              kJobName:
                  'build engine, gen_snapshot (for: $target, flavor: $flavor, host: ${runner.os})',
              ...targetConfig,
              ...genEngineConfig(flavor),
              ...genGenSnapshotConfig(
                flavor.runtimeMode,
                runner: runner,
                target: target,
              ),
              ...genRunnerConfig(runner),
            });
          } else {
            addJob({
              kJobName:
                  'build gen_snapshot (for: $target, flavor: $flavor, host: ${runner.os})',
              ...targetConfig,
              ...genGenSnapshotConfig(
                flavor.runtimeMode,
                runner: runner,
                target: target,
              ),
              ...genRunnerConfig(runner),
            });
          }
        }
      } else {
        addJob({
          kJobName: 'build engine (for: $target, flavor: $flavor)',
          ...targetConfig,
          ...genEngineConfig(flavor),
          ...genRunnerConfig(GithubRunner.ubuntuLatest),
        });
      }
    }
  }

  // add a job that builds the universal artifacts (flutter_embedder.h,
  // icudtl.dat)
  addJob({
    kJobName: 'build universal artifacts',
    kArtifactName: 'universal',
    ...genRunnerConfig(GithubRunner.ubuntuLatest),
    kNoStripped: false,
    kBuildEngine: false,
    kBuildARMGenSnapshot: false,
    kBuildARM64GenSnapshot: false,
    kBuildX64GenSnapshot: false,
    kBuildRISCV64GenSnapshot: false,
    kBuildUniversal: true,
    kSplitDebugSymbols: false,
  });

  return jobs;
}
