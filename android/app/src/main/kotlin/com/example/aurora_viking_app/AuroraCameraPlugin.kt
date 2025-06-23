// android/app/src/main/kotlin/com/example/aurora_viking_app/AuroraCameraPlugin.kt
package com.example.aurora_viking_app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import android.view.TextureView
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executor
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class AuroraCameraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var cameraManager: CameraManager? = null
    private var cameraDevice: CameraDevice? = null
    private var cameraCaptureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    private val cameraOpenCloseLock = Semaphore(1)
    
    // Camera preview
    private var previewSurface: Surface? = null
    private var textureView: TextureView? = null
    
    // Camera characteristics
    private var cameraCharacteristics: CameraCharacteristics? = null
    private var sensorOrientation: Int = 0
    
    // Manual control ranges
    private var isoRange: Range<Int>? = null
    private var exposureTimeRange: Range<Long>? = null
    private var focusDistanceRange: Range<Float>? = null
    
    // Current manual settings
    private var currentISO: Int = 800
    private var currentExposureTime: Long = 100_000_000L // 0.1 seconds in nanoseconds (safe default)
    private var currentFocusDistance: Float = 0.0f // 0 = infinity
    
    // Device capabilities
    private var supportsManualSensor = false
    private var supportsManualPostProcessing = false

    // New member variable
    private var useAutoFocus: Boolean = false

    companion object {
        private const val TAG = "AuroraCameraPlugin"
        private const val CAMERA_CHANNEL = "aurora_camera/native"
        private const val CAMERA_VIEW_TYPE = "aurora_camera_preview"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CAMERA_CHANNEL)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        
        // Register the platform view factory
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            CAMERA_VIEW_TYPE,
            CameraPreviewFactory(this)
        )
        
        Log.d(TAG, "AuroraCameraPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.d(TAG, "AuroraCameraPlugin detached from engine")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method call received: ${call.method}")
        
        when (call.method) {
            "initializeCamera" -> {
                initializeCamera(result)
            }
            "applyCameraSettings" -> {
                val iso = call.argument<Int>("iso") ?: currentISO
                val exposureSeconds = call.argument<Double>("exposureTimeSeconds") ?: 0.1
                val focusDistance = call.argument<Double>("focusDistance") ?: 0.0
                
                applyCameraSettings(iso, exposureSeconds, focusDistance.toFloat(), result)
            }
            "capturePhoto" -> {
                capturePhoto(result)
            }
            "disposeCamera" -> {
                disposeCamera(result)
            }
            "setFocusMode" -> {
                val auto = call.argument<Boolean>("auto") ?: false
                useAutoFocus = auto
                result.success(mapOf("success" to true, "auto" to useAutoFocus))
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeCamera(result: MethodChannel.Result) {
        Log.d(TAG, "Initializing camera...")
        val replied = AtomicBoolean(false)
        fun safeSuccess(value: Any?) {
            if (replied.compareAndSet(false, true)) result.success(value)
        }
        fun safeError(code: String, message: String?, details: Any?) {
            if (replied.compareAndSet(false, true)) result.error(code, message, details)
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) 
            != PackageManager.PERMISSION_GRANTED) {
            safeError("PERMISSION_DENIED", "Camera permission not granted", null)
            return
        }
        try {
            startBackgroundThread()
            
            cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = getBestCameraId()
            
            if (cameraId == null) {
                safeError("NO_CAMERA", "No suitable camera found", null)
                return
            }

            cameraCharacteristics = cameraManager!!.getCameraCharacteristics(cameraId)
            
            // Get sensor orientation
            sensorOrientation = cameraCharacteristics!!.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
            
            // Get manual control ranges with better error handling
            isoRange = cameraCharacteristics!!.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
            exposureTimeRange = cameraCharacteristics!!.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
            focusDistanceRange = cameraCharacteristics!!.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)?.let { 
                Range(0.0f, it) 
            }
            
            // Check if manual controls are supported
            val availableCapabilities = cameraCharacteristics!!.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
            supportsManualSensor = availableCapabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) == true
            supportsManualPostProcessing = availableCapabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING) == true
            
            Log.d(TAG, "Camera capabilities:")
            Log.d(TAG, "  Manual sensor: $supportsManualSensor")
            Log.d(TAG, "  Manual post-processing: $supportsManualPostProcessing")
            Log.d(TAG, "  ISO range: ${isoRange?.lower} - ${isoRange?.upper}")
            Log.d(TAG, "  Exposure time range: ${exposureTimeRange?.lower} - ${exposureTimeRange?.upper} ns")
            Log.d(TAG, "  Focus distance range: ${focusDistanceRange?.lower} - ${focusDistanceRange?.upper}")

            openCamera(cameraId) { success, error ->
                if (success) {
                    // Convert nanoseconds to seconds for Flutter side, with safe defaults
                    val minExposureSec = if (exposureTimeRange?.lower != null) {
                        (exposureTimeRange!!.lower / 1_000_000_000.0).coerceAtLeast(0.001) // Min 1ms
                    } else {
                        0.001 // 1ms default
                    }
                    
                    val maxExposureSec = if (exposureTimeRange?.upper != null) {
                        (exposureTimeRange!!.upper / 1_000_000_000.0).coerceAtMost(30.0) // Max 30s
                    } else {
                        1.0 // 1s default
                    }
                    
                    safeSuccess(mapOf(
                        "success" to true,
                        "minISO" to (isoRange?.lower ?: 100),
                        "maxISO" to (isoRange?.upper ?: 3200),
                        "minExposureTime" to minExposureSec,
                        "maxExposureTime" to maxExposureSec,
                        "supportsManualSensor" to supportsManualSensor,
                        "supportsManualPostProcessing" to supportsManualPostProcessing
                    ))
                } else {
                    safeError("CAMERA_OPEN_FAILED", error ?: "Failed to open camera", null)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error initializing camera", e)
            safeError("INITIALIZATION_FAILED", e.message, null)
        }
    }

    private fun getBestCameraId(): String? {
        return try {
            val cameraIdList = cameraManager!!.cameraIdList
            Log.d(TAG, "Available cameras: ${cameraIdList.size}")
            
            // Prefer back camera with manual controls
            for (cameraId in cameraIdList) {
                val characteristics = cameraManager!!.getCameraCharacteristics(cameraId)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val capabilities = characteristics.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                
                val isBackCamera = facing == CameraCharacteristics.LENS_FACING_BACK
                val supportsManual = capabilities?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) == true
                
                Log.d(TAG, "Camera $cameraId: back=$isBackCamera, manual=$supportsManual")
                
                if (isBackCamera) {
                    Log.d(TAG, "Selected camera: $cameraId")
                    return cameraId
                }
            }
            
            // If no back camera, return first available
            cameraIdList.firstOrNull()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting camera ID", e)
            null
        }
    }

    @SuppressLint("MissingPermission")
    private fun openCamera(cameraId: String, callback: (Boolean, String?) -> Unit) {
        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                callback(false, "Time out waiting to lock camera opening.")
                return
            }

            Log.d(TAG, "Opening camera: $cameraId")

            cameraManager!!.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    Log.d(TAG, "Camera opened successfully")
                    cameraOpenCloseLock.release()
                    cameraDevice = camera
                    createCameraPreviewSession { success, error ->
                        callback(success, error)
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    Log.d(TAG, "Camera disconnected")
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    callback(false, "Camera disconnected")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "Camera error: $error")
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    callback(false, "Camera error: $error")
                }
            }, backgroundHandler)

        } catch (e: Exception) {
            Log.e(TAG, "Exception opening camera", e)
            callback(false, "Exception opening camera: ${e.message}")
        }
    }

    private fun createCameraPreviewSession(callback: (Boolean, String?) -> Unit) {
        try {
            val device = cameraDevice
            if (device == null) {
                callback(false, "Camera device is null")
                return
            }

            Log.d(TAG, "Creating camera preview session")

            // Set up ImageReader for photo capture - use reasonable resolution
            imageReader = ImageReader.newInstance(1920, 1080, ImageFormat.JPEG, 1)
            
            val surfaces = mutableListOf<Surface>()
            surfaces.add(imageReader!!.surface)
            
            // Add preview surface if available
            previewSurface?.let { surfaces.add(it) }

            val outputConfigurations = surfaces.map { OutputConfiguration(it) }

            val sessionConfig = SessionConfiguration(
                SessionConfiguration.SESSION_REGULAR,
                outputConfigurations,
                ContextCompat.getMainExecutor(context),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        if (cameraDevice == null) {
                            callback(false, "Camera device closed during session creation")
                            return
                        }

                        cameraCaptureSession = session
                        Log.d(TAG, "Camera capture session configured successfully")
                        
                        // Start preview if we have a surface
                        if (previewSurface != null) {
                            startPreview()
                        }
                        
                        callback(true, null)
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Failed to configure camera capture session")
                        callback(false, "Failed to configure capture session")
                    }
                }
            )

            device.createCaptureSession(sessionConfig)

        } catch (e: Exception) {
            Log.e(TAG, "Error creating camera preview session", e)
            callback(false, "Error creating preview session: ${e.message}")
        }
    }

    fun setPreviewSurface(surface: Surface) {
        Log.d(TAG, "Setting preview surface")
        previewSurface = surface
        
        // If camera is already initialized, restart session
        if (cameraDevice != null) {
            createCameraPreviewSession { success, error ->
                if (!success) {
                    Log.e(TAG, "Failed to restart session with preview: $error")
                }
            }
        }
    }

    private fun startPreview() {
        try {
            val device = cameraDevice
            val session = cameraCaptureSession
            val surface = previewSurface
            
            if (device == null || session == null || surface == null) {
                Log.w(TAG, "Cannot start preview - missing components")
                return
            }

            Log.d(TAG, "Starting camera preview")

            val previewRequestBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            previewRequestBuilder.addTarget(surface)
            
            // Use auto mode for preview for better performance
            previewRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)

            session.setRepeatingRequest(
                previewRequestBuilder.build(),
                null,
                backgroundHandler
            )
            
            Log.d(TAG, "Preview started successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting preview", e)
        }
    }

    private fun applyCameraSettings(iso: Int, exposureSeconds: Double, focusDistance: Float, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Applying camera settings:")
            Log.d(TAG, "  Requested - ISO: $iso, Exposure: ${exposureSeconds}s, Focus: $focusDistance, AutoFocus: $useAutoFocus")
            
            // Clamp values to supported ranges with logging
            val clampedISO = isoRange?.clamp(iso) ?: iso
            val exposureNs = (exposureSeconds * 1_000_000_000L).toLong()
            val clampedExposureNs = exposureTimeRange?.clamp(exposureNs) ?: exposureNs
            // Convert meters to diopters for manual focus
            val focusDiopters = if (focusDistance >= 1000f) 0.0f else (1.0f / focusDistance)
            val clampedFocus = focusDistanceRange?.clamp(focusDiopters) ?: focusDiopters
            currentISO = clampedISO
            currentExposureTime = clampedExposureNs
            currentFocusDistance = clampedFocus
            Log.d(TAG, "  Applied - ISO: $currentISO, Exposure: ${currentExposureTime}ns (${currentExposureTime/1_000_000_000.0}s), Focus: $currentFocusDistance, AutoFocus: $useAutoFocus")
            result.success(mapOf(
                "success" to true,
                "appliedISO" to currentISO,
                "appliedExposureTime" to (currentExposureTime / 1_000_000_000.0),
                "appliedFocusDistance" to currentFocusDistance,
                "supportsManualSensor" to supportsManualSensor
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error applying camera settings", e)
            result.error("SETTINGS_FAILED", e.message, null)
        }
    }

    private fun capturePhoto(result: MethodChannel.Result) {
        try {
            val device = cameraDevice
            val session = cameraCaptureSession
            val reader = imageReader

            if (device == null || session == null || reader == null) {
                result.error("CAMERA_NOT_READY", "Camera not properly initialized", null)
                return
            }

            Log.d(TAG, "Starting photo capture")
            Log.d(TAG, "  Using settings - ISO: $currentISO, Exposure: ${currentExposureTime}ns, Focus: $currentFocusDistance, AutoFocus: $useAutoFocus")

            // Create capture request with manual settings
            val captureRequestBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureRequestBuilder.addTarget(reader.surface)

            if (supportsManualSensor) {
                Log.d(TAG, "Applying manual sensor controls")
                // Apply manual controls
                captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_OFF)
                captureRequestBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, currentISO)
                captureRequestBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, currentExposureTime)
                captureRequestBuilder.set(CaptureRequest.CONTROL_AWB_MODE, CameraMetadata.CONTROL_AWB_MODE_OFF)
                if (useAutoFocus) {
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON)
                } else {
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_OFF)
                    captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_OFF)
                    captureRequestBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, currentFocusDistance)
                }
            } else {
                Log.w(TAG, "Manual sensor controls not supported, using auto mode")
                captureRequestBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
            }

            // Set up image capture callback
            reader.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                try {
                    Log.d(TAG, "Image captured, saving...")
                    saveImage(image) { success, filePath, error ->
                        if (success && filePath != null) {
                            Log.d(TAG, "Image saved successfully: $filePath")
                            result.success(mapOf(
                                "success" to true,
                                "imagePath" to filePath
                            ))
                        } else {
                            Log.e(TAG, "Failed to save image: $error")
                            result.error("SAVE_FAILED", error ?: "Failed to save image", null)
                        }
                    }
                } finally {
                    image.close()
                }
            }, backgroundHandler)

            // Capture the photo
            session.capture(
                captureRequestBuilder.build(),
                object : CameraCaptureSession.CaptureCallback() {
                    override fun onCaptureStarted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        timestamp: Long,
                        frameNumber: Long
                    ) {
                        Log.d(TAG, "Capture started at timestamp: $timestamp")
                    }

                    override fun onCaptureCompleted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        result: TotalCaptureResult
                    ) {
                        Log.d(TAG, "Photo capture completed successfully")
                        
                        // Log actual applied settings
                        val actualISO = result.get(CaptureResult.SENSOR_SENSITIVITY)
                        val actualExposure = result.get(CaptureResult.SENSOR_EXPOSURE_TIME)
                        val actualFocus = result.get(CaptureResult.LENS_FOCUS_DISTANCE)
                        
                        Log.d(TAG, "Actual capture settings - ISO: $actualISO, Exposure: ${actualExposure}ns, Focus: $actualFocus")
                    }

                    override fun onCaptureFailed(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        failure: CaptureFailure
                    ) {
                        Log.e(TAG, "Photo capture failed: ${failure.reason}")
                        result.error("CAPTURE_FAILED", "Photo capture failed: ${failure.reason}", null)
                    }
                },
                backgroundHandler
            )

        } catch (e: Exception) {
            Log.e(TAG, "Error capturing photo", e)
            result.error("CAPTURE_ERROR", e.message, null)
        }
    }

    private fun saveImage(image: Image, callback: (Boolean, String?, String?) -> Unit) {
        try {
            val buffer = image.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)

            val outputDir = File(context.getExternalFilesDir(null), "aurora_photos")
            if (!outputDir.exists()) {
                outputDir.mkdirs()
            }

            val outputFile = File(outputDir, "aurora_${System.currentTimeMillis()}.jpg")
            
            FileOutputStream(outputFile).use { output ->
                output.write(bytes)
            }

            Log.d(TAG, "Photo saved to: ${outputFile.absolutePath}")
            callback(true, outputFile.absolutePath, null)

        } catch (e: Exception) {
            Log.e(TAG, "Error saving image", e)
            callback(false, null, "Error saving image: ${e.message}")
        }
    }

    private fun disposeCamera(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Disposing camera")
            cameraOpenCloseLock.acquire()
            
            cameraCaptureSession?.close()
            cameraCaptureSession = null
            
            cameraDevice?.close()
            cameraDevice = null
            
            imageReader?.close()
            imageReader = null
            
            previewSurface = null
            
            stopBackgroundThread()
            
            Log.d(TAG, "Camera disposed successfully")
            result.success(mapOf("success" to true))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing camera", e)
            result.error("DISPOSE_ERROR", e.message, null)
        } finally {
            cameraOpenCloseLock.release()
        }
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
        Log.d(TAG, "Background thread started")
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
            Log.d(TAG, "Background thread stopped")
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread", e)
        }
    }
}

// Platform view factory for camera preview
class CameraPreviewFactory(private val plugin: AuroraCameraPlugin) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CameraPreviewView(context, viewId, plugin)
    }
}

// Platform view for camera preview
class CameraPreviewView(context: Context, id: Int, private val plugin: AuroraCameraPlugin) : PlatformView {
    private val textureView: TextureView = TextureView(context)

    init {
        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                Log.d("CameraPreviewView", "Surface texture available: ${width}x${height}")
                plugin.setPreviewSurface(Surface(surface))
            }

            override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
                Log.d("CameraPreviewView", "Surface texture size changed: ${width}x${height}")
            }

            override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
                Log.d("CameraPreviewView", "Surface texture destroyed")
                return true
            }

            override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
                // Called for each frame - don't log here as it's too frequent
            }
        }
    }

    override fun getView(): TextureView = textureView

    override fun dispose() {
        Log.d("CameraPreviewView", "Preview view disposed")
    }
}

// Extension function to clamp values to range
private fun <T : Comparable<T>> Range<T>.clamp(value: T): T {
    return when {
        value < lower -> lower
        value > upper -> upper
        else -> value
    }
}