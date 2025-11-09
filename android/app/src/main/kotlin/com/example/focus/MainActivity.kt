package com.example.focus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build // Required for API check

class MainActivity : FlutterActivity() {
    // 1. Define the MethodChannel name (MUST match the Dart file)
    private val CHANNEL = "com.example.focus/lock_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 2. Set up the MethodChannel handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->

            // Handle the method calls from Dart
            when (call.method) {
                "pinApp" -> {
                    // Start Android Screen Pinning
                    // startLockTask() is available from API 21+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        startLockTask()
                        result.success(true) // Indicate success back to Dart
                    } else {
                        result.error("UNSUPPORTED", "Screen Pinning requires Android Lollipop (API 21) or higher.", null)
                    }
                }
                "unpinApp" -> {
                    // Stop Android Screen Pinning
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        stopLockTask()
                        result.success(true) // Indicate success back to Dart
                    } else {
                        result.error("UNSUPPORTED", "Screen Pinning requires Android Lollipop (API 21) or higher.", null)
                    }
                }
                else -> {
                    // Method call not recognized
                    result.notImplemented()
                }
            }
        }
    }
}