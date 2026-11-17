package com.attd.tracker

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

// FlutterFragmentActivity is required by local_auth, which uses
// androidx.biometric and needs a FragmentActivity host.
//
// It also hands a tapped handoff file (VIEW) or a file shared to the app
// (SEND) to Dart. The bytes are read here, bounded, and nothing in the file is
// interpreted natively: Dart validates it.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pendingFile: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    result.success(pendingFile)
                    pendingFile = null
                }
                else -> result.notImplemented()
            }
        }
        channel = methodChannel
        pendingFile = readIncoming(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val bytes = readIncoming(intent) ?: return
        val methodChannel = channel
        if (methodChannel != null) {
            methodChannel.invokeMethod("fileOpened", bytes)
        } else {
            pendingFile = bytes
        }
    }

    private fun readIncoming(intent: Intent?): ByteArray? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return null
        return try {
            contentResolver.openInputStream(uri)?.use { readBounded(it) }
        } catch (e: Exception) {
            null
        }
    }

    // Reads at most MAX_BYTES + 1 bytes: enough for Dart to see that a file is
    // over the cap and reject it, without ever holding a huge file in memory.
    private fun readBounded(input: InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (total <= MAX_BYTES) {
            val read = input.read(buffer, 0, minOf(buffer.size, MAX_BYTES + 1 - total))
            if (read < 0) break
            out.write(buffer, 0, read)
            total += read
        }
        return out.toByteArray()
    }

    companion object {
        private const val CHANNEL = "com.attd.tracker/handoff"

        // Keep in step with HandoffLimits.maxBytes in Dart.
        private const val MAX_BYTES = 512 * 1024
    }
}
