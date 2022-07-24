package com.example.liveness

import android.graphics.BitmapFactory
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.benamorn.liveness"
    private var job: Job? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLiveness" -> checkLiveness(call.arguments)
                else -> result.notImplemented()
            }
        }
    }

    private fun checkLiveness(data: Any) {
        if (job?.isActive == false || job == null) {
            job = CoroutineScope(Dispatchers.Main).launch {
                val imageBytes = withContext(Dispatchers.Default) {
                    val key = data as Map<String, String>
                    val bytesList = key["platforms"] as List<ByteArray>;
                    val strides = key["strides"] as IntArray;
                    val width = key["width"] as Int;
                    val height = key["height"] as Int;
                    YuvConverter.NV21toJPEG(YuvConverter.YUVtoNV21(bytesList, strides, width, height), width, height, 80);
                }

                val decodedImage = withContext(Dispatchers.Default) { BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) }
                withContext(Dispatchers.Default) {
                    Log.i("got decodedImage", "$decodedImage")
                    // Feed decodedImage into ML
                }
            }
        }
    }
}
