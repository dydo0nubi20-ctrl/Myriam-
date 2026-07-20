library;

import '../entities/project.dart';
import 'studio_command.dart';

class HistorySnapshot {
  final int undoCount;
  final int redoCount;
  const HistorySnapshot({required this.undoCount, required this.redoCount});

  bool get canUndo => undoCount > 0;
  bool get canRedo => redoCount > 0;

  static const empty = HistorySnapshot(undoCount: 0, redoCount: 0);
}

class ExecutionResult {
  final StudioProject project;
  final bool success;
  final String? message;
  const ExecutionResult({required this.project, required this.success, this.message});
}

/// Linear undo/redo stack. Kept intentionally simple (no tree/branching
/// history) because that's what every mainstream video editor's "undo"
/// button actually does — branching history adds real complexity for a
/// feature almost nobody discovers.
class HistoryEngine {
  HistoryEngine({this.maxSize = 100});

  final int maxSize;
  final List<StudioCommand> _undoStack = [];
  final List<StudioCommand> _redoStack = [];

  HistorySnapshot snapshot() =>
      HistorySnapshot(undoCount: _undoStack.length, redoCount: _redoStack.length);

  ExecutionResult apply(StudioProject project, StudioCommand command) {
    final result = command.execute(project);
    if (result is CommandFailure) {
      return ExecutionResult(project: project, success: false, message: result.message);
    }

    if (command.isMergeable &&
        _undoStack.isNotEmpty &&
        _undoStack.last.runtimeType == command.runtimeType) {
      _undoStack.removeLast();
    } else {
      _redoStack.clear();
    }
    _undoStack.add(command);
    while (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }

    return ExecutionResult(project: result.project, success: true, message: result.message);
  }

  ExecutionResult undo(StudioProject project) {
    if (_undoStack.isEmpty) {
      return ExecutionResult(project: project, success: false, message: 'Nothing to undo');
    }
    final command = _undoStack.removeLast();
    final result = command.undo(project);
    if (result is CommandFailure) {
      _undoStack.add(command);
      return ExecutionResult(project: project, success: false, message: result.message);
    }
    _redoStack.add(command);
    return ExecutionResult(
      project: result.project,
      success: true,
      message: result.message ?? 'Undo: ${command.label}',
    );
  }

  ExecutionResult redo(StudioProject project) {
    if (_redoStack.isEmpty) {
      return ExecutionResult(project: project, success: false, message: 'Nothing to redo');
    }
    final command = _redoStack.removeLast();
    final result = command.execute(project);
    if (result is CommandFailure) {
      _redoStack.add(command);
      return ExecutionResult(project: project, success: false, message: result.message);
    }
    _undoStack.add(command);
    return ExecutionResult(
      project: result.project,
      success: true,
      message: result.message ?? 'Redo: ${command.label}',
    );
  }

  void reset() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
