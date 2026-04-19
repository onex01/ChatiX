import 'dart:io';
import 'dart:ui';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/logger/app_logger.dart';

class AudioPlayerService {
  static AudioPlayerService get I => GetIt.I<AudioPlayerService>();

  final _audioPlayer = AudioPlayer();
  final _logger = GetIt.I<AppLogger>();

  // Стримы для UI
  Stream<bool> get isPlayingStream => _audioPlayer.playingStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<MediaItem?> get currentMediaItemStream => _audioPlayer.sequenceStateStream
      .map((state) => state?.currentSource?.tag as MediaItem?);

  final _currentTitle = BehaviorSubject<String?>();
  Stream<String?> get currentTitleStream => _currentTitle.stream;

  bool _initialized = false;

  /// Инициализация (вызвать один раз в main.dart)
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Настройка фона и уведомления
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.rizz.app.audio',
        androidNotificationChannelName: 'Воспроизведение аудио',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        notificationColor: const Color(0xFF6B46C2), // deepPurple
        artDownscaleWidth: 512,
        preloadArtwork: true,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      );

      // Обработка завершения трека
      _audioPlayer.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _audioPlayer.stop();
          _currentTitle.add(null);
        }
      });

      _logger.info('AudioPlayerService initialized');
      _initialized = true;
    } catch (e, stack) {
      _logger.error('Failed to init AudioPlayerService', error: e, stack: stack);
    }
  }

  /// Воспроизведение песни из профиля (URL)
  Future<void> playUrl(
    String url, {
    required String title,
    String? artist,
    String? albumArtUrl,
  }) async {
    try {
      final mediaItem = MediaItem(
        id: url,
        title: title,
        artist: artist ?? 'Rizz',
        artUri: albumArtUrl != null ? Uri.parse(albumArtUrl) : null,
      );

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: mediaItem),
      );

      _currentTitle.add(title);
      await _audioPlayer.play();
    } catch (e, stack) {
      _logger.error('playUrl failed', error: e, stack: stack);
    }
  }

  /// Воспроизведение голосового сообщения (локальный файл)
  Future<void> playVoice(String filePath, {String? title}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.warning('Voice file not found: $filePath');
        return;
      }

      final mediaItem = MediaItem(
        id: filePath,
        title: title ?? 'Голосовое сообщение',
        artist: 'Rizz',
      );

      await _audioPlayer.setAudioSource(
        AudioSource.file(filePath, tag: mediaItem),
      );

      _currentTitle.add(title ?? 'Голосовое');
      await _audioPlayer.play();
    } catch (e, stack) {
      _logger.error('playVoice failed', error: e, stack: stack);
    }
  }

  Future<void> pause() => _audioPlayer.pause();
  Future<void> resume() => _audioPlayer.play();
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTitle.add(null);
  }

  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  /// Текущая позиция (для прогресс-бара)
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;

  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _currentTitle.close();
  }
}