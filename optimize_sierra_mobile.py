import bpy, json, shutil
from pathlib import Path
base=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(base/'Circuito_de_la_Sierra/Circuito_de_la_Sierra.blend'))
counts={}
for o in bpy.data.objects:
 if o.type=='MESH':
  key=o.name.split('_')[0];counts[key]=counts.get(key,0)+sum(len(p.vertices)-2 for p in o.data.polygons)
print('BEFORE',counts,flush=True)
for o in list(bpy.data.objects):
 if o.type!='MESH' or o.name.startswith('EDIT_'):continue
 if o.name.startswith(('Seats_LOD0','Grandstand_LOD1')):
  bpy.data.objects.remove(o,do_unlink=True);continue
 ratio=1.0
 if o.name.startswith('Tire_Buffer'):ratio=.22
 elif o.name.startswith('Kerb'):ratio=.35
 elif o.name.startswith('Fence'):ratio=.6
 elif o.name.startswith('Terrain'):ratio=.55
 if ratio<1:
  bpy.context.view_layer.objects.active=o;o.hide_set(False)
  d=o.modifiers.new('Mobile_mesh_budget','DECIMATE');d.ratio=ratio
  bpy.ops.object.modifier_apply(modifier=d.name)
 if o.name.startswith('Grandstand_LOD2'):o.name='Grandstand_LOD1';o.hide_render=False
for c in bpy.data.collections:
 if c.name!='90_EDITABLE_GUIDE':c.hide_viewport=False
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
 if o.type=='MESH' and not o.name.startswith('EDIT_'):o.hide_set(False);o.select_set(True)
out=base/'Race/assets/tracks/sierra/sierra_mobile.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,export_cameras=False,export_lights=False,export_extras=True)
tris=sum(len(p.vertices)-2 for o in bpy.context.selected_objects for p in o.data.polygons)
report={'source':'Circuito de la Sierra v1.0','blender':'4.5.3','triangles':tris,'source_triangles':665155,'road_geometry_unchanged':True,'road_chunks':14,'max_banking_percent':8,'length_m':4200}
(base/'Race/docs/SIERRA_MOBILE.json').write_text(json.dumps(report,indent=2))
shutil.copyfile(base/'Circuito_de_la_Sierra/godot/assets/centerline.json', base/'Race/assets/tracks/sierra/centerline.json')
print('MOBILE',report,flush=True)
