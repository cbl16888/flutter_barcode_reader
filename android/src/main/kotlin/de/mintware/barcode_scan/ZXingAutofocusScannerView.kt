package de.mintware.barcode_scan

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.hardware.Camera
import android.util.AttributeSet
import android.util.TypedValue
import me.dm7.barcodescanner.core.CameraWrapper
import me.dm7.barcodescanner.core.IViewFinder
import me.dm7.barcodescanner.core.ViewFinderView
import me.dm7.barcodescanner.zxing.ZXingScannerView

class ZXingAutofocusScannerView(context: Context) : ZXingScannerView(context) {

    private var callbackFocus = false
    private var autofocusPresence = false

    override fun setupCameraPreview(cameraWrapper: CameraWrapper?) {
        cameraWrapper?.mCamera?.parameters?.let { parameters ->
            try {
                autofocusPresence = parameters.supportedFocusModes.contains(Camera.Parameters.FOCUS_MODE_AUTO);
                parameters.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE
                cameraWrapper.mCamera.parameters = parameters
            } catch (ex: Exception) {
                callbackFocus = true
            }
        }
        super.setupCameraPreview(cameraWrapper)
    }

    override fun setAutoFocus(state: Boolean) {
        //Fix to avoid crash on devices without autofocus (Issue #226)
        if(autofocusPresence){
            super.setAutoFocus(callbackFocus)
        }
    }

    override fun createViewFinderView(context: Context?): IViewFinder {
        return CustomViewFinderView(context, BarcodeScannerActivity.hint)
    }

    private class CustomViewFinderView : ViewFinderView {
        var tradeMarkText = ""
        var textPixelSize = 0f
        val paint = Paint()

        constructor(context: Context?, hint: String) : super(context) {
            tradeMarkText = hint
            initView()
        }

        constructor(context: Context?, attrs: AttributeSet?) : super(context, attrs) {
            initView()
        }

        private fun initView() {
            paint.color = Color.WHITE
            paint.isAntiAlias = true
            textPixelSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, TRADE_MARK_TEXT_SIZE_SP.toFloat(), resources.displayMetrics)
            paint.textSize = textPixelSize
            setSquareViewFinder(true)
            setLaserEnabled(true)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            drawTradeMark(canvas)
        }

        private fun drawTradeMark(canvas: Canvas) {
            val framingRect = framingRect
            val tradeMarkTop: Float
            val tradeMarkLeft: Float
            if (framingRect != null) {
                tradeMarkTop = framingRect.bottom + paint.textSize + 20
                tradeMarkLeft = (BarcodeScannerActivity.windowsWidth / 2 - tradeMarkText.length * textPixelSize / 2)
            } else {
                tradeMarkTop = 30f
                tradeMarkLeft = canvas.height - paint.textSize - 20
            }
            canvas.drawText(tradeMarkText, tradeMarkLeft, tradeMarkTop, paint)
        }

        companion object {
            const val TRADE_MARK_TEXT_SIZE_SP = 16
        }
    }
}