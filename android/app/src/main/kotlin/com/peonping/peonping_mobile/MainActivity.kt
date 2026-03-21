package com.peonping.peonping_mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var lastStepCount: Float = 0f
    private var initialStepCount: Float = -1f
    private var dailyStepOffset: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.peonforge/battery")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestBatteryExemption") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.peonforge/steps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStepCount" -> {
                        val p = getSharedPreferences("peonforge_steps", Context.MODE_PRIVATE)
                        val savedDate = p.getString("date", "") ?: ""
                        val today = java.time.LocalDate.now().toString()
                        val steps = if (savedDate == today) p.getInt("daily", 0) else 0
                        result.success(steps)
                    }
                    "hasSensor" -> {
                        result.success(stepSensor != null)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel for live step updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.peonforge/step_stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events

                    // Request ACTIVITY_RECOGNITION permission at native level
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (ContextCompat.checkSelfPermission(this@MainActivity,
                                Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this@MainActivity,
                                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), 1001)
                            // Listener will be registered in onRequestPermissionsResult
                            return
                        }
                    }
                    registerStepListener()
                }
                override fun onCancel(arguments: Any?) {
                    sensorManager?.unregisterListener(this@MainActivity)
                    eventSink = null
                }
            })

        // Load saved daily steps
        val prefs = getSharedPreferences("peonforge_steps", Context.MODE_PRIVATE)
        val savedDate = prefs.getString("date", "") ?: ""
        val today = java.time.LocalDate.now().toString()
        if (savedDate == today) {
            dailyStepOffset = prefs.getInt("daily", 0)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val currentTotal = event.values[0]
            lastStepCount = currentTotal
            val prefs = getSharedPreferences("peonforge_steps", Context.MODE_PRIVATE)
            val today = java.time.LocalDate.now().toString()
            val savedDate = prefs.getString("date", "") ?: ""

            if (savedDate != today) {
                // New day: save current total as baseline, carry over accumulated daily steps
                val prevDaily = prefs.getInt("daily", 0)
                initialStepCount = currentTotal
                dailyStepOffset = 0
                prefs.edit()
                    .putString("date", today)
                    .putFloat("initial", initialStepCount)
                    .putInt("daily", 0)
                    .apply()
            } else if (initialStepCount < 0) {
                // App restart same day: restore baseline
                initialStepCount = prefs.getFloat("initial", currentTotal)
                dailyStepOffset = prefs.getInt("daily", 0)
                // If device rebooted (currentTotal < initialStepCount), adjust
                if (currentTotal < initialStepCount) {
                    dailyStepOffset += (initialStepCount - currentTotal).toInt()
                    initialStepCount = currentTotal
                    prefs.edit()
                        .putFloat("initial", initialStepCount)
                        .putInt("daily", dailyStepOffset)
                        .apply()
                }
            }

            val dailySteps = (currentTotal - initialStepCount).toInt() + dailyStepOffset
            prefs.edit().putInt("daily", dailySteps).apply()
            eventSink?.success(dailySteps)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun registerStepListener() {
        stepSensor?.let {
            val ok = sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            android.util.Log.i("PeonForge", "Step sensor registered: $ok")
        } ?: android.util.Log.e("PeonForge", "No step counter sensor")
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            registerStepListener()
        }
    }
}
