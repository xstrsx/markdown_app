package com.xstrsx.mdeditor

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.*

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.xstrsx.mdeditor/file"
        private const val TAG = "MdEditorFile"
        private const val PICK_FILE_CODE = 1001
        private const val SAVE_FILE_CODE = 1002
    }

    private var pendingResult: MethodChannel.Result? = null
    private var saveContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> {
                        pendingResult = result
                        val mimeTypes = call.argument<List<String>>("mimeTypes")
                        startPickFileIntent(mimeTypes)
                    }
                    "saveFileAs" -> {
                        pendingResult = result
                        saveContent = call.argument<String>("content")
                        val fileName = call.argument<String>("fileName") ?: "未命名.md"
                        startSaveFileIntent(fileName)
                    }
                    "writeToUri" -> {
                        val uriString = call.argument<String>("uri")
                        val content = call.argument<String>("content")
                        if (uriString != null && content != null) {
                            writeToUri(Uri.parse(uriString), content)
                            result.success(true)
                        } else {
                            result.error("ARGS", "uri and content required", null)
                        }
                    }
                    "openFileLocation" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            openLocation(path)
                            result.success(true)
                        } else {
                            result.error("ARGS", "path required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Pick File (with WRITE permission) ───────────────────────────

    private fun startPickFileIntent(mimeTypes: List<String>?) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Support markdown and text files
            if (mimeTypes != null && mimeTypes.isNotEmpty()) {
                if (mimeTypes.size == 1) {
                    type = mimeTypes[0]
                } else {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                }
            } else {
                type = "*/*"
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                     Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, PICK_FILE_CODE)
        } catch (e: Exception) {
            pendingResult?.error("ERROR", e.message, null)
            pendingResult = null
        }
    }

    // ─── Save File As (CREATE_DOCUMENT with content) ─────────────────

    private fun startSaveFileIntent(fileName: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/markdown"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, SAVE_FILE_CODE)
        } catch (e: Exception) {
            pendingResult?.error("ERROR", e.message, null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            PICK_FILE_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) {
                    handlePickResult(data!!.data!!)
                } else {
                    pendingResult?.success(null)
                    pendingResult = null
                }
            }
            SAVE_FILE_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) {
                    handleSaveResult(data!!.data!!)
                } else {
                    pendingResult?.success(null)
                    pendingResult = null
                    saveContent = null
                }
            }
        }
    }

    private fun handlePickResult(uri: Uri) {
        try {
            // Take persistable permission so we can write back later
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {}

            val fileName = getFileName(uri)
            // Cache file content locally for reading
            val cacheDir = File(cacheDir, "file_picker")
            cacheDir.mkdirs()
            val cacheFile = File(cacheDir, "${System.currentTimeMillis()}_$fileName")

            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }

            val resultMap = mapOf(
                "path" to cacheFile.absolutePath,
                "uri" to uri.toString(),
                "name" to (fileName ?: "unknown.md")
            )
            pendingResult?.success(resultMap)
        } catch (e: Exception) {
            pendingResult?.error("PICK_ERROR", e.message, null)
        }
        pendingResult = null
    }

    private fun handleSaveResult(uri: Uri) {
        try {
            val content = saveContent ?: ""
            // Write content to the new file
            contentResolver.openOutputStream(uri, "wt")?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            }

            val fileName = getFileName(uri)

            // Try to resolve real path
            var realPath = resolveRealPath(uri)
            if (realPath == null) {
                // Fallback: save to a known location
                realPath = uri.toString()
            }

            val resultMap = mapOf(
                "path" to realPath,
                "uri" to uri.toString(),
                "name" to (fileName ?: "未命名.md")
            )
            pendingResult?.success(resultMap)
        } catch (e: Exception) {
            pendingResult?.error("SAVE_ERROR", e.message, null)
        }
        pendingResult = null
        saveContent = null
    }

    // ─── Write to existing URI ────────────────────────────────────────

    private fun writeToUri(uri: Uri, content: String) {
        contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(content.toByteArray(Charsets.UTF_8))
            output.flush()
        }
    }

    // ─── Open file location ───────────────────────────────────────────

    private fun openLocation(path: String) {
        try {
            val file = File(path)
            val parent = if (file.isDirectory) file else file.parentFile ?: return

            // Try opening the parent directory via SAF DocumentsUI
            val intent = Intent(Intent.ACTION_VIEW).apply {
                val parentUri = Uri.fromFile(parent)
                setDataAndType(parentUri, "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return
            }

            // Fallback: try opening with */*
            val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.fromFile(parent), "*/*")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (fallbackIntent.resolveActivity(packageManager) != null) {
                startActivity(fallbackIntent)
                return
            }

            // Last resort: copy path to clipboard
            val clipboard = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("path", path))
            Toast.makeText(this, "路径已复制到剪贴板", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Toast.makeText(this, "无法打开文件位置", Toast.LENGTH_SHORT).show()
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        try {
            if (uri.scheme == "content") {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME),
                    null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        name = cursor.getString(
                            cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                    }
                }
            }
        } catch (_: Exception) {}
        if (name == null) {
            name = uri.lastPathSegment
        }
        return name
    }

    private fun resolveRealPath(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        if (uri.scheme != "content") return null

        // Try DocumentsProvider
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                if (DocumentsContract.isDocumentUri(this, uri)) {
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split = docId.split(":")
                    if (split.size >= 2 && "primary".equals(split[0], ignoreCase = true)) {
                        return Environment.getExternalStorageDirectory().toString() +
                               "/" + split[1]
                    }
                }
            } catch (_: Exception) {}
        }

        // Try _data column
        try {
            contentResolver.query(uri, arrayOf("_data"), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndexOrThrow("_data")
                    return cursor.getString(idx)
                }
            }
        } catch (_: Exception) {}

        return null
    }
}
