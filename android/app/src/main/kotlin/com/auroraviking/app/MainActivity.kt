// android/app/src/main/kotlin/com/auroraviking/app/MainActivity.kt
package com.auroraviking.app

import android.os.Bundle
import android.util.Log
import com.auroraviking.app.R
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AuroraCameraPlugin())
    }
}