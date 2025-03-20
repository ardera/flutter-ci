import 'package:workflow_tool/workflow_tool.dart';
import 'package:test/test.dart';

import 'all_of_or_none.dart';
import 'contains_at_most_one.dart';

void main() {
  final anyDebugFlavor = anyOf('debug_unopt', 'debug');
  final anyTunedArtifact = anyOf('pi3', 'pi3-64', 'pi4', 'pi4-64');

  test('only build profile & release engines for cpu-tuned targets', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      isNot(contains(allOf(
        containsPair('os', anything),
        containsPair('artifact-name', anyTunedArtifact),
        containsPair('flavor', anyDebugFlavor),
      ))),
    );
  });

  test('don\t build gen_snapshot for cpu-tuned targets', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      isNot(contains(allOf(
        containsPair('os', anything),
        containsPair('artifact-name', anyTunedArtifact),
        containsPair('build-gen-snapshot', true),
      ))),
    );
  });

  test('don\t build gen_snapshot for debug engines', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      isNot(contains(allOf(
        containsPair('os', anything),
        containsPair('runtime-mode', 'debug'),
        containsPair('build-gen-snapshot', true),
      ))),
    );
  });

  test('all targets have a release and profile mode engine', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      containsAll([
        for (final artifact in [
          'pi3',
          'pi3-64',
          'pi4',
          'pi4-64',
          'armv7-generic',
          'aarch64-generic',
          'x64-generic',
          'riscv64-generic',
        ]) ...[
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'release'),
          ),
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'profile'),
          )
        ]
      ]),
    );
  });

  test('all generic targets have a release and profile mode gen_snapshot', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      containsAll([
        for (final artifact in [
          'armv7-generic',
          'aarch64-generic',
          'x64-generic',
          'riscv64-generic',
        ]) ...[
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('runtime-mode', 'release'),
            containsPair('build-x64-gen-snapshot', true),
          ),
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('runtime-mode', 'profile'),
            containsPair('build-x64-gen-snapshot', true),
          )
        ]
      ]),
    );
  });

  test(
      'all generic targets have a debug, debug_unopt, release and profile mode engine',
      () {
    final matrix = generateMatrix();

    expect(
      matrix,
      containsAll([
        for (final artifact in [
          'armv7-generic',
          'aarch64-generic',
          'x64-generic',
          'riscv64-generic',
        ]) ...[
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'debug_unopt'),
          ),
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'debug'),
          ),
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'release'),
          ),
          allOf(
            containsPair('artifact-name', artifact),
            containsPair('flavor', 'profile'),
          )
        ]
      ]),
    );
  });

  test('all gen_snaphots are built from macos and linux', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      containsAll([
        for (final artifact in [
          'armv7-generic',
          'aarch64-generic',
          'x64-generic',
          'riscv64-generic',
        ])
          for (final runtimeMode in ['release', 'profile'])
            for (final os in ['macos-13', 'ubuntu-latest'])
              allOf(
                containsPair('artifact-name', artifact),
                containsPair('runtime-mode', runtimeMode),
                containsPair('build-x64-gen-snapshot', true),
                containsPair('os', os),
              ),
      ]),
    );
  });

  test('every flavor has an equivalent runtime-mode set', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      everyElement(allOf(
        allOfOrNone(
          containsPair('flavor', anyOf('debug_unopt', 'debug')),
          containsPair('runtime-mode', 'debug'),
        ),
        allOfOrNone(
          containsPair('flavor', 'profile'),
          containsPair('runtime-mode', 'profile'),
        ),
        allOfOrNone(
          containsPair('flavor', 'release'),
          containsPair('runtime-mode', 'release'),
        ),
      )),
    );
  });

  test('only one build for each artifact-name, flavor and host os', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      allOf([
        // These are all the combinations the engine is built for.
        // There is not necessarily a MacOS job for every engine build,
        //   on MacOS we only build gen_snapshot, so debug_unopt and debug
        //   won't have a MacOS runner.
        for (final artifact in [
          'armv7-generic',
          'aarch64-generic',
          'x64-generic',
          'riscv64-generic',
          'pi3',
          'pi3-64',
          'pi4',
          'pi4-64',
        ])
          for (final flavor in ['debug_unopt', 'debug', 'release', 'profile'])
            for (final os in ['ubuntu-latest', 'macos-13'])
              containsAtMostOne(allOf(
                containsPair('os', os),
                containsPair('artifact-name', artifact),
                containsPair('flavor', flavor),
              )),
      ]),
    );
  });

  test('unoptimized is only set for debug_unopt', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      everyElement(allOf(
        allOfOrNone(
          allOf(
            containsPair('build-engine', true),
            containsPair('flavor', 'debug_unopt'),
          ),
          containsPair('unoptimized', true),
        ),
        allOfOrNone(
          allOf(
            containsPair('build-engine', true),
            containsPair('flavor', anyOf('debug', 'profile', 'release')),
          ),
          containsPair('unoptimized', false),
        ),
      )),
    );
  });

  test('no-stripped is set for every engine build', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      everyElement(
        allOfOrNone(
          containsPair('build-engine', true),
          containsPair('nostripped', true),
        ),
      ),
    );
  });

  test(
      'arm-cpu, arm-tune are set for every build targetting arm/arm64, unset otherwise',
      () {
    final matrix = generateMatrix();

    expect(
      matrix,
      everyElement(
        allOfOrNone(
          containsPair('cpu', anyOf('arm', 'arm64')),
          containsPair('arm-cpu',
              anyOf('generic', 'cortex-a53+nocrypto', 'cortex-a72+nocrypto')),
          containsPair(
              'arm-tune', anyOf('generic', 'cortex-a53', 'cortex-a72')),
        ),
      ),
    );
  });

  test('any engine build job is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      anyElement(
        containsPair('build-engine', true),
      ),
    );
  });

  test('any x64 host gen_snapshot build job is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      anyElement(
        containsPair('build-x64-gen-snapshot', true),
      ),
    );
  });

  test('any arm host gen_snapshot build job is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      anyElement(
        containsPair('build-arm-gen-snapshot', true),
      ),
    );
  });

  test('any arm64 host gen_snapshot build job is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      anyElement(
        containsPair('build-arm64-gen-snapshot', true),
      ),
    );
  });

  test('any riscv64 host gen_snapshot build job is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      anyElement(
        containsPair('build-riscv64-gen-snapshot', true),
      ),
    );
  });

  test('every job has a known runner image set', () {
    final matrix = generateMatrix();

    final anyKnownRunnerImage =
        anyOf('ubuntu-latest', 'macos-latest', 'macos-13', 'windows-latest');

    expect(
      matrix,
      everyElement(allOf(
        containsPair('os', anyKnownRunnerImage),
        containsPair('os-nice', anyOf('Linux', 'MacOS', 'Windows')),
      )),
    );
  });

  test('every job has a job name', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      everyElement(
        allOf(
          containsPair(
            'job-name',
            isA<String>(),
          ),
        ),
      ),
    );
  });

  test('every arch is present', () {
    final matrix = generateMatrix();

    expect(
      matrix,
      allOf([
        for (final arch in ['arm', 'arm64', 'x64', 'riscv64'])
          anyElement(
            containsPair('cpu', arch)
          )
      ])
    );
  });
}
