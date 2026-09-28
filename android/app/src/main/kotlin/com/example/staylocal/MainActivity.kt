package com.example.staylocal

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "staylocal/device_capability",
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getMemoryInfo" -> result.success(getMemoryInfo())
                    "getStorageInfo" -> result.success(getStorageInfo())
                    "getGpuInfo" -> result.success(getGpuInfo())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("device_capability_error", e.message, null)
            }
        }
    }

    private fun getMemoryInfo(): Map<String, Any> {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return mapOf(
            "totalBytes" to memoryInfo.totalMem,
            "availableBytes" to memoryInfo.availMem,
        )
    }

    private fun getStorageInfo(): Map<String, Any> {
        val stats = StatFs(filesDir.absolutePath)
        return mapOf(
            "freeBytes" to stats.availableBytes,
            "totalBytes" to stats.totalBytes,
        )
    }

    private fun getGpuInfo(): Map<String, Any?> {
        return mapOf(
            "renderer" to queryGpuRenderer(),
            "vulkanVersion" to queryVulkanVersion(),
        )
    }

    private fun queryVulkanVersion(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return null
        val feature = packageManager.systemAvailableFeatures.firstOrNull {
            it.name == PackageManager.FEATURE_VULKAN_HARDWARE_VERSION
        } ?: return null
        val major = feature.version ushr 22
        val minor = (feature.version ushr 12) and 0x3ff
        if (major == 0 && minor == 0) return null
        return "$major.$minor"
    }

    private fun queryGpuRenderer(): String? {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return null
        try {
            if (!EGL14.eglInitialize(display, IntArray(1), 0, IntArray(1), 0)) {
                return null
            }
            val configAttribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val configCount = IntArray(1)
            if (!EGL14.eglChooseConfig(
                    display, configAttribs, 0, configs, 0, 1, configCount, 0,
                ) || configCount[0] < 1
            ) {
                return null
            }
            val contextAttribs = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE,
            )
            val context = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT, contextAttribs, 0,
            ) ?: return null
            if (context == EGL14.EGL_NO_CONTEXT) return null
            val surfaceAttribs = intArrayOf(
                EGL14.EGL_WIDTH, 1,
                EGL14.EGL_HEIGHT, 1,
                EGL14.EGL_NONE,
            )
            val surface = EGL14.eglCreatePbufferSurface(
                display, configs[0], surfaceAttribs, 0,
            ) ?: return null
            if (surface == EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroyContext(display, context)
                return null
            }
            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) {
                EGL14.eglDestroySurface(display, surface)
                EGL14.eglDestroyContext(display, context)
                return null
            }
            val renderer = GLES20.glGetString(GLES20.GL_RENDERER)
            EGL14.eglMakeCurrent(
                display,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            EGL14.eglDestroySurface(display, surface)
            EGL14.eglDestroyContext(display, context)
            return renderer
        } finally {
            EGL14.eglTerminate(display)
        }
    }
}
