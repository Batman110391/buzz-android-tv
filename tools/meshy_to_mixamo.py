# Blender: FBX di Meshy -> zip per l'auto-rigger di Mixamo (una mesh, ~20k triangoli, OBJ+MTL+albedo, nessuno scheletro)
# + anteprima frontale. Uso: blender -b --python meshy_to_mixamo.py -- <fbx> <albedo.png> <out_dir>
import bpy, sys, os, shutil, zipfile, mathutils
src, albedo, out = sys.argv[sys.argv.index("--") + 1:]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
o = max((x for x in bpy.data.objects if x.type == 'MESH'), key=lambda x: len(x.data.vertices))
for x in list(bpy.data.objects):
    if x != o:
        bpy.data.objects.remove(x, do_unlink=True)
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
d = o.modifiers.new("dec", 'DECIMATE'); d.ratio = min(1.0, 20000 / tris)
bpy.ops.object.modifier_apply(modifier="dec")
print("TRIS", tris, "->", sum(len(p.vertices) - 2 for p in o.data.polygons), "dims", tuple(round(v, 3) for v in o.dimensions))
obj = os.path.join(out, "host.obj")
bpy.ops.wm.obj_export(filepath=obj, export_selected_objects=True, export_materials=True)
mat = next(l.split(" ", 1)[1].strip() for l in open(obj) if l.startswith("usemtl"))
open(os.path.join(out, "host.mtl"), "w").write(f"newmtl {mat}\nKd 1 1 1\nmap_Kd host.png\n")
shutil.copy(albedo, os.path.join(out, "host.png"))
with zipfile.ZipFile(os.path.join(out, "host_mixamo.zip"), "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("host.obj", "host.mtl", "host.png"):
        z.write(os.path.join(out, f), f)
pts = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
c = sum(pts, mathutils.Vector()) / 8
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); bpy.context.scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(o.dimensions) * 1.15
cam.location = (c.x, c.y - 10, c.z); cam.rotation_euler = (1.5708, 0, 0)
bpy.context.scene.camera = cam
w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.color = (0.3, 0.3, 0.35)
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x = 600; sc.render.resolution_y = 600; sc.render.filepath = os.path.join(out, "preview.png")
bpy.ops.render.render(write_still=True)
