package com.vellum.app

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * 必须继承 FlutterFragmentActivity，以支持 local_auth 调起系统生物识别弹窗。
 * 同时主动向系统请求最高刷新率显示模式（120Hz）与 Surface 帧率提示，避免 LTPO 屏幕回落至 60Hz。
 */
class MainActivity : FlutterFragmentActivity() {
    private var targetRefreshRate: Float = 120f
    private var surfaceCallbackAttached: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
        applySurfaceFrameRateHint()
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
        applySurfaceFrameRateHint()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            requestHighRefreshRate()
        }
    }

    private fun requestHighRefreshRate() {
        try {
            val currentDisplay: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            if (currentDisplay != null) {
                val activeMode = currentDisplay.mode
                val bestMode = currentDisplay.supportedModes
                    .filter {
                        it.physicalWidth == activeMode.physicalWidth &&
                            it.physicalHeight == activeMode.physicalHeight
                    }
                    .maxByOrNull { it.refreshRate }
                    ?: currentDisplay.supportedModes.maxByOrNull { it.refreshRate }

                if (bestMode != null) {
                    targetRefreshRate = bestMode.refreshRate
                    val params = window.attributes
                    if (params.preferredDisplayModeId != bestMode.modeId ||
                        params.preferredRefreshRate != bestMode.refreshRate
                    ) {
                        params.preferredDisplayModeId = bestMode.modeId
                        params.preferredRefreshRate = bestMode.refreshRate
                        window.attributes = params
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                try {
                    window.setFrameRateBoostOnTouchEnabled(true)
                    window.setFrameRatePowerSavingsBalanced(false)
                } catch (_: Throwable) {
                }
            }
        } catch (_: Throwable) {
        }
    }

    private fun applySurfaceFrameRateHint() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val root = window?.decorView ?: return
        root.post {
            val surfaceView = findFlutterSurfaceView(root) ?: return@post
            setSurfaceFrameRate(surfaceView.holder.surface)
            if (!surfaceCallbackAttached) {
                surfaceCallbackAttached = true
                surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
                    override fun surfaceCreated(holder: SurfaceHolder) {
                        setSurfaceFrameRate(holder.surface)
                    }

                    override fun surfaceChanged(
                        holder: SurfaceHolder,
                        format: Int,
                        width: Int,
                        height: Int,
                    ) {
                        setSurfaceFrameRate(holder.surface)
                    }

                    override fun surfaceDestroyed(holder: SurfaceHolder) {}
                })
            }
        }
    }

    private fun setSurfaceFrameRate(surface: Surface?) {
        if (surface == null || !surface.isValid) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                    targetRefreshRate,
                    Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                    Surface.CHANGE_FRAME_RATE_ALWAYS,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                surface.setFrameRate(
                    targetRefreshRate,
                    Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                )
            }
        } catch (_: Throwable) {
        }
    }

    private fun findFlutterSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView && view.javaClass.simpleName.contains("Flutter")) {
            return view
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findFlutterSurfaceView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        if (view is SurfaceView) return view
        return null
    }
}
