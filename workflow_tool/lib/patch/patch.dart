import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'config.dart';

class PatchRecorder {
  final String configDir;
  final String root;

  PatchRecorder({
    required this.configDir,
    required this.root,
  });

  /// Record patches from all repositories and generate configuration
  Future<PatchConfig> recordAll(List<String> repoPaths) async {
    final deps = <Dependency>[];

    for (final repoPath in repoPaths) {
      final dep = await _recordDependencyPatches(repoPath);
      if (dep != null) {
        deps.add(dep);
      }
    }

    return PatchConfig(deps: deps);
  }

  /// Record patches for a single dependency
  Future<Dependency?> _recordDependencyPatches(String repoPath) async {
    // Resolve the repository path (relative to flutter root)
    final absoluteRepoPath = p.normalize(p.join(root, repoPath));

    // Verify repository exists
    final repoDir = Directory(absoluteRepoPath);
    if (!await repoDir.exists()) {
      stderr.writeln('Warning: Repository path does not exist: $absoluteRepoPath');
      return null;
    }

    // Verify it's a git repository
    final gitDir = Directory(p.join(absoluteRepoPath, '.git'));
    if (!await gitDir.exists()) {
      stderr.writeln('Warning: Not a git repository: $absoluteRepoPath');
      return null;
    }

    print('Recording patches from $absoluteRepoPath...');

    // Check if unpatched and patched tags/branches exist
    final hasUnpatched = await _refExists(absoluteRepoPath, 'unpatched');
    final hasPatched = await _refExists(absoluteRepoPath, 'patched');

    if (!hasUnpatched || !hasPatched) {
      stderr.writeln(
          'Warning: Repository $absoluteRepoPath does not have both "unpatched" and "patched" refs. Skipping.');
      return null;
    }

    // Get commit range
    final unpatchedCommit = await _getCommitHash(absoluteRepoPath, 'unpatched');
    final patchedCommit = await _getCommitHash(absoluteRepoPath, 'patched');

    // Check if there are any differences
    final hasDiff = await _hasCommitDifference(absoluteRepoPath, unpatchedCommit, patchedCommit);

    if (!hasDiff) {
      print('No patches found for $repoPath');
      return null;
    }

    // Get list of commits between unpatched and patched
    final commits = await _getCommitList(absoluteRepoPath, unpatchedCommit, patchedCommit);

    if (commits.isEmpty) {
      print('No commits between unpatched and patched for $repoPath');
      return null;
    }

    print('Found ${commits.length} commit(s) to export');

    // Create patch directory for this dependency
    final patchDirName = _getPatchDirName(repo: repoPath, root: root);
    final patchDir = Directory(p.join(configDir, patchDirName));
    if (!await patchDir.exists()) {
      await patchDir.create(recursive: true);
    }

    // Generate patch files
    final patchFiles = <String>[];
    for (var i = 0; i < commits.length; i++) {
      final commit = commits[i];
      final patchNum = (i + 1).toString().padLeft(4, '0');
      final patchFileName = await _generatePatchFile(
        absoluteRepoPath,
        commit,
        patchDir.path,
        patchNum,
      );

      if (patchFileName != null) {
        // Store relative path from config directory
        patchFiles.add(p.join(patchDirName, patchFileName));
      }
    }

    if (patchFiles.isEmpty) {
      print('No patch files generated for $repoPath');
      return null;
    }

    return Dependency(
      path: repoPath,
      patches: patchFiles,
    );
  }

  /// Check if a git ref exists
  Future<bool> _refExists(String repoPath, String ref) async {
    final result = await Process.run(
      'git',
      ['rev-parse', '--verify', ref],
      workingDirectory: repoPath,
    );

    return result.exitCode == 0;
  }

  /// Get commit hash for a ref
  Future<String> _getCommitHash(String repoPath, String ref) async {
    final result = await Process.run(
      'git',
      ['rev-parse', ref],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to get commit hash for $ref in $repoPath');
      stderr.write(result.stderr);
      exit(1);
    }

    return (result.stdout as String).trim();
  }

  /// Check if there's a difference between two commits
  Future<bool> _hasCommitDifference(String repoPath, String commit1, String commit2) async {
    final result = await Process.run(
      'git',
      ['diff', '--quiet', commit1, commit2],
      workingDirectory: repoPath,
    );

    // Exit code 0 means no difference, 1 means there is a difference
    return result.exitCode != 0;
  }

  /// Get list of commits between two refs
  Future<List<String>> _getCommitList(String repoPath, String fromCommit, String toCommit) async {
    final result = await Process.run(
      'git',
      ['rev-list', '--reverse', '$fromCommit..$toCommit'],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to get commit list between $fromCommit and $toCommit');
      stderr.write(result.stderr);
      exit(1);
    }

    final output = (result.stdout as String).trim();
    if (output.isEmpty) {
      return [];
    }

    return output.split('\n');
  }

  /// Generate a patch file from a commit
  Future<String?> _generatePatchFile(
    String repoPath,
    String commit,
    String outputDir,
    String patchNum,
  ) async {
    // Get commit subject for filename
    final subjectResult = await Process.run(
      'git',
      ['log', '--format=%s', '-n', '1', commit],
      workingDirectory: repoPath,
    );

    if (subjectResult.exitCode != 0) {
      stderr.writeln('Error: Failed to get commit subject for $commit');
      return null;
    }

    final subject = (subjectResult.stdout as String)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final patchFileName = '$patchNum-$subject.patch';
    final patchFilePath = p.join(outputDir, patchFileName);

    // Generate patch using git format-patch
    final result = await Process.run(
      'git',
      [
        'format-patch',
        '-1',
        commit,
        '--stdout',
      ],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to generate patch for commit $commit');
      stderr.write(result.stderr);
      return null;
    }

    // Write patch to file
    final patchFile = File(patchFilePath);
    await patchFile.writeAsString(result.stdout as String);

    print('  Generated: $patchFileName');
    return patchFileName;
  }

  /// Get patch directory name from repository path
  String _getPatchDirName({required String repo, required String root}) {
    // make repo path relative to root (regardless of whether repo is relative or absolute)
    var normalized = p.relative(p.join(root, repo), from: root);

    // For root path (.), use a default name
    if (normalized == '.') {
      return 'flutter';
    }

    // Extract last component or meaningful part
    final parts = p.split(normalized);
    if (parts.isEmpty) {
      return 'patches';
    }

    // Return last part of the path as directory name
    return parts.last;
  }
}

class PatchApplier {
  final PatchConfig config;
  final String configDir;
  final String root;

  PatchApplier({
    required this.config,
    required this.configDir,
    required this.root,
  });

  /// Apply all patches from the configuration
  Future<void> applyAll() async {
    for (final dep in config.deps) {
      await _applyDependencyPatches(dep);
    }
  }

  /// Apply patches for a single dependency
  Future<void> _applyDependencyPatches(Dependency dep) async {
    // Resolve the repository path (relative to flutter root)
    final repoPath = p.normalize(p.join(root, dep.path));

    // Verify repository exists
    final repoDir = Directory(repoPath);
    if (!await repoDir.exists()) {
      stderr.writeln('Error: Repository path does not exist: $repoPath');
      exit(1);
    }

    // Verify it's a git repository
    final gitDir = Directory(p.join(repoPath, '.git'));
    if (!await gitDir.exists()) {
      stderr.writeln('Error: Not a git repository: $repoPath');
      exit(1);
    }

    print('Applying patches to $repoPath...');

    // Get current commit hash
    final currentCommit = await _getCurrentCommit(repoPath);

    // Tag the unpatched commit
    await _tagUnpatchedCommit(repoPath, currentCommit);

    // Create and checkout a new branch for patches
    await _createPatchBranch(repoPath, currentCommit);

    // Apply each patch
    for (final patchPath in dep.patches) {
      await _applyPatch(repoPath, patchPath);
    }
  }

  /// Get the current commit hash
  Future<String> _getCurrentCommit(String repoPath) async {
    final result = await Process.run(
      'git',
      ['rev-parse', 'HEAD'],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to get current commit in $repoPath');
      stderr.write(result.stderr);
      exit(1);
    }

    return (result.stdout as String).trim();
  }

  /// Tag the unpatched commit
  Future<void> _tagUnpatchedCommit(String repoPath, String commitHash) async {
    final tagName = 'unpatched';

    final result = await Process.run(
      'git',
      ['tag', '-f', tagName, commitHash],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to tag unpatched commit in $repoPath');
      stderr.write(result.stderr);
      exit(1);
    }

    print('Tagged unpatched state as $tagName');
  }

  /// Create and checkout a new branch for patches
  Future<void> _createPatchBranch(String repoPath, String commitHash) async {
    final branchName = 'patched';

    // Create branch
    var result = await Process.run(
      'git',
      ['checkout', '-B', branchName],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Error: Failed to create patch branch in $repoPath');
      stderr.write(result.stderr);
      exit(1);
    }

    print('Created and checked out branch $branchName');
  }

  /// Apply a single patch file
  Future<void> _applyPatch(String repoPath, String patchPath) async {
    // Resolve patch file path (relative to config file)
    final absolutePatchPath = p.normalize(p.join(configDir, patchPath));

    // Verify patch file exists
    final patchFile = File(absolutePatchPath);
    if (!await patchFile.exists()) {
      stderr.writeln('Error: Patch file not found: $absolutePatchPath');
      exit(1);
    }

    // Run git am
    final process = await Process.start(
      'git',
      ['am', absolutePatchPath],
      workingDirectory: repoPath,
      runInShell: false,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;

    // Exit immediately on failure
    if (exitCode != 0) {
      exit(exitCode);
    }
  }
}

/// Main entry point for the patch CLI
Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'patch',
    'Tool for applying and recording patches for dependencies.',
  )
    ..addCommand(ApplyCommand())
    ..addCommand(RecordCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

class ApplyCommand extends Command<void> {
  @override
  final name = 'apply';

  @override
  final description = 'Apply patches from a JSON configuration file to git repositories.';

  @override
  String get invocation => '${super.invocation} <config-file> <checkout-dir>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;

    if (rest.length != 2) {
      usageException('Expected exactly 2 arguments: <config-file> <checkout-dir>');
    }

    final configPath = rest[0];
    final root = rest[1];

    try {
      // Load configuration
      final config = PatchConfig.loadFromFile(configPath);

      // Get the directory containing the config file
      final configDir = p.dirname(p.absolute(configPath));

      // Verify checkout root exists
      final rootDir = Directory(root);
      if (!rootDir.existsSync()) {
        stderr.writeln('Error: Checkout directory does not exist: $root');
        exit(1);
      }

      // Apply patches
      final applier = PatchApplier(
        config: config,
        configDir: configDir,
        root: root,
      );

      await applier.applyAll();
    } on FileSystemException catch (e) {
      stderr.writeln('Error: ${e.message}: ${e.path}');
      exit(1);
    } on FormatException catch (e) {
      stderr.writeln('Error parsing configuration: ${e.message}');
      exit(1);
    }
  }
}

class RecordCommand extends Command<void> {
  @override
  final name = 'record';

  @override
  final description =
      'Record patches from repositories by comparing "unpatched" and "patched" refs.';

  @override
  String get invocation => '${super.invocation} <config-file> <checkout-dir> <repo-path>...\n\n'
      'Example:\n'
      '  patch record patches.json /path/to/checkout . engine/src/flutter/third_party/dart';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;

    if (rest.length < 3) {
      usageException('Expected at least 3 arguments: <config-file> <checkout-dir> <repo-path>...');
    }

    final configPath = rest[0];
    final root = rest[1];
    final repoPaths = rest.sublist(2);

    if (repoPaths.isEmpty) {
      usageException('At least one repository path is required.\n\n'
          'Repository paths should be relative to the checkout directory.\n'
          'Use "." for the root repository.');
    }

    try {
      // Get the directory containing the config file
      final configDir = p.dirname(p.absolute(configPath));

      // Verify checkout root exists
      final rootDir = Directory(root);
      if (!rootDir.existsSync()) {
        stderr.writeln('Error: Checkout directory does not exist: $root');
        exit(1);
      }

      // Create config directory if it doesn't exist
      final configDirObj = Directory(configDir);
      if (!configDirObj.existsSync()) {
        configDirObj.createSync(recursive: true);
      }

      // Record patches
      final recorder = PatchRecorder(
        configDir: configDir,
        root: root,
      );

      final config = await recorder.recordAll(repoPaths);

      // Save configuration
      config.saveToFile(configPath);

      print('');
      print('Successfully recorded patches to $configPath');
      print('Total dependencies: ${config.deps.length}');
    } on FileSystemException catch (e) {
      stderr.writeln('Error: ${e.message}: ${e.path}');
      exit(1);
    }
  }
}
