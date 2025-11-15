import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'config.dart';

enum ApplyMode {
  apply,
  am,
}

class PatchApplier {
  final PatchConfig config;
  final String configDir;
  final String root;
  final ApplyMode mode;

  PatchApplier({
    required this.config,
    required this.configDir,
    required this.root,
    required this.mode,
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

    // Apply each patch
    for (final patchPath in dep.patches) {
      await _applyPatch(repoPath, patchPath);
    }
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

    // Determine git command based on mode
    final gitCommand = mode == ApplyMode.am ? 'am' : 'apply';

    // Run git command
    final process = await Process.start(
      'git',
      [gitCommand, absolutePatchPath],
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
    ..addFlag('apply',
        help: 'Use git apply (default)', negatable: false, defaultsTo: false)
    ..addFlag('am', help: 'Use git am', negatable: false, defaultsTo: false)
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

  // Check for required arguments: flutter-root and config file
  if (argResults.rest.length < 3) {
    stderr.writeln('Error: Missing required arguments');
    _printUsage(parser);
    exit(1);
  }

  final root = argResults.rest[1];
  final configPath = argResults.rest[2];

  // Determine apply mode
  final useAm = argResults['am'] as bool;
  final useApply = argResults['apply'] as bool;

  if (useAm && useApply) {
    stderr.writeln('Error: Cannot specify both --am and --apply');
    exit(1);
  }

  final mode = useAm ? ApplyMode.am : ApplyMode.apply;

  try {
    // Load configuration
    final config = PatchConfig.loadFromFile(configPath);

    // Get the directory containing the config file
    final configDir = p.dirname(p.absolute(configPath));

    // Verify flutter root exists
    final rootDir = Directory(root);
    if (!rootDir.existsSync()) {
      stderr.writeln('Error: Root directory does not exist: $root');
      exit(1);
    }

    // Apply patches
    final applier = PatchApplier(
      config: config,
      configDir: configDir,
      root: root,
      mode: mode,
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
  print('Apply patches from a JSON configuration file to git repositories.');
  print('');
  print('Arguments:');
  print('  config-file Path to the JSON configuration file');
  print('  checkout    Path to the gclient project checkout checkout');
  print('');
  print('Options:');
  print(parser.usage);
}
