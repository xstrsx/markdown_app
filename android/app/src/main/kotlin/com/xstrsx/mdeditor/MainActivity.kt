package com.xstrsx.mdeditor

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.*

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.xstrsx.mdeditor/file"
        private const val PICK_FILE_CODE = 1001
        private const val SAVE_FILE_CODE = 1002
        private const val SAVE_BYTES_CODE = 1003
    }

    private var pendingResult: MethodChannel.Result? = null
    private var saveContent: String? = null
    private var saveBytes: ByteArray? = null
    private var saveMimeType: String? = null

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
                    "saveBytesAs" -> {
                        pendingResult = result
                        saveBytes = call.argument<ByteArray>("bytes")
                        saveMimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val fileName = call.argument<String>("fileName") ?: "未命名.pdf"
                        startSaveBytesIntent(fileName)
                    }
                    "readFile" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString != null) {
                            val content = readFileFromUri(Uri.parse(uriString))
                            result.success(content)
                        } else {
                            result.error("ARGS", "uri required", null)
                        }
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
                    "deleteDocument" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString != null) {
                            result.success(deleteDocument(Uri.parse(uriString)))
                        } else {
                            result.success(deleteResult("unsupported", "无效的文件地址"))
                        }
                    }
                    "openFileLocation" -> {
                        val path = call.argument<String>("path")
                        val contentUri = call.argument<String>("contentUri")
                        if (path != null) {
                            openLocation(path, contentUri)
                            result.success(true)
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startPickFileIntent(mimeTypes: List<String>?) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            if (mimeTypes != null && mimeTypes.isNotEmpty()) {
                if (mimeTypes.size == 1) type = mimeTypes[0]
                else { type = "*/*"; putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray()) }
            } else type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                     Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        try { startActivityForResult(intent, PICK_FILE_CODE) }
        catch (e: Exception) { pendingResult?.error("ERROR", e.message, null); pendingResult = null }
    }

    private fun startSaveFileIntent(fileName: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_TITLE, fileName)
            type = "text/*"
        }
        if (intent.resolveActivity(packageManager) == null) {
            intent.type = "*/*"
        }
        try { startActivityForResult(intent, SAVE_FILE_CODE) }
        catch (e: Exception) { pendingResult?.error("ERROR", e.message, null); pendingResult = null }
    }

    private fun startSaveBytesIntent(fileName: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_TITLE, fileName)
            type = saveMimeType ?: "application/octet-stream"
        }
        try { startActivityForResult(intent, SAVE_BYTES_CODE) }
        catch (e: Exception) { pendingResult?.error("ERROR", e.message, null); pendingResult = null }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            PICK_FILE_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) handlePickResult(data!!.data!!)
                else { pendingResult?.success(null); pendingResult = null }
            }
            SAVE_FILE_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) handleSaveResult(data!!.data!!)
                else { pendingResult?.success(null); pendingResult = null; saveContent = null }
            }
            SAVE_BYTES_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) handleSaveBytesResult(data!!.data!!)
                else { pendingResult?.success(deleteResult("cancelled", "用户取消导出")); pendingResult = null; saveBytes = null; saveMimeType = null }
            }
        }
    }

    private fun handlePickResult(uri: Uri) {
        try {
            try {
                contentResolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or
                          Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            } catch (_: Exception) {}

            val fileName = getFileName(uri) ?: "unknown.md"

            val cacheDir = File(cacheDir, "file_picker"); cacheDir.mkdirs()
            val cacheFile = File(cacheDir, "${System.currentTimeMillis()}_$fileName")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(cacheFile).use { output -> input.copyTo(output) }
            }

            val realPath = resolveRealPath(uri)
            val displayPath = realPath ?: uri.toString()

            val resultMap = mapOf(
                "path" to cacheFile.absolutePath,
                "displayPath" to displayPath,
                "realPath" to (realPath ?: ""),
                "uri" to uri.toString(),
                "name" to fileName
            )
            pendingResult?.success(resultMap)
        } catch (e: Exception) { pendingResult?.error("PICK_ERROR", e.message, null) }
        pendingResult = null
    }

    private fun handleSaveResult(uri: Uri) {
        try {
            val content = saveContent ?: ""
            contentResolver.openOutputStream(uri, "wt")?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8)); output.flush()
            }
            val fileName = getFileName(uri) ?: "未命名.md"
            val realPath = resolveRealPath(uri) ?: uri.toString()

            val cacheDir = File(cacheDir, "file_picker"); cacheDir.mkdirs()
            val cacheFile = File(cacheDir, "${System.currentTimeMillis()}_$fileName")
            cacheFile.writeText(content)

            val resultMap = mapOf(
                "path" to cacheFile.absolutePath,
                "displayPath" to realPath,
                "realPath" to (resolveRealPath(uri) ?: ""),
                "uri" to uri.toString(),
                "name" to fileName
            )
            pendingResult?.success(resultMap)
        } catch (e: Exception) { pendingResult?.error("SAVE_ERROR", e.message, null) }
        pendingResult = null; saveContent = null
    }

    private fun handleSaveBytesResult(uri: Uri) {
        try {
            val bytes = saveBytes ?: ByteArray(0)
            contentResolver.openOutputStream(uri, "wt")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: run {
                pendingResult?.success(deleteResult("failed", "无法写入 PDF 文件"))
                pendingResult = null
                saveBytes = null
                saveMimeType = null
                return
            }
            val fileName = getFileName(uri) ?: "未命名.pdf"
            val resultMap = mapOf(
                "status" to "saved",
                "path" to (resolveRealPath(uri) ?: uri.toString()),
                "contentUri" to uri.toString(),
                "name" to fileName
            )
            pendingResult?.success(resultMap)
        } catch (e: Exception) {
            pendingResult?.success(deleteResult("failed", e.message ?: "PDF 导出失败"))
        }
        pendingResult = null; saveBytes = null; saveMimeType = null
    }

    private fun readFileFromUri(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                input.bufferedReader().readText()
            }
        } catch (e: Exception) { null }
    }

    private fun writeToUri(uri: Uri, content: String) {
        contentResolver.openOutputStream(uri, "wt")?.use { output ->
            output.write(content.toByteArray(Charsets.UTF_8)); output.flush()
        }
    }

    private fun deleteDocument(uri: Uri): Map<String, String> {
        if (uri.scheme != "content") {
            return deleteResult("unsupported", "当前文件地址不支持系统删除")
        }

        return try {
            val deleted = try {
                DocumentsContract.deleteDocument(contentResolver, uri)
            } catch (_: UnsupportedOperationException) {
                contentResolver.delete(uri, null, null) > 0
            }
            if (deleted) deleteResult("success", "原文件已删除")
            else deleteResult("unsupported", "存储提供方拒绝删除此文件")
        } catch (_: SecurityException) {
            deleteResult("permissionDenied", "没有删除原文件的权限")
        } catch (_: FileNotFoundException) {
            deleteResult("notFound", "原文件不存在")
        } catch (_: UnsupportedOperationException) {
            deleteResult("unsupported", "当前存储提供方不支持删除")
        } catch (error: Exception) {
            deleteResult("failed", error.message ?: "删除原文件失败")
        }
    }

    private fun deleteResult(status: String, message: String): Map<String, String> =
        mapOf("status" to status, "message" to message)

    private fun openLocation(path: String, contentUri: String?) {
        try {
            if (!contentUri.isNullOrBlank()) {
                val uri = Uri.parse(contentUri)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, contentResolver.getType(uri) ?: "text/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return
                }
            }

            val file = File(path)
            if (!file.exists()) {
                showToast("无法定位原文件，请重新选择文件")
                return
            }
            val parent = if (file.isDirectory) file else file.parentFile ?: return

            if (parent.absolutePath.startsWith(filesDir.absolutePath) ||
                parent.absolutePath.startsWith(cacheDir.absolutePath)) {
                copyPathToClipboard(path)
                showToast("文件路径已复制到剪贴板: $path")
                return
            }

            try {
                val parentUri = Uri.parse(parent.absolutePath)
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(parentUri, "resource/folder")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent); return
                }
            } catch (_: Exception) {}

            copyPathToClipboard(path)
            showToast("文件路径已复制到剪贴板")
        } catch (e: Exception) {
            copyPathToClipboard(path)
            showToast("文件路径已复制到剪贴板")
        }
    }

    private fun getFileName(uri: Uri): String? {
        try {
            if (uri.scheme == "content") {
                contentResolver.query(uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor ->
                        if (cursor.moveToFirst())
                            return cursor.getString(
                                cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                    }
            }
        } catch (_: Exception) {}
        return uri.lastPathSegment
    }

    private fun resolveRealPath(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        if (uri.scheme != "content") return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                if (DocumentsContract.isDocumentUri(this, uri)) {
                    val docId = DocumentsContract.getDocumentId(uri)
                    val split = docId.split(":")
                    if (split.size >= 2 && "primary".equals(split[0], ignoreCase = true))
                        return Environment.getExternalStorageDirectory().toString() +
                               "/" + split[1]
                }
            } catch (_: Exception) {}
        }
        try {
            contentResolver.query(uri, arrayOf("_data"), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndexOrThrow("_data")
                        return cursor.getString(idx)
                    }
                }
        } catch (_: Exception) {}
        return null
    }

    private fun copyPathToClipboard(path: String) {
        val cm = getSystemService(CLIPBOARD_SERVICE) as android.content.ClipboardManager
        cm.setPrimaryClip(android.content.ClipData.newPlainText("path", path))
    }

    private fun showToast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }
}
