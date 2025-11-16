import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'config.dart';

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
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', help: 'Show usage information', negatable: false);

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(1);
  }

  if (argResults['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  // Check for the 'apply' command
  if (argResults.rest.isEmpty || argResults.rest.first != 'apply') {
    stderr.writeln('Error: Missing command. Expected: apply');
    _printUsage(parser);
    exit(1);
  }

  // Check for required arguments: config file and checkout path
  if (argResults.rest.length < 3) {
    stderr.writeln('Error: Missing required arguments');
    _printUsage(parser);
    exit(1);
  }

  final configPath = argResults.rest[1];
  final root = argResults.rest[2];

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
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print(
      'Usage: dart run workflow_tool:patch apply <config-file> <checkout> [options]');
  print('');
  print(
      'Apply patches from a JSON configuration file to git repositories using git am.');
  print('');
  print('Arguments:');
  print('  config-file  Path to the JSON configuration file');
  print('  checkout     Path to the project checkout directory');
  print('');
  print('Options:');
  print(parser.usage);
}
