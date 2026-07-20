import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/studio/state/studio_providers.dart';

class AppBootstrap {
  Future<ProviderContainer> compose() async {
    // background_downloader needs `.start()` before any enqueue call so it
    // can restore tasks that were in-flight when the app was last killed,
    // and so it has time to set up the WorkManager / URLSession config
    // before the first upload is enqueued.
    await FileDownloader().start();

    final container = ProviderContainer();

    // Warm up the SQLite file so the first draft save doesn't stall the
    // export screen. This is cheap (just opens the file and runs any
    // pending migrations).
    await container.read(draftRepositoryProvider).initialize();

    return container;
  }
}
