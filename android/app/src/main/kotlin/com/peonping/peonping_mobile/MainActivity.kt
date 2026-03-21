package com.peonping.peonping_mobile

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
                        result.success(lastStepCount.toInt())
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
                    stepSensor?.let {
                        sensorManager?.registerListener(this@MainActivity, it, SensorManager.SENSOR_DELAY_UI)
                    } ?: events?.error("NO_SENSOR", "Step counter sensor not available", null)
                }
                override fun onCancel(arguments: Any?) {
                    sensorManager?.unregisterListener(this@MainActivity)
                    eventSink = null
                }
            })

        // Load saved daily offset
        val prefs = getSharedPreferences("peonforge_steps", Context.MODE_PRIVATE)
        val savedDate = prefs.getString("date", "") ?: ""
        val today = java.time.LocalDate.now().toString()
        if (savedDate == today) {
            dailyStepOffset = prefs.getInt("offset", 0)
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            lastStepCount = event.values[0]

            // Track daily steps
            if (initialStepCount < 0) {
                val prefs = getSharedPreferences("peonforge_steps", Context.MODE_PRIVATE)
                val savedDate = prefs.getString("date", "") ?: ""
                val today = java.time.LocalDate.now().toString()
                if (savedDate == today) {
                    initialStepCount = prefs.getFloat("initial", lastStepCount)
                } else {
                    initialStepCount = lastStepCount
                    prefs.edit()
                        .putString("date", today)
                        .putFloat("initial", initialStepCount)
                        .putInt("offset", 0)
                        .apply()
                }
            }

            val dailySteps = (lastStepCount - initialStepCount).toInt()
            eventSink?.success(dailySteps)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
