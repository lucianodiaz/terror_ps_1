@tool
extends EditorPlugin

var filesystem = get_editor_interface().get_resource_filesystem()

var popupFilesystem : PopupMenu

var retarget_menu_id = 10002

func _enter_tree():
    FindFilesystemPopup()

func _exit_tree():
    if popupFilesystem:
        popupFilesystem.disconnect("about_to_popup", Callable(self, "AddItemToPopup"))
        popupFilesystem.disconnect("id_pressed", Callable(self, "RetargetMixamoAnimation"))

func FindFilesystemPopup():
    var file_system:FileSystemDock = get_editor_interface().get_file_system_dock()
    
    for child in file_system.get_children():
        var pop:PopupMenu = child as PopupMenu
        if not pop: continue
        
        popupFilesystem = pop
        popupFilesystem.connect("about_to_popup", Callable(self, "AddItemToPopup"))
        popupFilesystem.connect("id_pressed", Callable(self, "RetargetMixamoAnimation"))

func AddItemToPopup():
    popupFilesystem.add_separator("Mixamo Animation Retargeter")
    popupFilesystem.add_item("Retarget Mixamo Animation(s)", retarget_menu_id)

func RetargetMixamoAnimation(id : int):
    if id != retarget_menu_id:
        return
    var selected_paths = EditorInterface.get_selected_paths()
    var fbx_files = Array(selected_paths).filter(func(path): return path.to_lower().ends_with(".fbx"))
    if fbx_files.size() > 0:
        _show_save_dialog(fbx_files)
    else:
        print("No FBX files selected")

func _show_save_dialog(fbx_paths: Array) -> void:
    var file_dialog = EditorFileDialog.new()
    file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
    file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    file_dialog.title = "Select Export Folder for Animations"
    
    file_dialog.connect("dir_selected", Callable(self, "_on_export_folder_selected").bind(fbx_paths))
    file_dialog.connect("canceled", Callable(self, "_on_file_dialog_closed"))
    
    get_editor_interface().get_base_control().add_child(file_dialog)
    file_dialog.popup_centered_ratio(0.6)

func _on_export_folder_selected(dir_path: String, fbx_paths: Array) -> void:
    for fbx_path in fbx_paths:
        _process_fbx_file(fbx_path, dir_path)
    
    _on_file_dialog_closed()

func _process_fbx_file(fbx_path: String, dir_path: String) -> void:
    print("Exporting animations from ", fbx_path, " to ", dir_path)
    
    var import_file_path: String = fbx_path + ".import"
    var config := ConfigFile.new()
    var err := config.load(import_file_path)
    if err == OK:
        var subresources: Dictionary = config.get_value("params", "_subresources", {})
        if "nodes" not in subresources:
            subresources["nodes"] = {}
        if "PATH:Skeleton3D" not in subresources["nodes"]:
            subresources["nodes"]["PATH:Skeleton3D"] = {}
        
        # Update the specific settings for Skeleton3D
        subresources["nodes"]["PATH:Skeleton3D"]["retarget/bone_map"] = load("res://addons/mixamo_animation_retargeter/mixamo_bone_map.tres")
        subresources["nodes"]["PATH:Skeleton3D"]["retarget/bone_renamer/unique_node/skeleton_name"] = "Skeleton"
        subresources["nodes"]["PATH:Skeleton3D"]["retarget/remove_tracks/unmapped_bones"] = true
        
        # Add or update the animations section
        if not "animations" in subresources:
            subresources["animations"] = {}
        if not "mixamo_com" in subresources["animations"]:
            subresources["animations"]["mixamo_com"] = {}
        
        # Get the FBX file name and convert it to snake case
        var fbx_file_name = fbx_path.get_file().get_basename()
        var snake_case_name = to_snake_case(fbx_file_name)
        
        # Create the relative path (already starts with res://)
        var relative_res_path = dir_path.path_join(snake_case_name + ".res")
        
        # Update the save to file settings for mixamo_com animation
        subresources["animations"]["mixamo_com"]["save_to_file/enabled"] = true
        subresources["animations"]["mixamo_com"]["save_to_file/keep_custom_tracks"] = ""
        subresources["animations"]["mixamo_com"]["save_to_file/path"] = relative_res_path
        subresources["animations"]["mixamo_com"]["settings/loop_mode"] = 0
        
        # Save the updated subresources back to the config
        config.set_value("params", "_subresources", subresources)
        
        # Save the changes to the .import file
        err = config.save(import_file_path)
        if err == OK:
            print("Import settings updated successfully for ", fbx_path)
            # Trigger reimport immediately after saving
            _trigger_reimport(fbx_path)
        else:
            print("Failed to save import settings for ", fbx_path)
    else:
        print("Failed to load import file for editing: ", fbx_path)

# Helper function to convert string to snake_case
func to_snake_case(string: String) -> String:
    var result = ""
    var prev_is_lowercase = false
    for i in range(string.length()):
        var c = string[i]
        if c == ' ':
            if result and result[-1] != '_':
                result += '_'
        elif c >= 'A' and c <= 'Z':
            if prev_is_lowercase and result and result[-1] != '_':
                result += '_'
            result += c.to_lower()
            prev_is_lowercase = false
        else:
            result += c.to_lower()
            prev_is_lowercase = true
    return result

func _trigger_reimport(fbx_path: String) -> void:
    # Trigger reimport of the FBX file
    var file_system = get_editor_interface().get_resource_filesystem()
    file_system.reimport_files([fbx_path])
    print("Triggered reimport of FBX file")

func _get_import_settings(file_path: String) -> ConfigFile:
    var import_settings = ConfigFile.new()
    var err = import_settings.load(file_path + ".import")
    if err == OK:
        return import_settings
    else:
        print("Failed to load import settings for: ", file_path)
        return null

# Helper function to find Skeleton3D in the scene
func find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var result = find_skeleton(child)
        if result:
            return result
    return null

func _on_file_dialog_closed() -> void:
    var file_dialog = get_editor_interface().get_base_control().get_node_or_null("FileDialog")
    if file_dialog:
        file_dialog.queue_free()