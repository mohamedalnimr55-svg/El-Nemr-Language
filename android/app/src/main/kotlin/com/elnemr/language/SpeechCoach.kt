package com.elnemr.language

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** One-shot, strict on-device speech recognition for language-learning exercises. */
class SpeechCoach(private val activity: MainActivity) {
    companion object { const val CHANNEL = "elnemr/speech_coach" }

    private var recognizer: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null

    fun configure(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "listen" -> {
                    val locale = call.argument<String>("locale") ?: Locale.getDefault().toLanguageTag()
                    listen(locale, result)
                }
                "stop" -> {
                    stop(null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun listen(locale: String, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Speech recognition is already active", null)
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("microphone_denied", "Microphone permission is required", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            result.error(
                "offline_unavailable",
                "Offline speech recognition is not available on this Android device. No cloud fallback was used.",
                null,
            )
            return
        }
        pending = result
        activity.runOnUiThread {
            val speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
            recognizer = speech
            speech.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onError(error: Int) {
                    finishError("recognition_error", "Offline speech recognition failed ($error)")
                }
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val best = matches?.firstOrNull()?.trim().orEmpty()
                    if (best.isEmpty()) finishError("no_speech", "No speech was recognized")
                    else finishSuccess(best)
                }
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            try {
                speech.startListening(intent)
            } catch (e: Exception) {
                finishError("start_failed", e.message ?: "Could not start offline speech recognition")
            }
        }
    }

    private fun finishSuccess(text: String) {
        val result = pending ?: return
        pending = null
        destroyRecognizer()
        result.success(text)
    }

    private fun finishError(code: String, message: String) {
        val result = pending ?: return
        pending = null
        destroyRecognizer()
        result.error(code, message, null)
    }

    private fun stop(message: String?) {
        activity.runOnUiThread {
            try { recognizer?.stopListening() } catch (_: Exception) {}
            if (message != null && pending != null) finishError("cancelled", message)
            else if (pending != null) finishError("cancelled", "Speech recognition cancelled")
            else destroyRecognizer()
        }
    }

    private fun destroyRecognizer() {
        val local = recognizer
        recognizer = null
        activity.runOnUiThread {
            try { local?.cancel() } catch (_: Exception) {}
            try { local?.destroy() } catch (_: Exception) {}
        }
    }
}
