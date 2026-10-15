package com.eyedea3d.macrolens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.Executors

/**
 * Macro Lens Android-Plugin (Godot 4 v2).
 *
 * Dauer-Scanner: CameraX liefert eine native Vorschau (PreviewView, oben im
 * Bild) und einen Frame-Stream an den gebuendelten ML-Kit-Barcode-Scanner
 * (on-device, kein Play-Services-Zwang). Erkannte Codes gehen als Signal an
 * GDScript. Die Godot-UI zeichnet unterhalb der Vorschau.
 */
class MacroLensPlugin(godot: Godot) : GodotPlugin(godot) {

    private val permRequestCode = 4711
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    private var previewView: PreviewView? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var scanner: BarcodeScanner? = null
    private var heightFraction: Float = 0.32f
    private var pendingStart = false

    override fun getPluginName(): String = "MacroLens"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("barcode_scanned", String::class.java),
        SignalInfo("scan_failed", String::class.java),
        SignalInfo("preview_started"),
    )

    private fun scanner(): BarcodeScanner {
        if (scanner == null) {
            val opts = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_EAN_13,
                    Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_UPC_A,
                    Barcode.FORMAT_UPC_E,
                    Barcode.FORMAT_CODE_128,
                    Barcode.FORMAT_CODE_39,
                    Barcode.FORMAT_ITF
                )
                .build()
            scanner = BarcodeScanning.getClient(opts)
        }
        return scanner!!
    }

    /** Startet (oder aktualisiert) die Kamera-Vorschau oben; fraction = Hoehe 0..1. */
    @UsedByGodot
    fun startPreview(fraction: Float) {
        heightFraction = if (fraction in 0.10f..0.90f) fraction else 0.32f
        val act = activity ?: return
        runOnUiThread {
            if (ContextCompat.checkSelfPermission(act, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED
            ) {
                pendingStart = true
                act.requestPermissions(arrayOf(Manifest.permission.CAMERA), permRequestCode)
            } else {
                startPreviewInternal()
            }
        }
    }

    @UsedByGodot
    fun stopPreview() {
        runOnUiThread { stopPreviewInternal() }
    }

    /** Teilt Text ueber das System-Share-Sheet. */
    @UsedByGodot
    fun shareText(text: String) {
        val act = activity ?: return
        runOnUiThread {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            act.startActivity(Intent.createChooser(send, null))
        }
    }

    private fun startPreviewInternal() {
        val act = activity ?: return
        val heightPx = (act.resources.displayMetrics.heightPixels * heightFraction).toInt()

        var pv = previewView
        if (pv == null) {
            pv = PreviewView(act).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
                isClickable = false
                isFocusable = false
            }
            act.addContentView(
                pv,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    heightPx,
                    Gravity.TOP
                )
            )
            previewView = pv
        } else {
            val lp = pv.layoutParams as FrameLayout.LayoutParams
            lp.height = heightPx
            pv.layoutParams = lp
        }

        val future = ProcessCameraProvider.getInstance(act)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(pv.surfaceProvider)
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                analysis.setAnalyzer(analysisExecutor) { proxy -> analyze(proxy) }
                provider.unbindAll()
                provider.bindToLifecycle(
                    act as LifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis
                )
                emitSignal("preview_started")
            } catch (e: Exception) {
                emitSignal("scan_failed", e.message ?: "camera")
            }
        }, ContextCompat.getMainExecutor(act))
    }

    private fun analyze(proxy: ImageProxy) {
        val media = proxy.image
        if (media == null) {
            proxy.close()
            return
        }
        val image = InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees)
        scanner().process(image)
            .addOnSuccessListener { barcodes ->
                for (b in barcodes) {
                    val value = b.rawValue
                    if (!value.isNullOrEmpty()) {
                        emitSignal("barcode_scanned", value)
                        break
                    }
                }
            }
            .addOnCompleteListener { proxy.close() }
    }

    private fun stopPreviewInternal() {
        try {
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
        }
        val pv = previewView
        if (pv != null) {
            (pv.parent as? ViewGroup)?.removeView(pv)
        }
        previewView = null
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == permRequestCode && pendingStart) {
            pendingStart = false
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startPreviewInternal()
            } else {
                emitSignal("scan_failed", "permission")
            }
        }
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onMainDestroy() {
        stopPreviewInternal()
        scanner?.close()
        analysisExecutor.shutdown()
        super.onMainDestroy()
    }
}
