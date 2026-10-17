package com.eyedea3d.macrolens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ColorMatrix
import android.graphics.Matrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.net.Uri
import android.os.SystemClock
import android.util.Size
import android.view.Gravity
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.mlkit.vision.MlKitAnalyzer
import androidx.camera.view.CameraController
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Macro Lens Android-Plugin (Godot 4 v2).
 *
 * Dauer-Scanner: LifecycleCameraController liefert eine native Vorschau (oben im
 * Bild) und einen Frame-Stream an den gebuendelten ML-Kit-Barcode-Scanner. Der
 * MlKitAnalyzer rechnet die Barcode-Ecken direkt in Vorschau-Koordinaten um ->
 * ein Overlay zeigt ein getracktes Viereck (orange erkannt, gruen gelesen).
 * Die Vorschau wird nur in der ANZEIGE entsaettigt; die Analyse bekommt weiter
 * das volle Farbbild.
 */
class MacroLensPlugin(godot: Godot) : GodotPlugin(godot) {

    private val permRequestCode = 4711
    private val confirmFrames = 2
    private val missTolerance = 3
    private val throttleIntervalMs = 100L   // ~10 fps, solange derselbe Code bestaetigt ist
    private val detectIntervalMs = 400L     // Praefetch-Meldungen drosseln

    private var container: FrameLayout? = null
    private var previewView: PreviewView? = null
    private var overlay: BarcodeOverlay? = null
    private var controller: LifecycleCameraController? = null
    private var scanner: BarcodeScanner? = null
    private var streamObserver: Observer<PreviewView.StreamState>? = null
    private var analysisExecutor: ExecutorService? = null
    private var heightFraction: Float = 0.30f
    private var pendingStart = false

    private var candidate: String? = null
    private var candidateCount = 0
    private var misses = 0
    private var lastEmitted: String? = null
    private var lastEmitAt = 0L
    private var lastDetected: String? = null
    private var lastDetectAt = 0L

    /**
     * Sparmodus fuer die Analyse: true, sobald ein Code bestaetigt im Bild
     * liegt. Dann reicht ~10 fps (Overlay bleibt bei 100 ms < 260 ms sichtbar).
     * Sobald kein Code mehr erkannt wird oder ein anderer auftaucht, wird
     * wieder mit voller Kamerarate gesucht - die Ersterkennung bleibt schnell.
     */
    @Volatile
    private var throttleAnalysis = false

    override fun getPluginName(): String = "MacroLens"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo("barcode_scanned", String::class.java),
        SignalInfo("barcode_detected", String::class.java),
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
        heightFraction = if (fraction in 0.10f..0.90f) fraction else 0.30f
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

    /** Oeffnet eine URL (https:, mailto: ...) in der passenden System-App. */
    @UsedByGodot
    fun openUrl(url: String) {
        val act = activity ?: return
        runOnUiThread {
            try {
                val uri = Uri.parse(url)
                val intent = if (url.startsWith("mailto:")) {
                    Intent(Intent.ACTION_SENDTO, uri)
                } else {
                    Intent(Intent.ACTION_VIEW, uri)
                }
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                act.startActivity(intent)
            } catch (e: Exception) {
                emitSignal("scan_failed", "url")
            }
        }
    }

    /** Beendet die App wirklich: Kamera aus, Activity samt Task weg. */
    @UsedByGodot
    fun quitApp() {
        val act = activity ?: return
        runOnUiThread {
            stopPreviewInternal()
            act.finishAndRemoveTask()
        }
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

    // --- Layout ----------------------------------------------------------------

    private fun contentHeight(): Int {
        val act = activity ?: return 0
        val content = act.findViewById<ViewGroup>(android.R.id.content)
        if (content != null && content.height > 0) {
            return content.height
        }
        return act.resources.displayMetrics.heightPixels
    }

    private fun applyHeight() {
        val c = container ?: return
        val lp = c.layoutParams as? FrameLayout.LayoutParams ?: return
        lp.height = (contentHeight() * heightFraction).toInt()
        c.layoutParams = lp
    }

    /** Graustufen nur fuer die Anzeige (leicht abgedunkelt, damit das Viereck leuchtet). */
    private fun monoPaint(dim: Float): Paint {
        val cm = ColorMatrix().apply { setSaturation(0f) }
        cm.postConcat(
            ColorMatrix(
                floatArrayOf(
                    dim, 0f, 0f, 0f, 0f,
                    0f, dim, 0f, 0f, 0f,
                    0f, 0f, dim, 0f, 0f,
                    0f, 0f, 0f, 1f, 0f
                )
            )
        )
        return Paint().apply { colorFilter = ColorMatrixColorFilter(cm) }
    }

    private fun startPreviewInternal() {
        val act = activity ?: return
        val owner = act as? LifecycleOwner ?: run {
            emitSignal("scan_failed", "lifecycle")
            return
        }

        if (container == null) {
            val c = FrameLayout(act)
            val pv = PreviewView(act).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
            // Entsaettigung auf Anzeige-Ebene (Hardware-Layer mit Farbfilter).
            pv.setLayerType(View.LAYER_TYPE_HARDWARE, monoPaint(0.85f))
            val ov = BarcodeOverlay(act)
            c.addView(pv, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            c.addView(ov, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            act.addContentView(
                c,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    (contentHeight() * heightFraction).toInt(),
                    Gravity.TOP
                )
            )
            container = c
            previewView = pv
            overlay = ov

            // Zusaetzlich direkt am TextureView, sobald der Stream laeuft.
            val obs = Observer<PreviewView.StreamState> { state ->
                if (state == PreviewView.StreamState.STREAMING) {
                    for (i in 0 until pv.childCount) {
                        val child = pv.getChildAt(i)
                        if (child is TextureView) {
                            child.setLayerPaint(monoPaint(1.0f))
                        }
                    }
                }
            }
            pv.previewStreamState.observe(owner, obs)
            streamObserver = obs
        } else {
            applyHeight()
        }

        // Hoehe nach dem ersten Layout nachziehen (Content-View hat dann seine Groesse).
        val content = act.findViewById<ViewGroup>(android.R.id.content)
        if (content != null && content.height == 0) {
            content.viewTreeObserver.addOnGlobalLayoutListener(
                object : ViewTreeObserver.OnGlobalLayoutListener {
                    override fun onGlobalLayout() {
                        content.viewTreeObserver.removeOnGlobalLayoutListener(this)
                        applyHeight()
                    }
                }
            )
        }

        val pv = previewView ?: return
        if (controller == null) {
            try {
                val mainExec = ContextCompat.getMainExecutor(act)
                val ctrl = LifecycleCameraController(act)
                ctrl.cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                ctrl.setEnabledUseCases(CameraController.IMAGE_ANALYSIS)
                ctrl.imageAnalysisResolutionSelector = ResolutionSelector.Builder()
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            Size(1280, 720),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER
                        )
                    )
                    .build()
                ctrl.setImageAnalysisBackpressureStrategy(
                    ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST
                )
                val sc = scanner()
                val mlkit = MlKitAnalyzer(
                    listOf(sc),
                    ImageAnalysis.COORDINATE_SYSTEM_VIEW_REFERENCED,
                    mainExec
                ) { result ->
                    onBarcodes(result?.getValue(sc))
                }
                // Analyse ausserhalb des Main-Threads; gedrosselt wird nur,
                // wenn derselbe Code bereits bestaetigt im Bild liegt.
                val exec = Executors.newSingleThreadExecutor()
                analysisExecutor = exec
                ctrl.setImageAnalysisAnalyzer(exec, object : ImageAnalysis.Analyzer {
                    private var lastAnalyzed = 0L
                    override fun analyze(imageProxy: ImageProxy) {
                        val now = SystemClock.uptimeMillis()
                        if (throttleAnalysis && now - lastAnalyzed < throttleIntervalMs) {
                            imageProxy.close()
                            return
                        }
                        lastAnalyzed = now
                        mlkit.analyze(imageProxy)
                    }

                    // CameraController schiebt die Sensor->View-Matrix nur in
                    // Analyzer, die sich als MlKitAnalyzer ausgeben. Ohne diese
                    // zwei Delegationen bleibt die Matrix im MlKitAnalyzer null
                    // und JEDER Frame wird verworfen (keine Barcodes).
                    override fun getDefaultTargetResolution(): Size =
                        mlkit.defaultTargetResolution

                    override fun getTargetCoordinateSystem(): Int =
                        mlkit.targetCoordinateSystem

                    override fun updateTransform(matrix: Matrix?) {
                        mlkit.updateTransform(matrix)
                    }
                })
                ctrl.bindToLifecycle(owner)
                pv.controller = ctrl
                controller = ctrl
                emitSignal("preview_started")
            } catch (e: Exception) {
                analysisExecutor?.shutdown()
                analysisExecutor = null
                emitSignal("scan_failed", e.message ?: "camera")
            }
        }
    }

    /** Stabilitaetslogik: erst nach mehreren gleichen Frames gilt ein Code als gelesen. */
    private fun onBarcodes(list: List<Barcode>?) {
        val ov = overlay ?: return
        if (list.isNullOrEmpty()) {
            misses++
            if (misses > missTolerance) {
                candidateCount = 0
            }
            throttleAnalysis = false   // wieder mit voller Rate suchen
            ov.lost()
            return
        }
        misses = 0
        val b = list.maxByOrNull {
            val r = it.boundingBox
            if (r == null) 0 else r.width() * r.height()
        } ?: return
        val value = b.rawValue
        if (!value.isNullOrEmpty()) {
            if (value == candidate) {
                candidateCount++
            } else {
                candidate = value
                candidateCount = 1
            }
        } else {
            candidateCount = 0
        }
        val confirmed = candidateCount >= confirmFrames
        ov.update(b.cornerPoints, confirmed)
        val now = SystemClock.uptimeMillis()
        if (value != null && !confirmed && value != lastDetected &&
            now - lastDetectAt > detectIntervalMs
        ) {
            // Erster Sichtkontakt: Godot kann das Produkt schon vorab laden.
            lastDetected = value
            lastDetectAt = now
            emitSignal("barcode_detected", value)
        }
        if (confirmed && value != null) {
            if (value != lastEmitted || now - lastEmitAt > 2500L) {
                lastEmitted = value
                lastEmitAt = now
                emitSignal("barcode_scanned", value)
            }
            // Derselbe Code liegt bestaetigt im Bild -> ~10 fps reichen.
            throttleAnalysis = true
        } else {
            throttleAnalysis = false
        }
    }

    private fun stopPreviewInternal() {
        try {
            controller?.unbind()
        } catch (_: Exception) {
        }
        val pv = previewView
        val obs = streamObserver
        if (pv != null && obs != null) {
            pv.previewStreamState.removeObserver(obs)
        }
        pv?.controller = null
        val c = container
        if (c != null) {
            (c.parent as? ViewGroup)?.removeView(c)
        }
        controller = null
        container = null
        previewView = null
        overlay = null
        streamObserver = null
        throttleAnalysis = false
        lastDetected = null
        lastDetectAt = 0L
        analysisExecutor?.shutdown()
        analysisExecutor = null
        candidate = null
        candidateCount = 0
        misses = 0
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
        super.onMainDestroy()
    }
}
