package com.colin2wang.epub_reader

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.colin2wang.epub_reader/file"
    private var methodChannel: MethodChannel? = null
    private var pendingFileUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 设置方法通道
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    // 返回待处理的文件 URI
                    if (pendingFileUri != null) {
                        result.success(pendingFileUri.toString())
                        pendingFileUri = null
                    } else {
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // 检查是否有待处理的 intent
        if (intent != null && intent.action == Intent.ACTION_VIEW) {
            handleIntent(intent)
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val action = intent.action
        val data = intent.data
        
        if (action == Intent.ACTION_VIEW && data != null) {
            // 保存文件 URI，等待 Flutter 引擎准备好后获取
            pendingFileUri = data
            
            // 如果 Flutter 引擎已经准备好，立即发送
            if (methodChannel != null) {
                sendFileToFlutter(data)
            }
        }
    }

    private fun sendFileToFlutter(uri: Uri) {
        try {
            // 读取文件内容
            val inputStream = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val bytes = inputStream.readBytes()
                inputStream.close()
                
                // 获取文件名
                val fileName = getFileName(uri)
                
                // 通过 MethodChannel 发送文件数据到 Flutter
                methodChannel?.invokeMethod("openFile", mapOf(
                    "fileName" to fileName,
                    "fileBytes" to bytes
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getFileName(uri: Uri): String {
        var fileName = "book.epub"
        
        // 尝试从 URI 路径获取文件名
        val path = uri.path
        if (path != null) {
            val segments = path.split("/")
            if (segments.isNotEmpty()) {
                fileName = segments.last()
            }
        }
        
        // 如果是 content scheme，尝试查询显示名称
        if (uri.scheme == "content") {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (it.moveToFirst() && nameIndex != -1) {
                    fileName = it.getString(nameIndex)
                }
            }
        }
        
        return fileName
    }
}
