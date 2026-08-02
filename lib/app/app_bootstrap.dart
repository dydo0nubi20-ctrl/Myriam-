import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../features/studio/state/studio_providers.dart';

class AppBootstrap {
  Future<ProviderContainer> compose() async {
    await _startBackgroundDownloader();
    final container = ProviderContainer();
    await _warmUpDraftStore(container);
    return container;
  }

  Future<void> _startBackgroundDownloader() async {
    try {
      await FileDownloader().start();
      AppLogger.d('background_downloader started');
    } catch (e, st) {
      AppLogger.w('background_downloader failed to start', error: e, stack: st);
    }
  }

  Future<void> _warmUpDraftStore(ProviderContainer container) async {
    try {
      await container.read(draftRepositoryProvider).initialize();
      AppLogger.d('draft repository warmed up');
    } catch (e, st) {
      AppLogger.w('draft repository failed to initialize', error: e, stack: st);
    }
  }
}
