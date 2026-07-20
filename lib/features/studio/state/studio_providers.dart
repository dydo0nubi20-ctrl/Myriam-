library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../drafts/draft_repository.dart';
import '../export/export_pipeline.dart';
import '../render/adapters/easy_video_editor_adapter.dart';
import '../render/adapters/pro_video_editor_adapter.dart';
import '../render/render_pipeline.dart';
import '../uploads/upload_pipeline.dart';

/// Replace with your real backend's media-upload endpoint. Left as an
/// obvious placeholder URL (not a fabricated "working" one) on purpose —
/// `background_downloader` will simply get an HTTP error from this host
/// until you point it at your own API, and that failure will show up
/// honestly in the upload progress UI instead of silently "succeeding".
const String kUploadEndpoint = 'https://api.your-backend.example.com/v1/posts/media';

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
