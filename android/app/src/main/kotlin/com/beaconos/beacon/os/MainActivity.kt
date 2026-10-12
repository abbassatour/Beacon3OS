package com.beaconos.beacon_os

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.beaconos/system"
    private var isTorchOn = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 🌟 فحص تلقائي: هل هذا الجهاز تلفزيون (Android TV / Fire TV)؟
                "isTv" -> {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    val isTv = (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) ||
                            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                            packageManager.hasSystemFeature("android.hardware.type.television")
                    result.success(isTv)
                }

                // 1. ضبط منبه حقيقي في نظام أندرويد دون فتح شاشة الساعة
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 0
                    val label = call.argument<String>("label") ?: "BeaconOS Alarm"

                    val success = setSystemAlarm(hour, minute, label)
                    result.success(success)
                }

                // 2. تشغيل أو إطفاء فلاش الكشاف مع حماية من انهيار المحاكي
                "toggleFlashlight" -> {
                    val enable = call.argument<Boolean>("enable") ?: !isTorchOn
                    val success = setFlashlight(enable)
                    result.success(success)
                }

                // 3. فتح أي تطبيق مثبت على الهاتف بالاسم أو الحزمة (Package Name)
                "openApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (!packageName.isNullOrBlank()) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Package name is null or empty", null)
                    }
                }

                // 4. قفل الشاشة أو العودة الفورية لسطح النظام
                "lockScreen" -> {
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setSystemAlarm(hour: Int, minute: Int, label: String): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun setFlashlight(enable: Boolean): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            try {
                val cameraIds = cameraManager.cameraIdList
                if (cameraIds.isEmpty()) return false

                val cameraIdWithFlash = cameraIds.firstOrNull { id ->
                    val chars = cameraManager.getCameraCharacteristics(id)
                    chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                } ?: cameraIds[0]

                cameraManager.setTorchMode(cameraIdWithFlash, enable)
                isTorchOn = enable
                return true
            } catch (e: CameraAccessException) {
                e.printStackTrace()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return false
    }
}