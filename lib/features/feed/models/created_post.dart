library;

/// What the studio hands back to the feed via `context.pop(CreatedPost(...))`
/// once a post has actually finished uploading. The feed is expected to
/// optimistically insert this at the top of the timeline rather than
/// re-fetching — `url` is the real, already-uploaded media URL returned
/// by your backend's upload endpoint.
class CreatedPost {
  final String url;
  final String caption;
  final List<String> hashtags;
  final List<String> mentions;
  final bool isVideo;
  final String? localThumbnailPath;

  const CreatedPost({
    required this.url,
    this.caption = '',
    this.hashtags = const [],
    this.mentions = const [],
    this.isVideo = true,
    this.localThumbnailPath,
  });
}
