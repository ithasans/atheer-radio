package com.hassanobeid.atheer_radio

import android.content.Intent
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val shareChannelName = "com.hassanobeid.atheer_radio/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                            if (subject.isNotEmpty()) {
                                putExtra(Intent.EXTRA_SUBJECT, subject)
                            }
                        }
                        val chooser = Intent.createChooser(sendIntent, subject.ifEmpty { null })
                        startActivity(chooser)
                        result.success(true)
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val title = call.argument<String>("title") ?: ""
                        if (path.isNullOrEmpty()) {
                            result.error("INVALID_PATH", "Empty file path", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("NOT_FOUND", "File not found", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val sendIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "audio/mpeg"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            if (title.isNotEmpty()) {
                                putExtra(Intent.EXTRA_SUBJECT, title)
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(sendIntent, title.ifEmpty { null })
                        startActivity(chooser)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
