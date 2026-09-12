import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../models/library_video.dart';
import '../models/video_item.dart';
import '../services/continue_watching.dart';
import '../services/file_browser.dart';
import '../services/native_media_scanner.dart';
import '../services/subtitle_prefs.dart';
import '../utils/file_info_extractor.dart';
import '../widgets/el_nemr_brand.dart';
import 'file_browser_screen.dart';
import 'tmd_details_screen.dart';

class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key, this.refreshTick});

  final Listenable? refreshTick;

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen>
    with AutomaticKeepAliveClientMixin {
  bool _autoLearningSubs = true;
  bool _scanning = false;
  List<LibraryVideo> _deviceVideos = const [];
  List<ContinueWatchingEntry> _recent = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refreshTick?.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    widget.refreshTick?.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _load() async {
    final auto = await SubtitlePrefs.loadAutoLearning();
    final recent = await ContinueWatchingStore.load();
    if (!mounted) return;
    setState(() {
      _autoLearningSubs = auto;
      _recent = recent.where((entry) {
        final video = entry.video;
        final uri = video.uri ?? '';
        return video.path != null ||
            uri.startsWith('file:') ||
            uri.startsWith('content:');
      }).take(8).toList(growable: false);
    });
  }

  Future<void> _refresh() async {
    await _load();
    if (Platform.isAndroid && _deviceVideos.isNotEmpty) {
      await _scanDevice();
    }
  }

  Future<void> _toggleAutoLearning(bool value) async {
    setState(() => _autoLearningSubs = value);
    await SubtitlePrefs.saveAutoLearning(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Auto learning subtitles are on. Missing text will be generated from the video audio locally.'
              : 'Auto learning subtitles are off.',
        ),
      ),
    );
  }

  Future<void> _openFiles() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FileBrowserScreen()),
    );
    await _load();
  }

  Future<void> _importVideo() async {
    if (Platform.isIOS) {
      final picked = await FileBrowserService.instance.openFilesHome();
      if (picked == null || !mounted) return;
      await _openVideo(_videoFromFileEntry(picked));
      return;
    }
    await _openFiles();
  }

  Future<void> _scanDevice() async {
    if (!Platform.isAndroid) {
      await _openFiles();
      return;
    }
    setState(() => _scanning = true);
    final videos = await NativeMediaScanner.instance.scanAll();
    if (!mounted) return;
    videos.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    setState(() {
      _deviceVideos = videos.take(60).toList(growable: false);
      _scanning = false;
    });
    if (videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No videos found yet. Check storage/video permission or use Open Files.'),
        ),
      );
    }
  }

  Future<void> _openVideo(VideoItem video) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TmdDetailsScreen(video: video),
      ),
    );
    await _load();
  }

  VideoItem _videoFromLibrary(LibraryVideo video) {
    final info = extractFileInfo(video.title);
    final isContentUri = video.path.startsWith('content://');
    return VideoItem(
      id: 'local_media_${video.id}',
      title: video.title,
      path: isContentUri ? null : video.path,
      uri: isContentUri ? video.path : null,
      resumeKey: video.path,
      duration: Duration(milliseconds: video.duration),
      sizeBytes: video.sizeBytes,
      resolution: video.resolutionLabel.isEmpty ? null : video.resolutionLabel,
      videoCodec: info.videoCodec,
      audioCodec: info.audioCodec,
      audioChannels: info.audioChannels,
      audioLanguage: info.audioLanguage,
      fps: info.fps,
    );
  }

  VideoItem _videoFromFileEntry(FileEntry entry) {
    final isContentUri = entry.path.startsWith('content://');
    final info = extractFileInfo(entry.name);
    return VideoItem(
      id: 'local_file_${entry.path.hashCode}',
      title: entry.name,
      path: isContentUri ? null : entry.path,
      uri: isContentUri ? entry.path : null,
      resumeKey: entry.resumeKey ?? entry.path,
      duration: Duration.zero,
      sizeBytes: entry.size,
      videoCodec: info.videoCodec,
      audioCodec: info.audioCodec,
      audioChannels: info.audioChannels,
      audioLanguage: info.audioLanguage,
      resolution: info.resolution,
      fps: info.fps,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: const PageStorageKey('local-screen-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 72,
              title: const ElNemrBrandLockup(compact: true),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Play your own files and turn them into language lessons.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LocalActionCard(
                      icon: Icons.folder_open_rounded,
                      title: 'Open Files',
                      subtitle: 'Browse folders, storage, Files app and providers',
                      onTap: _openFiles,
                    ),
                    _LocalActionCard(
                      icon: Icons.video_file_rounded,
                      title: 'Import Video',
                      subtitle: Platform.isIOS
                          ? 'Choose a video from the iOS Files app'
                          : 'Choose any video from your device',
                      onTap: _importVideo,
                    ),
                    _LocalActionCard(
                      icon: Icons.manage_search_rounded,
                      title: Platform.isAndroid ? 'Scan Device' : 'Browse Device',
                      subtitle: Platform.isAndroid
                          ? 'Find videos on your phone automatically'
                          : 'Open local and cloud files from Files',
                      onTap: _scanDevice,
                      trailing: _scanning
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: SwitchListTile.adaptive(
                        value: _autoLearningSubs,
                        onChanged: _toggleAutoLearning,
                        secondary: const Icon(Icons.subtitles_rounded),
                        title: const Text(
                          'Auto Learning Subtitles',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'When needed, extract the video audio, transcribe it locally, and build learning translations. No API key required.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_recent.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Recent local videos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                  final entry = _recent[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: const CircleAvatar(
                      child: Icon(Icons.play_arrow_rounded),
                    ),
                    title: Text(
                      entry.video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Resume at ${_time(entry.position)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openVideo(entry.video),
                  );
                  },
                  childCount: _recent.length,
                ),
              ),
            ],
            if (_deviceVideos.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Found on this phone',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text('${_deviceVideos.length} videos'),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                  final video = _deviceVideos[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF24D6FF), Color(0xFF7C4DFF)],
                        ),
                      ),
                      child: const Icon(Icons.movie_rounded, color: Colors.white),
                    ),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (video.resolutionLabel.isNotEmpty) video.resolutionLabel,
                        if (video.duration > 0)
                          _time(Duration(milliseconds: video.duration)),
                      ].join(' • '),
                    ),
                    onTap: () => _openVideo(_videoFromLibrary(video)),
                  );
                  },
                  childCount: _deviceVideos.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  String _time(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _LocalActionCard extends StatelessWidget {
  const _LocalActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF24D6FF).withValues(alpha: 0.95),
                      scheme.primary,
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
