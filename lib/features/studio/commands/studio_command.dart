library;

import '../entities/project.dart';

/// Result of executing or undoing a [StudioCommand].
sealed class CommandResult {
  final StudioProject project;
  final String? message;
  const CommandResult(this.project, this.message);
}

class CommandSuccess extends CommandResult {
  const CommandSuccess(super.project, [super.message]);
}

class CommandFailure extends CommandResult {
  final Object error;
  const CommandFailure(super.project, this.error, [super.message]);
}

/// Every mutation to a [StudioProject] goes through a [StudioCommand] so
/// it can be undone/redone deterministically. Commands must be pure with
/// respect to the project they're given — any "what was there before"
/// state needed for undo is captured the first time [execute] runs.
abstract interface class StudioCommand {
  String get commandId;
  String get label;

  /// Mergeable commands (e.g. dragging a trim handle) collapse into the
  /// previous identical-type command instead of growing the undo stack
  /// by one entry per pixel of drag.
  bool get isMergeable => false;

  CommandResult execute(StudioProject project);
  CommandResult undo(StudioProject project);
}

/// Bundles several commands into a single undo-able step (e.g. "add clip
/// + create its track" should undo together).
class MacroCommand implements StudioCommand {
  MacroCommand({required this.commandId, required this.label, required this.commands});

  @override
  final String commandId;
  @override
  final String label;
  final List<StudioCommand> commands;

  @override
  bool get isMergeable => false;

  @override
  CommandResult execute(StudioProject project) {
    var current = project;
    for (final c in commands) {
      final r = c.execute(current);
      if (r is CommandFailure) return r;
      current = r.project;
    }
    return CommandSuccess(current, label);
  }

  @override
  CommandResult undo(StudioProject project) {
    var current = project;
    for (final c in commands.reversed) {
      final r = c.undo(current);
      if (r is CommandFailure) return r;
      current = r.project;
    }
    return CommandSuccess(current, 'Undo: $label');
  }
}
