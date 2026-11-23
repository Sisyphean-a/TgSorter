package com.example.tgsorter

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val thumbnailWorker = Executors.newSingleThreadExecutor()
    // 仅在抽帧线程访问；同一任务共享一次 setDataSource。
    private val thumbnailReaders = mutableMapOf<Long, MediaMetadataRetriever>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tgsorter/video_thumbnail")
            .setMethodCallHandler { call, result ->
                if (call.method == "close") {
                    val id = (call.arguments as? Number)?.toLong()
                    if (id == null) {
                        result.error("INVALID_FRAME_REQUEST", "抽帧会话无效", null)
                    } else {
                        thumbnailWorker.execute {
                            try {
                                thumbnailReaders.remove(id)?.release()
                                runOnUiThread { result.success(null) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("FRAME_CLOSE_FAILED", error.message, null) }
                            }
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method != "extract") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val sessionId = call.argument<Number>("sessionId")?.toLong()
                val source = call.argument<String>("source")
                val local = call.argument<Boolean>("local")
                val positionUs = call.argument<Number>("positionUs")?.toLong()
                if (sessionId == null || source == null || local == null || positionUs == null || positionUs < 0) {
                    result.error("INVALID_FRAME_REQUEST", "抽帧参数无效", null)
                    return@setMethodCallHandler
                }
                thumbnailWorker.execute {
                    try {
                        val reader = thumbnailReaders.getOrPut(sessionId) { openReader(source, local) }
                        val bytes = extractFrame(reader, positionUs)
                        runOnUiThread { result.success(bytes) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("FRAME_UNAVAILABLE", "无法读取该时间点的画面", null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        thumbnailWorker.execute {
            for (reader in thumbnailReaders.values) {
                try {
                    reader.release()
                } catch (error: Exception) {
                    android.util.Log.e("VideoThumbnail", "释放抽帧解码器失败", error)
                }
            }
            thumbnailReaders.clear()
        }
        thumbnailWorker.shutdown()
        super.onDestroy()
    }

    private fun openReader(source: String, local: Boolean): MediaMetadataRetriever {
        val reader = MediaMetadataRetriever()
        try {
            if (local) reader.setDataSource(source)
            else reader.setDataSource(source, emptyMap<String, String>())
            return reader
        } catch (error: Exception) {
            try {
                reader.release()
            } catch (releaseError: Exception) {
                error.addSuppressed(releaseError)
            }
            throw error
        }
    }

    private fun extractFrame(reader: MediaMetadataRetriever, positionUs: Long): ByteArray? {
        val mode = MediaMetadataRetriever.OPTION_CLOSEST
        val frame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            reader.getScaledFrameAtTime(positionUs, mode, 480, 480)
        } else {
            reader.getFrameAtTime(positionUs, mode)
        } ?: return null
        try {
            val scale = 480.0 / maxOf(frame.width, frame.height)
            val thumbnail = if (scale < 1) {
                Bitmap.createScaledBitmap(frame, maxOf(1, (frame.width * scale).toInt()),
                    maxOf(1, (frame.height * scale).toInt()), true)
            } else frame
            try {
                return ByteArrayOutputStream().use { output ->
                    if (thumbnail.compress(Bitmap.CompressFormat.JPEG, 80, output)) {
                        output.toByteArray()
                    } else null
                }
            } finally {
                if (thumbnail !== frame) thumbnail.recycle()
            }
        } finally {
            frame.recycle()
        }
    }
}
