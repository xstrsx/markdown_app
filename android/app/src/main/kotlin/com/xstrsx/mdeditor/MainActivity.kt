package com.xstrsx.mdeditor

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.xstrsx.mdeditor/file"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeToUri" -> {
                    val uriString = call.argument<String>("uri")
                    val content = call.argument<String>("content")
                    if (uriString != null && content != null) {
                        try {
                            writeToContentUri(Uri.parse(uriString), content)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "uri and content required", null)
                    }
                }
                "getRealPath" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        try {
                            val realPath = getRealPath(Uri.parse(uriString))
                            result.success(realPath)
                        } catch (e: Exception) {
                            result.error("PATH_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "uri required", null)
                    }
                }
                "openFileLocation" -> {
                    val path = call.argument<String>("path")
                    val uriString = call.argument<String>("uri")
                    if (path != null) {
                        try {
                            openLocationInFileManager(path, uriString)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "path required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun writeToContentUri(uri: Uri, content: String) {
        contentResolver.openOutputStream(uri, "wt")?.use { outputStream ->
            outputStream.write(content.toByteArray(Charsets.UTF_8))
            outputStream.flush()
        }
    }

    private fun getRealPath(uri: Uri): String? {
        // Try to resolve content URI to a real file path
        if (uri.scheme == "file") {
            return uri.path
        }

        if (uri.scheme == "content") {
            // Try DocumentsProvider resolution
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT &&
                DocumentsContract.isDocumentUri(this, uri)) {
                try {
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split = docId.split(":")
                    if (split.size >= 2 && "primary".equals(split[0], ignoreCase = true)) {
                        return Environment.getExternalStorageDirectory().toString() + "/" + split[1]
                    }
                } catch (_: Exception) {}
            }
            // Try _data column
            try {
                val projection = arrayOf(MediaStore.MediaColumns.DATA)
                contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                        return cursor.getString(idx)
                    }
                }
            } catch (_: Exception) {}
        }
        return null
    }

    private fun openLocationInFileManager(path: String, uriString: String?) {
        try {
            // Try to open parent directory
            val file = File(path)
            val parentPath = if (file.isDirectory) path else file.parent ?: path
            val parentUri = Uri.parse("file://$parentPath")

            // Use SAF to view the folder if possible
            val intent = Intent(Intent.ACTION_VIEW).apply {
                val uri = if (uriString != null) Uri.parse(uriString) else parentUri
                setDataAndType(uri, "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (resolveActivity(packageManager) == null) {
                    // Fall back to showing the file
                    setDataAndType(parentUri, "*/*")
                }
            }
            startActivity(intent)
        } catch (_: Exception) {
            // If all fails, try to open files app
            try {
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_DEFAULT)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {}
        }
    }
}
