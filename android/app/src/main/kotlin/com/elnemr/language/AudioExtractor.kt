package com.elnemr.language

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max

class AudioExtractor(private val context: Context) {
    companion object { const val CHANNEL = "elnemr/audio_extractor" }

    fun configure(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "extractToWav" -> {
                    val source = call.argument<String>("source")
                    val language = call.argument<String>("preferredLanguage")
                    if (source.isNullOrBlank()) {
                        result.error("NO_SOURCE", "No media source provided", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val output = extract(source, language)
                            context.mainExecutor.execute { result.success(output.absolutePath) }
                        } catch (e: Exception) {
                            context.mainExecutor.execute {
                                result.error("EXTRACT_FAILED", e.message ?: e.javaClass.simpleName, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extract(source: String, preferredLanguage: String?): File {
        val extractor = MediaExtractor()
        try {
            setSource(extractor, source)
            val track = chooseAudioTrack(extractor, preferredLanguage)
                ?: error("No decodable audio track was found in this media")
            extractor.selectTrack(track.first)
            val inputFormat = track.second
            val mime = inputFormat.getString(MediaFormat.KEY_MIME) ?: error("Audio MIME type is missing")
            val decoder = MediaCodec.createDecoderByType(mime)
            val output = File(context.cacheDir, "elnemr_audio_${System.currentTimeMillis()}.wav")
            try {
                // Request a stable 16-bit PCM decoder output. Some codecs may
                // still expose float PCM, which decodeToWav handles below.
                inputFormat.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                decoder.configure(inputFormat, null, null, 0)
                decoder.start()
                decodeToWav(extractor, decoder, inputFormat, output)
            } finally {
                try { decoder.stop() } catch (_: Exception) {}
                decoder.release()
            }
            return output
        } finally {
            extractor.release()
        }
    }

    private fun setSource(extractor: MediaExtractor, source: String) {
        when {
            source.startsWith("content://") -> extractor.setDataSource(context, Uri.parse(source), null)
            source.startsWith("file://") -> extractor.setDataSource(Uri.parse(source).path ?: source.removePrefix("file://"))
            source.startsWith("http://") || source.startsWith("https://") -> extractor.setDataSource(source, emptyMap())
            else -> extractor.setDataSource(source)
        }
    }

    private fun chooseAudioTrack(extractor: MediaExtractor, preferredLanguage: String?): Pair<Int, MediaFormat>? {
        val preferred = preferredLanguage?.lowercase()?.substringBefore('-')
        var first: Pair<Int, MediaFormat>? = null
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (!mime.startsWith("audio/")) continue
            if (first == null) first = i to format
            val language = format.getString(MediaFormat.KEY_LANGUAGE)?.lowercase()?.substringBefore('-')
            if (!preferred.isNullOrBlank() && language == preferred) return i to format
        }
        return first
    }

    private fun decodeToWav(
        extractor: MediaExtractor,
        decoder: MediaCodec,
        originalFormat: MediaFormat,
        output: File,
    ) {
        var sampleRate = originalFormat.getIntegerOrNull(MediaFormat.KEY_SAMPLE_RATE) ?: 48000
        var channels = originalFormat.getIntegerOrNull(MediaFormat.KEY_CHANNEL_COUNT) ?: 2
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
        val targetRate = 16000
        val targetChannels = 1
        val raf = RandomAccessFile(output, "rw")
        raf.setLength(0)
        writeWavHeader(raf, targetRate, targetChannels, 0)

        var dataBytes = 0L
        var inputDone = false
        var outputDone = false
        var inputFramesSeen = 0L
        var outputFramesWritten = 0L
        val info = MediaCodec.BufferInfo()
        val timeoutUs = 10_000L

        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = decoder.dequeueInputBuffer(timeoutUs)
                    if (inputIndex >= 0) {
                        val buffer = decoder.getInputBuffer(inputIndex) ?: error("Decoder input buffer unavailable")
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, extractor.sampleFlags)
                            extractor.advance()
                        }
                    }
                }

                when (val outputIndex = decoder.dequeueOutputBuffer(info, timeoutUs)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val f = decoder.outputFormat
                        sampleRate = f.getIntegerOrNull(MediaFormat.KEY_SAMPLE_RATE) ?: sampleRate
                        channels = f.getIntegerOrNull(MediaFormat.KEY_CHANNEL_COUNT) ?: channels
                        pcmEncoding = f.getIntegerOrNull(MediaFormat.KEY_PCM_ENCODING) ?: AudioFormat.ENCODING_PCM_16BIT
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    else -> if (outputIndex >= 0) {
                        val buffer = decoder.getOutputBuffer(outputIndex)
                        if (buffer != null && info.size > 0) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            buffer.order(ByteOrder.LITTLE_ENDIAN)
                            val channelCount = max(1, channels)
                            if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
                                val floats = buffer.asFloatBuffer()
                                val frameCount = floats.remaining() / channelCount
                                for (frame in 0 until frameCount) {
                                    var sum = 0f
                                    for (ch in 0 until channelCount) sum += floats.get(frame * channelCount + ch)
                                    val monoFloat = (sum / channelCount).coerceIn(-1f, 1f)
                                    val mono = (monoFloat * 32767f).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
                                    dataBytes += writeResampledFrame(raf, mono, sampleRate, targetRate, inputFramesSeen, outputFramesWritten)
                                    outputFramesWritten = ((inputFramesSeen + 1L) * targetRate) / sampleRate
                                    inputFramesSeen++
                                }
                            } else {
                                val shorts = buffer.asShortBuffer()
                                val frameCount = shorts.remaining() / channelCount
                                for (frame in 0 until frameCount) {
                                    var sum = 0
                                    for (ch in 0 until channelCount) sum += shorts.get(frame * channelCount + ch).toInt()
                                    val mono = (sum / channelCount).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
                                    dataBytes += writeResampledFrame(raf, mono, sampleRate, targetRate, inputFramesSeen, outputFramesWritten)
                                    outputFramesWritten = ((inputFramesSeen + 1L) * targetRate) / sampleRate
                                    inputFramesSeen++
                                }
                            }
                        }
                        outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        decoder.releaseOutputBuffer(outputIndex, false)
                    }
                }
            }
        } finally {
            writeWavHeader(raf, targetRate, targetChannels, dataBytes)
            raf.close()
        }
        if (dataBytes <= 0) error("The selected audio track decoded to no PCM samples")
    }

    private fun writeResampledFrame(
        raf: RandomAccessFile,
        mono: Short,
        sourceRate: Int,
        targetRate: Int,
        inputFrame: Long,
        alreadyWritten: Long,
    ): Long {
        val shouldHaveWritten = ((inputFrame + 1L) * targetRate) / max(1, sourceRate)
        var written = alreadyWritten
        var bytes = 0L
        while (written < shouldHaveWritten) {
            raf.write(mono.toInt() and 0xFF)
            raf.write((mono.toInt() shr 8) and 0xFF)
            written++
            bytes += 2
        }
        return bytes
    }

    private fun writeWavHeader(raf: RandomAccessFile, sampleRate: Int, channels: Int, dataSize: Long) {
        raf.seek(0)
        val byteRate = sampleRate * channels * 2
        raf.writeBytes("RIFF")
        writeLE32(raf, 36L + dataSize)
        raf.writeBytes("WAVEfmt ")
        writeLE32(raf, 16)
        writeLE16(raf, 1)
        writeLE16(raf, channels)
        writeLE32(raf, sampleRate.toLong())
        writeLE32(raf, byteRate.toLong())
        writeLE16(raf, channels * 2)
        writeLE16(raf, 16)
        raf.writeBytes("data")
        writeLE32(raf, dataSize)
    }

    private fun writeLE16(raf: RandomAccessFile, value: Int) {
        raf.write(value and 0xFF); raf.write((value shr 8) and 0xFF)
    }
    private fun writeLE32(raf: RandomAccessFile, value: Long) {
        raf.write((value and 0xFF).toInt()); raf.write(((value shr 8) and 0xFF).toInt())
        raf.write(((value shr 16) and 0xFF).toInt()); raf.write(((value shr 24) and 0xFF).toInt())
    }

    private fun MediaFormat.getIntegerOrNull(key: String): Int? = try {
        if (containsKey(key)) getInteger(key) else null
    } catch (_: Exception) { null }
}
