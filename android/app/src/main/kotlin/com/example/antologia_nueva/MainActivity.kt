package com.example.antologia_nueva

import android.view.WindowManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ESTA LÍNEA PROTEGE TODA LA APP (MODO CAOS SEGURO)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}