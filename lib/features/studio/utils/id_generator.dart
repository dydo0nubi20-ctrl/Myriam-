import 'package:uuid/uuid.dart';

class IdGenerator {
  const IdGenerator._();

  static const Uuid _uuid = Uuid();

  static String newLayer() => 'layer_${_uuid.v4()}';
  static String newTrack() => 'track_${_uuid.v4()}';
  static String newSource() => 'source_${_uuid.v4()}';
  static String newProject() => 'project_${_uuid.v4()}';
  static String newExport() => 'export_${_uuid.v4()}';
  static String newUpload() => 'upload_${_uuid.v4()}';
  static String newDraft() => 'draft_${_uuid.v4()}';
}
