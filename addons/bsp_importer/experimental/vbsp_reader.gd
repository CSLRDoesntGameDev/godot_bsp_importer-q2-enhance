@tool class_name VBSPReader extends Node

## just an experimental file. in theory source uses all of the same geometry code as quake 2 so this is all redudant. 
## but this does need the separate code since it's header is different. -cs
## i will most likely be using this file as a way to improve on the quake 2 reader.

## based on documentation from https://developer.valvesoftware.com/wiki/BSP_(Source)

enum {LUMP_OFFSET, LUMP_LENGTH}

var table = PackedStringArray([
	"LUMP_ENTITIES",
	"LUMP_PLANES",
	"LUMP_TEXDATA",
	"LUMP_VERTEXES",
	"LUMP_VISIBILITY",
	"LUMP_NODES",
	"LUMP_TEXINFO",
	"LUMP_FACES",
	"LUMP_LIGHTING",
	"LUMP_OCCLUSION",
	"LUMP_LEAFS",
	"LUMP_FACEIDS",
	"LUMP_EDGES",
	"LUMP_SURFEDGES",
	"LUMP_MODELS",
	"LUMP_WORLDLIGHTS",
	"LUMP_LEAFFACES",
	"LUMP_LEAFBRUSHES",
	"LUMP_BRUSHES",
	"LUMP_BRUSHSIDES",
	"LUMP_AREAS",
	"LUMP_AREAPORTALS",
	"LUMP_PORTALS",
	"LUMP_UNUSED0",
	"LUMP_PROPCOLLISION",
	"LUMP_CLUSTERS",
	"LUMP_UNUSED1",
	"LUMP_PROPHULLS",
	"LUMP_PORTALVERTS",
	"LUMP_UNUSED2",
	"LUMP_FAKEENTITIES",
	"LUMP_PROPHULLVERTS",
	"LUMP_CLUSTERPORTALS",
	"LUMP_UNUSED3",
	"LUMP_PROPTRIS",
	"LUMP_DISPINFOD",
	"LUMP_ORIGINALFACES",
	"LUMP_PHYSDISP",
	"LUMP_PHYSCOLLIDE",
	"LUMP_VERTNORMALS",
	"LUMP_VERTNORMALINDICES",
	"LUMP_DISP_LIGHTMAP_ALPHAS",
	"LUMP_DISP_VERTS",
	"LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS",
	"LUMP_GAME_LUMP",
	"LUMP_LEAFWATERDATA",
	"LUMP_PRIMITIVES",
	"LUMP_PRIMVERTS",
	"LUMP_PRIMINDICES",
	"LUMP_PAKFILE",
	"LUMP_CLIPPORTALVERTS",
	"LUMP_CUBEMAPS",
	"LUMP_TEXDATA_STRING_DATA",
	"LUMP_TEXDATA_STRING_TABLE",
	"LUMP_OVERLAYS",
	"LUMP_LEAFMINDISTTOWATER",
	"LUMP_FACE_MACRO_TEXTURE_INFO",
	"LUMP_DISP_TRIS",
	"LUMP_PHYSCOLLIDESURFACE",
	"LUMP_PROP_BLOB",
	"LUMP_WATEROVERLAYS",
	"LUMP_LIGHTMAPPAGES",
	"LUMP_LEAF_AMBIENT_INDEX_HDR",
	"LUMP_LIGHTMAPPAGEINFOS",
	"LUMP_LEAF_AMBIENT_INDEX",
	"LUMP_LIGHTING_HDR",
	"LUMP_WORLDLIGHTS_HDR",
	"LUMP_LEAF_AMBIENT_LIGHTING_HDR",
	"LUMP_LEAF_AMBIENT_LIGHTING",
	"LUMP_XZIPPAKFILE",
	"LUMP_FACES_HDR",
	"LUMP_MAP_FLAGS",
	"LUMP_OVERLAY_FADES",
	"LUMP_OVERLAY_SYSTEM_LEVELS",
	"LUMP_PHYSLEVEL",
	"LUMP_DISP_MULTIBLEND"
])

class SourceFace:
	var plane_index : int = 0
	
	var side_opposite : int = 0 
	var on_node : int = 0
	
	var texture_index : int = 0
	
	var face_indices : PackedInt64Array = []

class SourceTexInfo:
	var UV : PackedVector4Array
	var LM_UV : PackedVector4Array
	var flag : int
	var texture_index : int

class SourceTexData:
	var reflectivity : Vector3 = Vector3.ZERO # probably unusable in godot
	var nameStringTableID : int = 0 # index into texture string table
	var width : int = 0 # self explanatory
	var height : int = 0
	var view_width : int = 0 # also self explanatory
	var view_height : int = 0 
	


var directory_table : Dictionary = {}
var bsp_bytes : PackedByteArray = []
var bsp_reader : BSPReader

var geometry : Dictionary = {"VERTEX": PackedVector3Array(), "FACE": [], "EDGE": []}

var subversion : int = -1
var textures : Dictionary = {}

var vpk_source_path := ""

var source_version = "2004"

	## TODO: use the functions in this for quake 2 mesh construction

func convert_to_scene(source_file : String):
	push_warning("VALVE BSP SUPPORT IS EXPERIMENTAL, IT MAY NOT WORK AND MAY BE REMOVED IN A FUTURE VERSION!")
	
	bsp_bytes = FileAccess.get_file_as_bytes(source_file)
	
	var magic_num = bsp_bytes.slice(0, 4).get_string_from_ascii() # THIS BETTER VBSP DAMMIT!
	var bsp_version = bsp_bytes.slice(4, 8).decode_u32(0) # 20 for Source 2006, 21 for L4D2.
	
	prints(magic_num, bsp_version)
	
	if vpk_source_path != "":
		var reader = VPKReader.new()
		reader.read_vpk(vpk_source_path)
	
	geometry = {}
	textures = {}
	directory_table = {}
	
	for dir_entry in table.size():
		var lump_name = table[dir_entry]
		var byte_index = 8 + (dir_entry * 16)
		var slice: PackedByteArray = bsp_bytes.slice(byte_index, byte_index + 16)
		directory_table[lump_name] = {
			"offset": slice.decode_u32(0), 
			"length": slice.decode_u32(4), 
			"version": slice.decode_u32(8), 
			"identifier": slice.slice(12, 16)
		}
	
	geometry.VERTEX = vertex_array(directory_table.LUMP_VERTEXES)
	geometry.FACE = face_array(directory_table.LUMP_FACES)
	
	geometry.TEXDATA = get_tex_data(directory_table.LUMP_TEXDATA)
	geometry.TEXINFO = get_tex_info(directory_table.LUMP_TEXINFO)
	
	get_tex_string_table(directory_table.LUMP_TEXDATA_STRING_TABLE)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in geometry.FACE:
		face = face as SourceFace
		
		for index in face.face_indices.size()-2:
			var v0 = geometry.VERTEX[face.face_indices[index+0]] * bsp_reader.unit_scale
			var v1 = geometry.VERTEX[face.face_indices[index+1]] * bsp_reader.unit_scale
			var v2 = geometry.VERTEX[face.face_indices[index+2]] * bsp_reader.unit_scale
			var norm = ((v1 - v0).cross(v2 - v0)).normalized()
			st.set_normal(norm)
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
			
	var m = MeshInstance3D.new()
	m.mesh = st.commit()
	m.name = str(source_file.get_file())
	return m
var u = 0


func get_tex_data(lump_data) -> Array[SourceTexData]:
	var count = lump_data.length / 32
	var offset = lump_data.offset
	var texdatas : Array[SourceTexData] = []
	
	for i in range(0, count, 1):
		
		var index = i * 32
		var rx = bsp_bytes.slice(offset + index, offset + index + 32).decode_float(0)
		var ry = bsp_bytes.slice(offset + index, offset + index + 32).decode_float(4)
		var rz = bsp_bytes.slice(offset + index, offset + index + 32).decode_float(8)
		var reflect = Vector3(rx, rz, -ry) # probably correct? 
		
		var ntd = SourceTexData.new()
		
		ntd.reflectivity = reflect
		
		ntd.nameStringTableID = bsp_bytes.slice(offset + index, offset + index + 32).decode_s32(12)
		ntd.width = bsp_bytes.slice(offset + index, offset + index + 32).decode_s32(16)
		ntd.height = bsp_bytes.slice(offset + index, offset + index + 32).decode_s32(20)
		ntd.view_width = bsp_bytes.slice(offset + index, offset + index + 32).decode_s32(24)
		ntd.view_height = bsp_bytes.slice(offset + index, offset + index + 32).decode_s32(28)
		texdatas.append(ntd)
		
	
	return texdatas

func get_tex_string_table(lump_data):
	var offset = lump_data.offset
	var count = lump_data.length / 4
	var texture_ind = []
	prints("estimated %s textures" % count)
	#for i in count:
		#var ind = i * 4
		#var index = bsp_bytes.slice(offset + ind, offset + ind + 4).decode_s32(0) #/ 256000
		#
		#print(index)

func get_tex_info(lump_data) -> Array[SourceTexInfo]:
	var count = lump_data.length / 72
	var offset = lump_data.offset
	var texinfos : Array[SourceTexInfo] = []
	for i in range(0, count, 1):
		var index = i * 72
		
		# UV 
		var ux = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(0)
		var uy = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(4)
		var uz = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(8)
		var uo = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(12)
		
		var u = Vector4(ux, uy, uz, uo)
		
		var vx = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(16)
		var vy = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(20)
		var vz = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(24)
		var vo = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(28)
		var v = Vector4(vx, vy, vz, vo)
		
		# LM
		var lm_ux = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(32)
		var lm_uy = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(36)
		var lm_uz = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(40)
		var lm_uo = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(44)
		var lm_u = Vector4(lm_ux, lm_uy, lm_uz, lm_uo)
		
		var lm_vx = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(48)
		var lm_vy = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(52)
		var lm_vz = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(56)
		var lm_vo = bsp_bytes.slice(offset + index, offset + index + 72).decode_float(60)
		var lm_v = Vector4(lm_vx, lm_vy, lm_vz, lm_vo)
		
		var flag = bsp_bytes.slice(offset + index, offset + index + 72).decode_u32(64)
		var texture_pointer = bsp_bytes.slice(offset + index, offset + index + 72).decode_s32(68)
		
		var ti = SourceTexInfo.new()
		ti.UV = [u, v]
		ti.LM_UV = [lm_u, lm_v]
		ti.flag = flag
		ti.texture_index = texture_pointer
		 
		var texture_data = geometry.TEXDATA[texture_pointer] as SourceTexData
		texinfos.append(ti)
		
		
	return texinfos


func face_array(lump_data) -> Array[SourceFace]:
	var faces : Array[SourceFace] = []
	var count = lump_data.length / 56
	var offset = lump_data.offset
	
	for v in range(0, count, 1):
		var index = v * 56
		var face = SourceFace.new()
		
		face.plane_index = bsp_bytes.slice(offset + index, offset + index + 56).decode_u16(0)
		face.side_opposite = bsp_bytes.slice(offset + index, offset + index + 56).decode_u8(2)
		face.on_node = bsp_bytes.slice(offset + index, offset + index + 56).decode_u8(3)
		var edge_first = bsp_bytes.slice(offset + index, offset + index + 56).decode_u32(4)
		var edge_count = bsp_bytes.slice(offset + index, offset + index + 56).decode_u16(8)
		
		var surface_edge_lump_offset = directory_table.LUMP_SURFEDGES.offset
		var edge_lump_offset = directory_table.LUMP_EDGES.offset
		
		var process_table = []
		
		for i in range(edge_first, edge_first + edge_count):
			var e_index = i * 4
			var surf_edge = bsp_bytes.slice(surface_edge_lump_offset + e_index, surface_edge_lump_offset + e_index + 8).decode_s32(0)
			var edge1 = bsp_bytes.slice(edge_lump_offset + abs(surf_edge * 4), edge_lump_offset + abs(surf_edge * 4) + 4).decode_u16(0)
			var edge2 = bsp_bytes.slice(edge_lump_offset + abs(surf_edge * 4), edge_lump_offset + abs(surf_edge * 4) + 4).decode_u16(2)
			if surf_edge < 0: process_table.append_array([edge2, edge1])
			if surf_edge > 0: process_table.append_array([edge1, edge2])
			
		
		for vi in range(0, process_table.size()-2):
			var ind0 = process_table[0] 
			var ind1 = process_table[vi + 1]
			var ind2 = process_table[vi + 2]
			
			face.face_indices.append(ind0)
			face.face_indices.append(ind1)
			face.face_indices.append(ind2)
		
		
		faces.append(face)
	
	return faces


func vertex_array(lump_data) -> PackedVector3Array:
	var verts : PackedVector3Array = []
	var count = lump_data.length / 12
	var offset = lump_data.offset
	
	for v in range(0, count, 1):
		var index = v * 12
		var x = bsp_bytes.slice(offset + index, offset + index + 12).decode_float(0)
		var y = bsp_bytes.slice(offset + index, offset + index + 12).decode_float(4)
		var z = bsp_bytes.slice(offset + index, offset + index + 12).decode_float(8)
		verts.append(Vector3(x, z, -y))
	return verts
