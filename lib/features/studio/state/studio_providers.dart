library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../drafts/draft_repository.dart';
import '../export/export_pipeline.dart';
import '../render/adapters/easy_video_editor_adapter.dart';
import '../render/adapters/pro_video_editor_adapter.dart';
import '../render/render_pipeline.dart';
import '../uploads/upload_pipeline.dart';

export '../../../core/config/app_config.dart'
    show kDemoMode, kUploadEndpoint, kAppEnv;

final renderPipelineProvider = Provider<RenderPipeline>((ref) {
  return RenderPipeline(adapters: [
    EasyVideoEditorAdapter(),
    const ProVideoEditorAdapter(),
  ]);
});

final exportPipelineProvider = Provider<ExportPipeline>((ref) {
  return ExportPipeline(renderPipeline: ref.watch(renderPipelineProvider));
});

final uploadPipelineProvider = Provider<UploadPipeline>((ref) {
  final pipeline = UploadPipeline(endpoint: kUploadEndpoint);
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final draftRepositoryProvider = Provider<DraftRepository>((ref) {
  final repo = DraftRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
