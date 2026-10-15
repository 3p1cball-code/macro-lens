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
		return PackedStringArray(["com.google.android.gms:play-services-code-scanner:16.1.0"])

	func _get_name() -> String:
		return _plugin_name
