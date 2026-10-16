@tool
extends EditorPlugin

## Godot 4 v2 Android-Plugin (Macro Lens Barcode).
## Liefert das AAR an den Export und deklariert die ML-Kit-Abhaengigkeit als
## Maven-Dependency, damit Gradle die transitiven Bibliotheken mitnimmt.

var export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name := "MacroLens"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["macrolens/macrolens-barcode.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.camera:camera-core:1.4.1",
			"androidx.camera:camera-camera2:1.4.1",
			"androidx.camera:camera-lifecycle:1.4.1",
			"androidx.camera:camera-view:1.4.1",
			"androidx.camera:camera-mlkit-vision:1.4.1",
			"com.google.mlkit:barcode-scanning:17.3.0",
		])

	func _get_name() -> String:
		return _plugin_name
