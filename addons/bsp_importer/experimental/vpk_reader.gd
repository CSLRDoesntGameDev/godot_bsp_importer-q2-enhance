@tool class_name VPKReader extends Node

@export var data : PackedByteArray 
var cursor = 0
var paks : Dictionary = {}
var current_directory : String
var current_path : String

var textures : Dictionary = {}

func get_pak_family(dir_name : String) -> String: return dir_name.replacen("dir.vpk", "")


func get_texture_list_from_vpk(dir : String):
	read_vpk(dir)

func read_vpk(from_directory : String):
	if not from_directory.ends_with("/"): from_directory += "/"
	current_directory = from_directory
	var files = DirAccess.get_files_at(from_directory)
	var directory_files : PackedStringArray = []
	for file in files: if file.get_basename().ends_with("dir"): directory_files.append(file)
	for d in directory_files: 
		var family = get_pak_family(d)
		for file in files:
			if !paks.has(family): paks[family] = []
			if paks.has(family) && file.containsn(family): paks[family].append(file)
	prints("Paks Loaded:", paks.keys())
	for pak in paks.keys(): load_vpk_directory_header(pak)

func load_vpk_directory_header(family : String):
	var file = current_directory + family
	var dir = file + "dir.vpk"
	var dir_data = FileAccess.get_file_as_bytes(dir)
	data = dir_data
	var Signature = dir_data.decode_u32(0)
	var Version = dir_data.decode_u32(4)
	
	var TreeSize = 0
	var FileDataSectionSize = 0
	var ArchiveMD5SectionSize = 0
	var OtherMD5SectionSize = 0
	var SignatureSectionSize = 0 
	
	print("VPK Version %s" % Version)
	
	match Version:
		1:
			cursor = 24
			read_directory(dir_data, file)
			prints(Signature, Version)
			
		2:
			TreeSize = dir_data.decode_u32(8)
			FileDataSectionSize = dir_data.decode_u32(12)
			ArchiveMD5SectionSize = dir_data.decode_u32(16)
			OtherMD5SectionSize = dir_data.decode_u32(24)
			SignatureSectionSize = dir_data.decode_u32(28)
			#prints("VPK Data:", Signature, Version, TreeSize, FileDataSectionSize, ArchiveMD5SectionSize, OtherMD5SectionSize, SignatureSectionSize)
			
			cursor = 32
			read_directory(dir_data, file)

func read_directory(dir_data : PackedByteArray, file : String):
	var i = 0
	while true:
		var extension = read_string(dir_data)
		if extension == "":
			break
		while true:
			var path = read_string(dir_data)
			if path == "":
				break
			while true:
				var filename = read_string(dir_data)
				if filename == "":
					break
				
				var CRC = dir_data.decode_u32(cursor); cursor += 4
				var PreloadBytes = dir_data.decode_u16(cursor); cursor += 2
				var ArchiveIndex = dir_data.decode_u16(cursor); cursor += 2
				var EntryOffset = dir_data.decode_u32(cursor); cursor += 4
				var EntryLength = dir_data.decode_u32(cursor); cursor += 4
				var Terminator = dir_data.decode_u16(cursor); cursor += 2
				var dict = {"CRC": CRC, "PreloadBytes": PreloadBytes, "ArchiveIndex": ArchiveIndex, "EntryOffset": EntryOffset, "EntryLength": EntryLength, "Terminator": Terminator}
				
				if extension == "vtf": 
					textures[path + "/" + filename] = dict
					return
					extract_vtf(file, path + "/" + filename, dict)
					i += 1
					#if i > 400: return
					print(path + "/" + filename + " (." + extension + ")")


func read_string(dir_data : PackedByteArray):
	var string = ""
	while true:
		var ch :int= dir_data.decode_u8(cursor)
		cursor += 1
		if ch == 0 || ch > 255: return string
		string += char(ch)

func extract_vtf(in_file : String, out_file : String, entry_data : Dictionary):
	var adopted_name = in_file 
	for i in 3-(str(entry_data.ArchiveIndex).length()): adopted_name += "0"
	adopted_name += str(entry_data.ArchiveIndex, ".vpk")
	
	var vpk_data = FileAccess.get_file_as_bytes(adopted_name)
	
	var signature = vpk_data.decode_u32(0)
	var version : float = (vpk_data.decode_u32(entry_data.EntryOffset + 4) + (vpk_data.decode_u32(entry_data.EntryOffset + 8) / 10.0)) 
	var header_size := vpk_data.decode_u32(entry_data.EntryOffset + 12)
	
	var width := vpk_data.decode_u16(entry_data.EntryOffset + 16)
	var height := vpk_data.decode_u16(entry_data.EntryOffset + 18)
	
	var flags := vpk_data.decode_u32(entry_data.EntryOffset + 20)
	
	var frames := vpk_data.decode_u16(entry_data.EntryOffset + 24)
	var firstFrame := vpk_data.decode_u16(entry_data.EntryOffset + 26)
	
	var padding = vpk_data.decode_u32(entry_data.EntryOffset + 28)
	
	var reflect_x = vpk_data.decode_float(entry_data.EntryOffset + 32)
	var reflect_y = vpk_data.decode_float(entry_data.EntryOffset + 36)
	var reflect_z = vpk_data.decode_float(entry_data.EntryOffset + 40)
	
	var other_cooler_padding = vpk_data.decode_u32(entry_data.EntryOffset + 44)
	var bumpmapScale = vpk_data.decode_float(entry_data.EntryOffset + 48)
	
	var highResImageFormat = vpk_data.decode_s32(entry_data.EntryOffset + 52)
	
	var mipmapCount = vpk_data.decode_u8(entry_data.EntryOffset + 56)
	
	var lowResImageFormat = vpk_data.decode_s32(entry_data.EntryOffset + 57)
	var lowResImageWidth = vpk_data.decode_u8(entry_data.EntryOffset + 61)
	var lowResImageHeight = vpk_data.decode_u8(entry_data.EntryOffset + 62)
	
	# 7.2+
	var depth = vpk_data.decode_u16(entry_data.EntryOffset + 63)
	
	# 7.3+
	var padding_but_even_cooler # 3 bytes! 65 - 68
	var numResources = vpk_data.decode_u32(entry_data.EntryOffset + 68)
	var padding_but_lame # 8 bytes (depends on the compiler) 72 - 80
	
	prints(version, width, height, mipmapCount, depth )
	
	if version == 7.2:
		var lowResByteCount = ceili(float(lowResImageWidth) / 4) * ceili(float(lowResImageHeight) / 4) * 8
		var highResByteCount = ceili(float(width) / 4) * ceili(float(height) / 4) * 16
		var low_res_byte_offset = entry_data.EntryOffset + 80
		
		var final_off = get_mipmap_offset(width, height, mipmapCount)
		
		var high_res_byte_offset = low_res_byte_offset + lowResByteCount
		var low_res_slice = vpk_data.slice(low_res_byte_offset, low_res_byte_offset + lowResByteCount)
		var high_res_slice = vpk_data.slice(final_off + high_res_byte_offset, final_off + high_res_byte_offset + highResByteCount)
		var image = null # Image.create_from_data(lowResImageWidth, lowResImageHeight, false, Image.FORMAT_DXT1, low_res_slice)
		#image.save_png("res://source/" + out_file.get_file() + "_lowres.png")
		var format = Image.FORMAT_DXT1
		
		# godot doesnt have most of the formats source did so im taking a wild guess here.
		
		match highResImageFormat:
			13: # DXT1
				format = Image.FORMAT_DXT1
			14: # DXT3
				format = Image.FORMAT_DXT3
				image = Image.create_from_data(width, height, false, Image.FORMAT_DXT3, high_res_slice)
				image.save_png("res://source/" + out_file.get_file() + "_dxt3.png")
			15: # DXT5
				image = Image.create_from_data(width, height, false, Image.FORMAT_DXT5, high_res_slice)
				image.save_png("res://source/" + out_file.get_file() + "_dxt5.png")
				
				format = Image.FORMAT_DXT5
			3:
				format = Image.FORMAT_RGB8
			12:
				format = Image.FORMAT_RGBA8
			22:
				format = Image.FORMAT_RG8

func get_mipmap_offset(width : int, height : int, depth : int) -> int: 
	var current_width = width
	var current_height = height
	var final_byte_offset = 0
	
	for i in depth-1:
		current_width = max(1, current_width / 2)
		current_height = max(1, current_height / 2)
		final_byte_offset += ceili(float(current_width) / 4) * ceili(float(current_height) / 4) * 16
	return final_byte_offset
