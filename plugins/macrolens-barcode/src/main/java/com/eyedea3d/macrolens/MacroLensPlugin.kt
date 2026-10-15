package com.eyedea3d.macrolens

import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Macro Lens Android-Plugin (Godot 4 v2).
 *
 * Phase A: nutzt den fertigen ML-Kit-Scanner-Bildschirm
 * (GmsBarcodeScanning) - kein eigenes Kamera-Overlay noetig.
 * Ergebnis wird als Signal an GDScript zurueckgegeben.
 */
class MacroLensPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName(): String = "MacroLens"

    override fun getPluginSignals(): MutableSet<SignalInfo> {
        val signals = mutableSetOf<SignalInfo>()
        signals.add(SignalInfo("barcode_scanned", String::class.java))
        signals.add(SignalInfo("scan_cancelled"))
        signals.add(SignalInfo("scan_failed", String::class.java))
        return signals
    }

    @UsedByGodot
    fun scanBarcode() {
        val act = activity ?: return
        runOnUiThread {
            val options = GmsBarcodeScannerOptions.Builder()
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
            val scanner = GmsBarcodeScanning.getClient(act, options)
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    val value = barcode.rawValue ?: ""
                    if (value.isNotEmpty()) {
                        emitSignal("barcode_scanned", value)
                    } else {
                        emitSignal("scan_failed", "empty")
                    }
                }
                .addOnFailureListener { e ->
                    emitSignal("scan_failed", e.message ?: "failed")
                }
        }
    }
}
