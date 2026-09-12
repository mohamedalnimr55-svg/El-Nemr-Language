#!/usr/bin/env python3
from pathlib import Path
import re, sys
R=Path(__file__).resolve().parents[1]
errors=[]

def text(rel): return (R/rel).read_text(errors='replace')
def need(rel,*patterns):
    s=text(rel)
    for p in patterns:
        if re.search(p,s,re.M|re.S) is None: errors.append(f'{rel}: missing {p}')
def forbid(rel,*patterns):
    s=text(rel)
    for p in patterns:
        if re.search(p,s,re.M|re.S): errors.append(f'{rel}: forbidden {p}')

# First-run profile really gates the app.
need('lib/app.dart', r'LearnerProfileStore\.load', r'onboardingComplete', r'LearningOnboardingScreen')
need('lib/learning/screens/onboarding_screen.dart', r'What is your main language\?', r'What do you want to learn\?', r'A1', r'C2', r'goals', r'genres')

# Offline media -> audio -> transcript -> translation chain.
need('lib/screens/player_screen.dart', r'_maybeAutoPrepareLearningSubs', r'_autoPrepareLearningVideo', r'TranscriptionService', r'OnDeviceTranslationService', r'_learningMediaSource', r'content://')
need('lib/learning/services/transcription_service.dart', r'AudioExtractionService', r'OfflineSpeechModelService', r'Whisper\(', r'isNoTimestamps:\s*false', r'diarize:\s*false')
need('lib/learning/services/audio_extraction_service.dart', r'elnemr/audio_extractor')
need('lib/learning/services/audio_extraction_service.dart', r'prepareSource', r'httpHeaders', r'allowSelfSigned', r'Directory\.systemTemp\.createTemp', r'await prepared\.dispose\(\)')
need('lib/screens/player_screen.dart', r'httpHeaders: _current\.httpHeaders', r'allowSelfSigned: _current\.allowSelfSigned')
need('android/app/src/main/kotlin/com/elnemr/language/SpeechCoach.kt', r'createOnDeviceSpeechRecognizer', r'isOnDeviceRecognitionAvailable', r'EXTRA_PREFER_OFFLINE')
need('ios/Runner/AppDelegate.swift', r'requiresOnDeviceRecognition = true', r'supportsOnDeviceRecognition')
forbid('ios/Runner/MediaProbe.swift', r'AVURLAssetHTTPHeaderFieldsKey')
need('ios/Runner/MediaProbe.swift', r'probeCustomSource', r'WebDAVClient\.shared\.makeByteRangeSource', r'FtpClient\.makeByteRangeSource')
need('android/app/src/main/kotlin/com/elnemr/language/MediaProbe.kt', r'HttpRangeMediaDataSource', r'PlayerCodecs\.httpDataSourceFactory', r'FtpRangeMediaDataSource')
forbid('lib/screens/tmd_details_screen.dart', r'probeViaTempDownload\(uri\)')
need('lib/learning/services/offline_speech_model_service.dart', r'downloadModel', r'whisper_models', r'Base · ~142 MB')
need('lib/learning/screens/offline_ai_setup_screen.dart', r'Prepare offline learning', r'Core learning works without API keys')
need('android/app/src/main/kotlin/com/elnemr/language/AudioExtractor.kt', r'MediaExtractor', r'MediaCodec', r'16000')
need('ios/Runner/AppDelegate.swift', r'AVAssetReader', r'16000', r'elnemr/audio_extractor')
forbid('lib/learning/services/transcription_service.dart', r'LEARNING_ASR_ENDPOINT', r'MultipartRequest', r'api\.openai\.com')

# Multi-subtitle is user-facing, not just a model.
need('lib/screens/player_screen.dart', r'MultiSubtitleOverlay', r'Learning subtitles ·', r'\+ Add another subtitle…', r'Generate from video audio · local', r'_learningLayers')
need('lib/learning/widgets/multi_subtitle_overlay.dart', r'onScale', r'locked')
need('lib/learning/models/subtitle_layer.dart', r'delayMs', r'position - Duration\(milliseconds: delayMs\)')

# Five-mode contract and independent automation.
need('lib/learning/models/learning_models.dart', r'enum LearningMode\s*\{\s*watch,\s*learn,\s*listening,\s*speak,\s*test\s*\}')
forbid('lib/learning/models/learning_models.dart', r'shadow|rolePlay|smartCoach')
need('lib/learning/widgets/learning_studio_sheet.dart', r'Immersion Auto', r'Smart Coach', r'Role Play', r'Shadow')

# Long-term learning loop.
need('lib/learning/widgets/learning_studio_sheet.dart', r'VocabularyStore', r'LocalLanguageCoach', r'SpeechAssessment')
need('lib/learning/services/vocabulary_store.dart', r'VocabularyGrade', r'dueAt', r'intervalDays', r'ease')
need('lib/screens/settings_screen.dart', r'Daily Review', r'No API key required', r'Optional online services')

# Local modern Android access.
need('android/app/src/main/kotlin/com/elnemr/language/MediaScanner.kt', r'ContentUris\.withAppendedId')
need('android/app/src/main/kotlin/com/elnemr/language/FileBrowser.kt', r'ACTION_OPEN_DOCUMENT_TREE')
forbid('android/app/src/main/AndroidManifest.xml', r'MANAGE_EXTERNAL_STORAGE')

forbid('lib/screens/home_screen.dart', r'_showTmdbHintOnce', r'Enter your free TMDB API key')
forbid('lib/screens/opensubtitles_sheet.dart', r'Missing OPENSUBTITLES_API_KEY')

# Discovery/recommendations are connected to UI.
need('lib/screens/discover_screen.dart', r'AI picks for you|Recommended for you|recommend', r'learning|target', r'taste|genre')
need('lib/screens/local_screen.dart', r'Auto Learning Subtitles', r'Open Files|Open files', r'Scan')

if errors:
    print('FEATURE WIRING AUDIT FAILED')
    for e in errors: print('-',e)
    sys.exit(1)
print('FEATURE WIRING AUDIT PASS')
