package com.eyedea3d.macrolens

import android.content.Context
import android.graphics.Canvas
import android.graphics.CornerPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Point
import android.os.SystemClock
import android.view.View
import kotlin.math.abs
import kotlin.math.exp

/**
 * Transparentes Viereck ueber dem erkannten Barcode.
 * Orange = Barcode im Bild, Gruen = Barcode sicher gelesen.
 * Position, Sichtbarkeit und Farbe werden exponentiell geglaettet (wirkt wie
 * Ease-Out, "snappy"); beim Bestaetigen gibt es einen kurzen Puls.
 */
class BarcodeOverlay(ctx: Context) : View(ctx) {

    private val density = ctx.resources.displayMetrics.density
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        pathEffect = CornerPathEffect(10f * density)
    }
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3.5f * density
        strokeJoin = Paint.Join.ROUND
        pathEffect = CornerPathEffect(10f * density)
    }
    private val path = Path()
    private val target = FloatArray(8)
    private val shown = FloatArray(8)
    private var hasShape = false
    private var visible = 0f
    private var mix = 0f          // 0 = orange, 1 = gruen
    private var pulse = 0f
    private var confirmed = false
    private var lastSeen = 0L
    private var lastFrame = 0L

    init {
        isClickable = false
        isFocusable = false
    }

    /** Neue Ecken (in View-Koordinaten) + ob der Code bereits sicher gelesen ist. */
    fun update(points: Array<Point>?, isConfirmed: Boolean) {
        if (points == null || points.size < 4) {
            return
        }
        var cx = 0f
        var cy = 0f
        for (i in 0 until 4) {
            cx += points[i].x
            cy += points[i].y
        }
        cx /= 4f
        cy /= 4f
        for (i in 0 until 4) {
            // etwas Luft um den Code herum
            target[i * 2] = cx + (points[i].x - cx) * 1.14f
            target[i * 2 + 1] = cy + (points[i].y - cy) * 1.14f
        }
        if (!hasShape || visible < 0.05f) {
            System.arraycopy(target, 0, shown, 0, 8)
            hasShape = true
        }
        if (isConfirmed && !confirmed) {
            pulse = 1f
        }
        confirmed = isConfirmed
        lastSeen = SystemClock.uptimeMillis()
        postInvalidateOnAnimation()
    }

    /** Kein Barcode im Bild -> ausblenden (weich). */
    fun lost() {
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val now = SystemClock.uptimeMillis()
        val dt = if (lastFrame == 0L) 0.016f else (now - lastFrame).coerceIn(0L, 100L) / 1000f
        lastFrame = now
        val present = now - lastSeen < 260L

        val kPos = 1f - exp(-dt * 20f)
        val kVis = 1f - exp(-dt * (if (present) 18f else 10f))
        val kMix = 1f - exp(-dt * 14f)
        val kPulse = 1f - exp(-dt * 7f)
        for (i in 0 until 8) {
            shown[i] += (target[i] - shown[i]) * kPos
        }
        visible += ((if (present) 1f else 0f) - visible) * kVis
        mix += ((if (confirmed) 1f else 0f) - mix) * kMix
        pulse -= pulse * kPulse
        if (!present && visible < 0.02f) {
            confirmed = false
        }

        if (hasShape && visible > 0.01f) {
            var cx = 0f
            var cy = 0f
            for (i in 0 until 4) {
                cx += shown[i * 2]
                cy += shown[i * 2 + 1]
            }
            cx /= 4f
            cy /= 4f
            val s = 1f + 0.10f * pulse
            path.reset()
            for (i in 0 until 4) {
                val x = cx + (shown[i * 2] - cx) * s
                val y = cy + (shown[i * 2 + 1] - cy) * s
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            val col = lerpColor(ORANGE, GREEN, mix)
            fillPaint.color = col
            fillPaint.alpha = (visible * 64f).toInt()
            strokePaint.color = col
            strokePaint.alpha = (visible * 245f).toInt()
            canvas.drawPath(path, fillPaint)
            canvas.drawPath(path, strokePaint)
        }

        val settling = present || visible > 0.01f || pulse > 0.01f ||
            abs(mix - (if (confirmed) 1f else 0f)) > 0.01f
        if (settling) {
            postInvalidateOnAnimation()
        } else {
            lastFrame = 0L
        }
    }

    private fun lerpColor(a: Int, b: Int, t: Float): Int {
        val tt = t.coerceIn(0f, 1f)
        val ar = (a shr 16) and 0xFF
        val ag = (a shr 8) and 0xFF
        val ab = a and 0xFF
        val br = (b shr 16) and 0xFF
        val bg = (b shr 8) and 0xFF
        val bb = b and 0xFF
        val r = (ar + (br - ar) * tt).toInt()
        val g = (ag + (bg - ag) * tt).toInt()
        val bl = (ab + (bb - ab) * tt).toInt()
        return (0xFF shl 24) or (r shl 16) or (g shl 8) or bl
    }

    companion object {
        private const val ORANGE = 0xFFF0A020.toInt()
        private const val GREEN = 0xFF4CC38A.toInt()
    }
}
