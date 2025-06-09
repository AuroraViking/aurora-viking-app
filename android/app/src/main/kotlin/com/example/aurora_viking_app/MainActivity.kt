// android/app/src/main/kotlin/com/example/aurora_viking_app/MainActivity.kt
package com.example.aurora_viking_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the Aurora Camera Plugin
        flutterEngine.plugins.add(AuroraCameraPlugin())
    }
}