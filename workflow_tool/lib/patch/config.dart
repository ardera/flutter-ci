import 'dart:convert';
import 'dart:io';

/// Represents a dependency with patches to apply
class Dependency {
  /// Path to the repository (relative to JSON file)
  final String path;

  /// List of patch files to apply (relative to JSON file)
  final List<String> patches;

  Dependency({
    required this.path,
    required this.patches,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'patches': patches,
    };
  }

  factory Dependency.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('path')) {
      throw FormatException('Missing required field: path');
    }
    if (!json.containsKey('patches')) {
      throw FormatException('Missing required field: patches');
    }

    final patches = json['patches'];
    if (patches is! List) {
      throw FormatException('patches must be a list');
    }

    return Dependency(
      path: json['path'] as String,
      patches: patches.map((p) => p.toString()).toList(),
    );
  }
}

/// Configuration for patch application
class PatchConfig {
  /// List of dependencies with their patches
  final List<Dependency> deps;

  PatchConfig({required this.deps});

  Map<String, dynamic> toJson() {
    return {
      'deps': deps.map((d) => d.toJson()).toList(),
    };
  }

  /// Save configuration to a JSON file
  void saveToFile(String path) {
    final file = File(path);
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(toJson());
    file.writeAsStringSync(jsonString);
  }

  factory PatchConfig.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('deps')) {
      throw FormatException('Missing required field: deps');
    }

    final deps = json['deps'];
    if (deps is! List) {
      throw FormatException('deps must be a list');
    }

    return PatchConfig(
      deps: deps.map((d) => Dependency.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }

  /// Load configuration from a JSON file
  static PatchConfig loadFromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Configuration file not found', path);
    }

    final contents = file.readAsStringSync();
    final json = jsonDecode(contents) as Map<String, dynamic>;
    return PatchConfig.fromJson(json);
  }
}
