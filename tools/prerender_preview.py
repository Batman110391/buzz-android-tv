# Anteprima "2D pre-renderizzato": studio in Blender + personaggi Mixamo in passate separate (bg / chars / refl / mask) + composizione.
# Uso: blender -b --python tools/prerender_preview.py -- <out_dir> [stage ...]   (stage: bg chars refl mask sprite comp; default tutti)
# BUZZ_SCALE=50 per render a mezza risoluzione (test veloci). I personaggi .fbx vecchi (v6100) non si leggono in Blender:
# servono i .glb convertiti con Godot in <out_dir>/glb/<nome>.glb (host.fbx e' leggibile direttamente).
import bpy, bmesh, math, random, sys, os, time
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
STAGES = argv[1:] or ["bg", "chars", "refl", "mask", "sprite", "comp"]
SCALE = int(os.environ.get("BUZZ_SCALE", "100"))
W, H = 1920, 1080
random.seed(7)
POOL = '2048'

# ---------------------------------------------------------------- utilita'
def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o

def mat(name, color=(0.5, 0.5, 0.5), rough=0.5, metal=0.0, emit=None, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    b = n["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

def emission(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n = m.node_tree.nodes
    n.clear()
    e = n.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    o = n.new("ShaderNodeOutputMaterial")
    m.node_tree.links.new(e.outputs[0], o.inputs[0])
    return m

def mesh_obj(name, bm, material, shadow=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(material)
    o.visible_shadow = shadow
    for p in me.polygons:
        p.use_smooth = True
    return o

def tube(bm, p0, p1, r0, r1=None, seg=8, fade=None):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    n0 = len(bm.verts)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r0 if r1 is None else r1,
                              depth=d.length, matrix=Matrix.Translation((p0 + p1) / 2) @ rot)
    if fade is not None:  # fade[0] sul vertice del p0 (z locale negativo), fade[1] su p1
        lay = bm.verts.layers.float.get("fade") or bm.verts.layers.float.new("fade")
        bm.verts.ensure_lookup_table()
        for v in bm.verts[n0:]:
            v[lay] = fade[1] if (v.co - p1).length < (v.co - p0).length else fade[0]

def arc_strip(bm, r0, r1, z0, z1, a0, a1, n, kind):
    """kind 'top': corona piana a z1 tra r0 e r1; 'front': parete a r0 tra z0 e z1; 'wall'."""
    for i in range(n):
        t0 = math.radians(a0 + (a1 - a0) * i / n)
        t1 = math.radians(a0 + (a1 - a0) * (i + 1) / n)
        def P(r, z, t): return bm.verts.new((r * math.cos(t), r * math.sin(t), z))
        if kind == "top":
            bm.faces.new((P(r0, z1, t0), P(r1, z1, t0), P(r1, z1, t1), P(r0, z1, t1)))
        else:
            bm.faces.new((P(r0, z0, t0), P(r0, z1, t0), P(r0, z1, t1), P(r0, z0, t1)))

def ramp(nodes, links, fac, stops):
    cr = nodes.new("ShaderNodeValToRGB")
    el = cr.color_ramp.elements
    while len(el) > 1:
        el.remove(el[0])
    for i, (p, c) in enumerate(stops):
        e = el[0] if i == 0 else el.new(p)
        e.position = p
        e.color = (*c, 1)
    links.new(fac, cr.inputs[0])
    return cr

# ---------------------------------------------------------------- studio
STUDIO, UNDER, CONES, PODIUMS = [], [], [], []
LIGHTS_CHARS_ONLY = []
CAM_POS, CAM_TGT = Vector((0, -5.4, 2.6)), Vector((0, 3.0, 1.75))

def build_studio():
    sc = bpy.context.scene
    # mondo
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.015, 0.05, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.25

    # pavimento pedana: blu notte lucido + puntini luminosi (Voronoi senza casualita')
    m = mat("floor", (0.015, 0.025, 0.1), rough=0.07)
    nt = m.node_tree; n, l = nt.nodes, nt.links
    tc = n.new("ShaderNodeTexCoord"); mp = n.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1, 1, 1)
    vo = n.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 1.4; vo.inputs["Randomness"].default_value = 0.0
    l.new(tc.outputs["Object"], mp.inputs[0]); l.new(mp.outputs[0], vo.inputs["Vector"])
    dots = ramp(n, l, vo.outputs["Distance"], [(0.0, (1, 1, 1)), (0.2, (1, 1, 1)), (0.3, (0, 0, 0))])
    no = n.new("ShaderNodeTexNoise"); no.inputs["Scale"].default_value = 0.35
    l.new(tc.outputs["Object"], no.inputs["Vector"])
    col = ramp(n, l, no.outputs["Fac"], [(0.3, (0.15, 0.85, 1.0)), (0.55, (0.9, 0.3, 1.0)), (0.75, (1.0, 0.55, 0.2))])
    mx = n.new("ShaderNodeMix"); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs[0].default_value = 1
    l.new(dots.outputs[0], mx.inputs[6]); l.new(col.outputs[0], mx.inputs[7])
    b = n["Principled BSDF"]
    l.new(mx.outputs[2], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = 5.0
    # base: anelli concentrici tenui
    bpy.ops.mesh.primitive_cylinder_add(radius=6.2, depth=0.4, location=(0, 0, -0.2), vertices=96)
    top = bpy.context.object; top.name = "platform"; top.data.materials.append(m)
    STUDIO.append(top); UNDER.append(top)
    # pavimento fuori dalla pedana
    bpy.ops.mesh.primitive_cylinder_add(radius=16, depth=0.2, location=(0, 0, -0.5), vertices=96)
    fl = bpy.context.object; fl.name = "outer_floor"; fl.data.materials.append(mat("outer", (0.01, 0.015, 0.05), 0.15))
    STUDIO.append(fl); UNDER.append(fl)
    # anello neon ciano al bordo + secondo anello arancio piu' fuori
    for r, z, rad, c, s in ((6.2, 0.02, 0.06, (0.1, 0.9, 1.0), 14), (6.55, -0.05, 0.05, (1.0, 0.4, 0.05), 10), (5.6, 0.005, 0.02, (0.1, 0.6, 1.0), 6)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=rad, major_segments=128, minor_segments=10, location=(0, 0, z))
        t = bpy.context.object; t.data.materials.append(emission("neon", c, s)); t.visible_shadow = False; STUDIO.append(t)

    # fascia arancio dietro la pedana + gradinate con pubblico
    orange = emission("fascia", (1.0, 0.33, 0.04), 1.6)
    bm = bmesh.new(); arc_strip(bm, 7.0, 0, -0.5, 0.55, -10, 190, 64, "front"); STUDIO.append(mesh_obj("fascia", bm, orange, False))
    dark = mat("tier", (0.02, 0.02, 0.05), 0.4)
    steps = [(8.0, 9.0, 0.55, 1.0), (9.0, 10.0, 1.0, 1.45), (10.0, 11.0, 1.45, 1.9), (11.0, 12.0, 1.9, 2.35)]
    bm_top, bm_f = bmesh.new(), bmesh.new()
    for r0, r1, z0, z1 in steps:
        arc_strip(bm_top, r0, r1, z0, z1, -10, 190, 64, "top")
        arc_strip(bm_f, r0, 0, z0, z1 - 0.12, -10, 190, 64, "front")
    STUDIO.append(mesh_obj("tier_top", bm_top, dark))
    STUDIO.append(mesh_obj("tier_front", bm_f, emission("tierfront", (1.0, 0.3, 0.03), 0.9), False))
    # pubblico: silhouette scure (corpo+testa) + qualche braccio alzato
    bm = bmesh.new()
    for r0, r1, z0, z1 in steps:
        rm = (r0 + r1) / 2 + 0.1
        n_p = int(math.radians(185) * rm / 0.5)
        for i in range(n_p):
            a = math.radians(-8 + 185 * (i + random.random() * 0.4) / n_p)
            hgt = 0.7 + random.random() * 0.15
            base = Vector((rm * math.cos(a), rm * math.sin(a), z1))
            bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1, matrix=Matrix.Translation(base + Vector((0, 0, hgt * 0.4))) @ Matrix.Diagonal((0.2, 0.15, hgt * 0.4, 1)))
            bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.1, matrix=Matrix.Translation(base + Vector((0, 0, hgt * 0.95))))
            if random.random() < 0.25:
                tube(bm, base + Vector((0.2, 0, hgt * 0.7)), base + Vector((0.3, 0, hgt * 1.35)), 0.04, seg=5)
    STUDIO.append(mesh_obj("crowd", bm, mat("crowd", (0.004, 0.004, 0.012), 1.0)))
    # lucine del pubblico (bloom)
    for ci, c in enumerate(((1.0, 0.45, 0.1), (0.2, 0.8, 1.0), (1.0, 1.0, 0.9), (1.0, 0.3, 0.7))):
        bm = bmesh.new()
        for _ in range(60):
            a = math.radians(-8 + 185 * random.random()); r = 8.2 + random.random() * 3.6
            z = 0.55 + (r - 8) / 4 * 1.8 + 0.9 + random.random() * 0.5
            bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.04, matrix=Matrix.Translation((r * math.cos(a), r * math.sin(a), z)))
        STUDIO.append(mesh_obj("lights%d" % ci, bm, emission("lamp%d" % ci, c, 60), False))

    # parete di fondo + anelli neon + schermi
    wm = mat("wall", (0.004, 0.003, 0.015), 0.3)
    nt = wm.node_tree; n, l = nt.nodes, nt.links
    tc = n.new("ShaderNodeTexCoord"); sp = n.new("ShaderNodeSeparateXYZ"); l.new(tc.outputs["Object"], sp.inputs[0])
    g = ramp(n, l, sp.outputs["Z"], [(0.0, (0.7, 0.25, 0.9)), (0.35, (0.25, 0.1, 0.65)), (0.9, (0.02, 0.03, 0.2))])
    mr = n.new("ShaderNodeMapRange"); mr.inputs[1].default_value = 3; mr.inputs[2].default_value = 12; l.new(sp.outputs["Z"], mr.inputs[0])
    nt.links.remove(g.inputs[0].links[0]); l.new(mr.outputs[0], g.inputs[0])
    l.new(g.outputs[0], n["Principled BSDF"].inputs["Emission Color"]); n["Principled BSDF"].inputs["Emission Strength"].default_value = 0.3
    bm = bmesh.new(); arc_strip(bm, 15, 0, -0.5, 13, -25, 205, 72, "front"); STUDIO.append(mesh_obj("wall", bm, wm, False))
    for r, c, s in ((7.2, (1.0, 0.45, 0.08), 9), (6.3, (0.1, 0.85, 1.0), 9)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.1, major_segments=128, minor_segments=10, location=(0, 14.3, 5.2), rotation=(math.pi / 2, 0, 0))
        t = bpy.context.object; t.data.materials.append(emission("ring", c, s)); t.visible_shadow = False; STUDIO.append(t)
    # schermo centrale
    sm = bpy.data.materials.new("screen"); sm.use_nodes = True
    n, l = sm.node_tree.nodes, sm.node_tree.links; n.clear()
    tc = n.new("ShaderNodeTexCoord"); sp = n.new("ShaderNodeSeparateXYZ"); l.new(tc.outputs["UV"], sp.inputs[0])
    g = ramp(n, l, sp.outputs["Y"], [(0.0, (1.0, 0.5, 0.1)), (0.3, (0.55, 0.15, 0.75)), (0.7, (0.12, 0.1, 0.55)), (1.0, (0.03, 0.06, 0.3))])
    e = n.new("ShaderNodeEmission"); e.inputs["Strength"].default_value = 1.0; l.new(g.outputs[0], e.inputs[0])
    o = n.new("ShaderNodeOutputMaterial"); l.new(e.outputs[0], o.inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 14.5, 5.2), rotation=(math.pi / 2, 0, 0)); sc_ = bpy.context.object
    sc_.scale = (9.5, 4.8, 1); sc_.data.materials.append(sm); STUDIO.append(sc_)
    # cornice schermo
    bm = bmesh.new()
    for (a, b_) in (((-4.9, 7.7), (4.9, 7.7)), ((-4.9, 2.7), (4.9, 2.7))):
        tube(bm, (a[0], 14.4, a[1]), (b_[0], 14.4, b_[1]), 0.07)
    for x in (-4.9, 4.9): tube(bm, (x, 14.4, 2.7), (x, 14.4, 7.7), 0.07)
    STUDIO.append(mesh_obj("frame", bm, emission("frame", (0.2, 0.9, 1.0), 12), False))
    # schermi laterali
    for side in (-1, 1):
        ang = math.radians(90 + side * 44)
        pos = (13.6 * math.cos(ang), 13.6 * math.sin(ang), 5.0)
        sm2 = bpy.data.materials.new("sscreen"); sm2.use_nodes = True
        n, l = sm2.node_tree.nodes, sm2.node_tree.links; n.clear()
        tc = n.new("ShaderNodeTexCoord"); wv = n.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 3; wv.inputs["Distortion"].default_value = 8
        l.new(tc.outputs["UV"], wv.inputs["Vector"])
        g = ramp(n, l, wv.outputs["Color"], [(0.0, (0.05, 0.1, 0.5)), (0.5, (0.1, 0.8, 1.0)), (1.0, (1.0, 0.45, 0.1))])
        e = n.new("ShaderNodeEmission"); e.inputs["Strength"].default_value = 0.6; l.new(g.outputs[0], e.inputs[0])
        o = n.new("ShaderNodeOutputMaterial"); l.new(e.outputs[0], o.inputs[0])
        bpy.ops.mesh.primitive_plane_add(size=1, location=pos, rotation=(math.pi / 2, 0, ang - math.pi / 2)); p = bpy.context.object
        p.scale = (3.4, 5.0, 1); p.data.materials.append(sm2); STUDIO.append(p)
    # scritta
    cu = bpy.data.curves.new("txt", 'FONT'); cu.body = "QUIZ PARTY!"; cu.size = 1.5; cu.extrude = 0.08; cu.bevel_depth = 0.02
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'
    t = link(bpy.data.objects.new("title", cu)); t.location = (0, 14.35, 5.3); t.rotation_euler = (math.pi / 2, 0, 0)
    t.data.materials.append(emission("title", (1.0, 0.45, 0.05), 2.2)); t.visible_shadow = False; STUDIO.append(t)

    # americane + faretti + coni
    bm_t, bm_f2 = bmesh.new(), bmesh.new()
    cone_bm = {}
    cols = [(1.0, 0.45, 0.08), (0.15, 0.7, 1.0), (1.0, 0.45, 0.08), (0.25, 0.4, 1.0), (1.0, 0.3, 0.6), (0.15, 0.85, 1.0)]
    for (y, z, hw) in ((5.5, 5.6, 6.5), (9.5, 6.7, 8.0)):
        for dz in (0.0, 0.5):
            tube(bm_t, (-hw, y, z + dz), (hw, y, z + dz), 0.05)
        for x in np.arange(-hw, hw, 0.6):
            tube(bm_t, (x, y, z), (x + 0.3, y, z + 0.5), 0.02, seg=5); tube(bm_t, (x + 0.3, y, z + 0.5), (x + 0.6, y, z), 0.02, seg=5)
    STUDIO.append(mesh_obj("truss", bm_t, mat("truss", (0.08, 0.08, 0.1), 0.35, 0.9)))
    targets = [(-3.2, 1.8), (3.2, 1.8), (-1.2, 3.0), (1.2, 3.0), (-5.0, 0.5), (5.0, 0.5), (0.0, 2.0), (-2.0, 0.8), (2.0, 0.8)]
    fixtures = [(-4.5, 5.5, 5.5), (4.5, 5.5, 5.5), (-1.5, 5.5, 5.5), (1.5, 5.5, 5.5), (-6.5, 9.5, 6.6), (6.5, 9.5, 6.6), (-3, 9.5, 6.6), (3, 9.5, 6.6), (0, 9.5, 6.6)]
    for i, (fx, tg) in enumerate(zip(fixtures, targets)):
        c = cols[i % len(cols)]
        p0 = Vector((fx[0], fx[1], fx[2] - 0.2)); p1 = Vector((tg[0], tg[1], 0.0))
        d = (p1 - p0).normalized()
        tube(bm_f2, p0 - d * 0.1, p0 + d * 0.35, 0.2, 0.15)
        cb = cone_bm.setdefault(i % len(cols), bmesh.new())
        tube(cb, p0 + d * 0.36, p1, 0.12, 0.9, seg=24, fade=(1.0, 0.0))
        lens = cone_bm.setdefault(("lens", i % len(cols)), bmesh.new())
        tube(lens, p0 + d * 0.34, p0 + d * 0.37, 0.15, seg=12)
        lt = bpy.data.lights.new("spot%d" % i, 'SPOT'); lt.color = c; lt.energy = 900; lt.spot_size = math.radians(30); lt.spot_blend = 0.5; lt.shadow_soft_size = 0.2
        lo = link(bpy.data.objects.new("spot%d" % i, lt)); lo.location = p0; lo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    STUDIO.append(mesh_obj("fixtures", bm_f2, mat("fix", (0.03, 0.03, 0.04), 0.4, 0.8)))
    for k, bmx in cone_bm.items():
        if isinstance(k, tuple):
            STUDIO.append(mesh_obj("lens", bmx, emission("lens", cols[k[1]], 40), False)); continue
        m = bpy.data.materials.new("cone"); m.use_nodes = True
        n, l = m.node_tree.nodes, m.node_tree.links; n.clear()
        at = n.new("ShaderNodeAttribute"); at.attribute_name = "fade"
        ma = n.new("ShaderNodeMath"); ma.operation = 'POWER'; ma.inputs[1].default_value = 1.6; l.new(at.outputs["Fac"], ma.inputs[0])
        mu = n.new("ShaderNodeMath"); mu.operation = 'MULTIPLY'; mu.inputs[1].default_value = 0.09; l.new(ma.outputs[0], mu.inputs[0])
        e = n.new("ShaderNodeEmission"); e.inputs["Color"].default_value = (*cols[k], 1); e.inputs["Strength"].default_value = 1.2
        tr = n.new("ShaderNodeBsdfTransparent"); mx = n.new("ShaderNodeMixShader")
        l.new(mu.outputs[0], mx.inputs[0]); l.new(tr.outputs[0], mx.inputs[1]); l.new(e.outputs[0], mx.inputs[2])
        o = n.new("ShaderNodeOutputMaterial"); l.new(mx.outputs[0], o.inputs[0])
        m.surface_render_method = 'BLENDED'; co = mesh_obj("cones%d" % k, bmx, m, False); STUDIO.append(co); CONES.append(co)

    # luci d'ambiente: key calda frontale, rim ciano a destra, rim arancio a sinistra
    def area(name, loc, color, energy, size, tgt=(0, 2, 1.0)):
        a = bpy.data.lights.new(name, 'AREA'); a.color = color; a.energy = energy; a.size = size
        o = link(bpy.data.objects.new(name, a)); o.location = loc
        o.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        return o
    area("key", (-3.5, -5.5, 5.0), (1.0, 0.82, 0.65), 520, 4)
    area("fill", (4.0, -5.0, 2.5), (0.5, 0.7, 1.0), 250, 4)
    area("rimC", (6.5, 6.5, 3.5), (0.1, 0.8, 1.0), 1400, 3)
    area("rimO", (-6.5, 6.5, 3.5), (1.0, 0.45, 0.1), 1400, 3)
    LIGHTS_CHARS_ONLY.append(area("bounce", (0, 1.5, 0.04), (0.55, 0.3, 1.0), 120, 8, tgt=(0, 1.5, 3)))

def build_podiums():
    pos = [(-2.8, 3.1), (-0.95, 2.5), (0.95, 2.5), (2.8, 3.1)]
    names = ["LOLA", "ELVIO", "SMERALDA", "POLPETTA"]
    cols = [(0.9, 0.05, 0.05), (0.05, 0.25, 0.95), (0.05, 0.75, 0.12), (1.0, 0.8, 0.05)]
    for (x, y), nm, c in zip(pos, names, cols):
        th = math.atan2(-x, 6 + y)
        pm = mat("pod_" + nm, c, 0.25, 0.1)
        bm = bmesh.new()
        r = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(1.05, 0.8, 0.8), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(0, 0, 0.4), verts=bm.verts)
        po = mesh_obj("pod_" + nm, bm, pm)
        # bordo superiore piu' chiaro / pulsante
        bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.15, radius2=0.12, depth=0.06, matrix=Matrix.Translation((0, -0.15, 0.83)))
        bt = mesh_obj("btn_" + nm, bm, emission("btn", (1.0, 0.1, 0.1), 6), False)
        # targhetta
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bmesh.ops.scale(bm, vec=(0.95, 0.02, 0.2), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(0, -0.41, 0.52), verts=bm.verts)
        pl = mesh_obj("plate_" + nm, bm, mat("plate", (0.92, 0.94, 1.0), 0.3, emit=(0.8, 0.85, 1.0), strength=0.6))
        cu = bpy.data.curves.new("n_" + nm, 'FONT'); cu.body = nm; cu.size = 0.15; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = 0.004
        tx = link(bpy.data.objects.new("n_" + nm, cu)); tx.location = (0, -0.43, 0.52); tx.rotation_euler = (math.pi / 2, 0, 0)
        tx.data.materials.append(mat("ink", (0.02, 0.02, 0.05), 0.5))
        par = link(bpy.data.objects.new("podpar_" + nm, None)); par.location = (x, y, 0); par.rotation_euler = (0, 0, th)
        for o in (po, bt, pl, tx): o.parent = par
        PODIUMS.extend([po, bt, pl, tx]); STUDIO.extend([po, bt, pl, tx])
    return pos, cols

def build_camera():
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("cam"); cam.lens = 30; cam.clip_end = 200
    co = link(bpy.data.objects.new("cam", cam)); sc.camera = co
    co.location = CAM_POS
    co.rotation_euler = (CAM_TGT - CAM_POS).to_track_quat('-Z', 'Y').to_euler()
    mc = bpy.data.cameras.new("mcam"); mc.lens = 30; mc.clip_end = 200
    mo = link(bpy.data.objects.new("mcam", mc))
    ml, mt = CAM_POS.copy(), CAM_TGT.copy(); ml.z *= -1; mt.z *= -1
    q = (mt - ml).to_track_quat('-Z', 'Y'); mo.location = ml
    mo.rotation_mode = 'QUATERNION'; mo.rotation_quaternion = q @ Euler((0, 0, math.pi)).to_quaternion()  # su = -Z mondo
    return co, mo

# ---------------------------------------------------------------- personaggi
def load_char(kind):
    before = set(bpy.data.objects)
    if kind == "host":
        bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "assets", "models", "characters", "host.fbx"))
    else:
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "glb", kind + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == 'ARMATURE')
    meshes = [o for o in new if o.type == 'MESH' and o.data.materials]
    for o in new:
        if o not in meshes and o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for m in meshes:
        for ms in m.material_slots:
            b = ms.material.node_tree.nodes.get("Principled BSDF")
            if b:
                b.inputs["Roughness"].default_value = max(0.55, b.inputs["Roughness"].default_value)
    arm.rotation_mode = 'XYZ'
    return arm, meshes

def bbox(meshes):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for m in meshes:
        e = m.evaluated_get(dg)
        pts += [e.matrix_world @ Vector(c) for c in e.bound_box]
    return Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))), Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))

def pose_from(idle, arm, frame_pose):
    """Copia la posa dell'idle (rotazioni in assi mondo rispetto al riposo) sul rig `arm` senza chiamare il depsgraph."""
    n = lambda s: s.replace(":", "_")
    Ai = idle.matrix_world.to_3x3().normalized(); Ac = arm.matrix_world.to_3x3().normalized()
    ipb = {n(p.name): p for p in idle.pose.bones}
    pose = {}
    for pb in arm.pose.bones:
        b = pb.bone
        rest = b.matrix_local
        if b.parent:
            rel = b.parent.matrix_local.inverted() @ rest
            par = pose[b.parent.name]
        else:
            rel, par = rest, Matrix.Identity(4)
        base = par @ rel
        ip = ipb.get(n(pb.name))
        if ip is not None:
            Rd = (Ai @ ip.matrix.to_3x3().normalized()) @ (Ai @ ip.bone.matrix_local.to_3x3().normalized()).inverted()
            R = Ac.inverted() @ (Rd @ (Ac @ rest.to_3x3().normalized()))
            m = R.to_4x4(); m.translation = base.translation
        else:
            m = base
        pose[b.name] = m
        pb.matrix_basis = rel.inverted() @ par.inverted() @ m if b.parent else rel.inverted() @ m

def place(idle, arm, meshes, xy, height, yaw):
    arm.rotation_euler = (math.pi / 2 if arm.rotation_euler.x > 1 else 0, 0, yaw)
    for ob in [arm]: ob.location = (0, 0, 0)
    bpy.context.view_layer.update()
    lo, hi = bbox(meshes)
    s = height / (hi.z - lo.z)
    arm.scale = arm.scale * s
    bpy.context.view_layer.update()

def ground(arm, meshes, xy):
    bpy.context.view_layer.update()
    lo, hi = bbox(meshes)
    hips = arm.matrix_world @ arm.pose.bones[[p.name for p in arm.pose.bones if p.name.endswith("Hips")][0]].head
    arm.location = (arm.location.x + xy[0] - hips.x, arm.location.y + xy[1] - hips.y, arm.location.z - lo.z)
    bpy.context.view_layer.update()

CHARS = []  # (arm, meshes, xy)
def build_chars(pod_pos):
    sc = bpy.context.scene
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "assets", "animations", "idle.fbx"))
    idle = next(o for o in bpy.data.objects if o.type == 'ARMATURE'); idle.hide_render = True
    sc.frame_set(60)
    specs = [("lola", pod_pos[0], 2.05), ("elvio", pod_pos[1], 2.15), ("smeralda", pod_pos[2], 2.1), ("polpetta", pod_pos[3], 2.0)]
    for k, (nm, (x, y), h) in enumerate(specs):
        arm, ms = load_char(nm)
        yaw = math.atan2(-x, 6 + y)
        place(idle, arm, ms, (x, y + 0.65), h, yaw)
        pose_from(idle, arm, 60)
        ground(arm, ms, (x - math.sin(yaw) * -0.65 * 0 + 0.0, y + 0.65))
        CHARS.append((arm, ms, nm))
    arm, ms = load_char("host")
    place(idle, arm, ms, (2.9, 0.6), 1.9, math.radians(-12))
    pose_from(idle, arm, 60)
    ground(arm, ms, (2.9, 0.6))
    CHARS.append((arm, ms, "host"))
    return idle

# ---------------------------------------------------------------- render
def render_setup(path, transparent, samples=24, border=None):
    sc = bpy.context.scene
    r = sc.render
    r.engine = 'BLENDER_EEVEE'
    r.resolution_x, r.resolution_y, r.resolution_percentage = W, H, SCALE
    r.film_transparent = transparent
    r.image_settings.file_format = 'PNG'; r.image_settings.color_mode = 'RGBA'; r.image_settings.color_depth = '8'
    sc.eevee.taa_render_samples = samples
    sc.eevee.use_raytracing = True
    sc.eevee.shadow_pool_size = POOL; sc.eevee.shadow_resolution_scale = 0.5
    sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - High Contrast'
    r.use_border = border is not None; r.use_crop_to_border = border is not None
    if border:
        r.border_min_x, r.border_min_y, r.border_max_x, r.border_max_y = border
    r.filepath = path

def do_render():
    t = time.time(); bpy.ops.render.render(write_still=True); return time.time() - t

def set_mode(mode):
    """mode: bg | chars | refl | mask"""
    sc = bpy.context.scene
    charobjs = [o for (a, ms, _) in CHARS for o in [a] + ms]
    for a, ms, _ in CHARS:
        a.hide_render = mode == "bg" or mode == "mask"
        for m in ms: m.hide_render = mode == "bg" or mode == "mask"
    for o in LIGHTS_CHARS_ONLY: o.hide_render = mode == "bg"
    for o in STUDIO:
        o.is_holdout = mode in ("chars", "refl", "mask") and o not in CONES
        o.hide_render = (mode in ("chars", "refl", "mask") and o in CONES) or (mode == "refl" and o in UNDER)
        if mode == "mask":
            o.is_holdout = o not in PODIUMS
            o.hide_render = False if o in PODIUMS else o.hide_render
    sc.camera = bpy.data.objects["mcam" if mode == "refl" else "cam"]
    for o in UNDER[:1]:
        o.is_shadow_catcher = mode == "chars"

def run():
    t0 = time.time()
    clean()
    build_studio()
    pod_pos, _ = build_podiums()
    build_camera()
    idle = None
    if any(s in STAGES for s in ("chars", "refl", "sprite")):
        idle = build_chars(pod_pos)
    # materiale bianco emissivo per la maschera dei podi
    times = {}
    P = lambda f: os.path.join(OUT, f)
    if "bg" in STAGES:
        set_mode("bg"); render_setup(P("bg_raw.png"), False, 32); times["bg"] = do_render()
    if "chars" in STAGES:
        set_mode("chars"); render_setup(P("chars.png"), True, 32); times["chars"] = do_render()
    if "refl" in STAGES:
        set_mode("refl"); render_setup(P("refl.png"), True, 24); times["refl"] = do_render()
    if "mask" in STAGES:
        set_mode("mask")
        for o in PODIUMS:
            for i in range(len(o.material_slots)): o.material_slots[i].material = emission("mk", (1, 1, 1), 1)
        render_setup(P("mask.png"), True, 8); times["mask"] = do_render()
    if "sprite" in STAGES:
        sprite(idle, P)
    print("TIMES", times, "total", time.time() - t0)

def sprite(idle, P):
    sc = bpy.context.scene
    from bpy_extras.object_utils import world_to_camera_view
    arm, ms, _ = CHARS[-1]
    set_mode("chars"); UNDER[0].is_shadow_catcher = False
    for a, m_, nm in CHARS[:-1]:
        a.hide_render = True
        for m in m_: m.hide_render = True
    frames = list(range(1, 251, 25))
    box = [1, 1, 0, 0]
    dg = bpy.context.evaluated_depsgraph_get()
    for f in frames:
        sc.frame_set(f); pose_from(idle, arm, f); bpy.context.view_layer.update()
        for m in ms:
            e = m.evaluated_get(bpy.context.evaluated_depsgraph_get())
            for c in e.bound_box:
                v = world_to_camera_view(sc, sc.camera, e.matrix_world @ Vector(c))
                box = [min(box[0], v.x), min(box[1], v.y), max(box[2], v.x), max(box[3], v.y)]
    mx, my = (box[2] - box[0]) * 0.04, (box[3] - box[1]) * 0.03
    box = [max(0, box[0] - mx), max(0, box[1] - my), min(1, box[2] + mx), min(1, box[3] + my)]
    os.makedirs(os.path.join(OUT, "sprite"), exist_ok=True)
    for i, f in enumerate(frames):
        sc.frame_set(f); pose_from(idle, arm, f)
        render_setup(os.path.join(OUT, "sprite", "sprite_%04d.png" % i), True, 32, box)
        do_render()
    print("SPRITE_BOX", box, "frames", len(frames))

# ---------------------------------------------------------------- post (numpy)
def load(p):
    im = bpy.data.images.load(p, check_existing=False)
    im.colorspace_settings.name = 'Non-Color'; im.alpha_mode = 'CHANNEL_PACKED'
    w, h = im.size
    a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[::-1].copy()

def save(p, a):
    h, w, _ = a.shape
    im = bpy.data.images.new("o", w, h, alpha=True)
    im.colorspace_settings.name = 'Non-Color'; im.alpha_mode = 'CHANNEL_PACKED'
    im.pixels.foreach_set(np.ascontiguousarray(np.clip(a, 0, 1)[::-1], dtype=np.float32).ravel())
    im.filepath_raw = p; im.file_format = 'PNG'; im.save()

def blur(a, s):
    h, w = a.shape[:2]
    fy = np.fft.fftfreq(h)[:, None]; fx = np.fft.rfftfreq(w)[None, :]
    k = np.exp(-2 * (math.pi ** 2) * s * s * (fx * fx + fy * fy)).astype(np.float32)
    out = np.empty_like(a)
    for c in range(a.shape[2]):
        out[..., c] = np.fft.irfft2(np.fft.rfft2(a[..., c]) * k, s=(h, w))
    return out

def post_bg():
    a = load(os.path.join(OUT, "bg_raw.png"))[..., :3]
    lum = a.max(axis=2, keepdims=True)
    bright = a * np.clip((lum - 0.8) / 0.2, 0, 1) ** 2
    bl = blur(bright, 5) * 0.9 + blur(bright, 18) * 0.9 + blur(bright, 55) * 1.1
    a = a + bl * 0.16
    a = 1 - (1 - np.clip(a, 0, 1)) * 1.0
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    v = 1 - 0.38 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 2
    a = a * v[..., None]
    out = np.concatenate([a, np.ones_like(a[..., :1])], axis=2)
    save(os.path.join(OUT, "bg.png"), out)
    return out

def comp():
    bg = post_bg()
    ch = load(os.path.join(OUT, "chars.png"))
    out = bg.copy()
    rp = os.path.join(OUT, "refl.png"); mp = os.path.join(OUT, "mask.png")
    if os.path.exists(rp):
        rf = load(rp); mk = load(mp)[..., 3:4] if os.path.exists(mp) else 0
        pm = rf[..., :3] * rf[..., 3:4]
        pm = np.concatenate([blur(pm, 2.5), blur(rf[..., 3:4], 2.5)], axis=2)
        # sfumata verso il basso: la riflessione si spegne con la distanza dai piedi
        h = pm.shape[0]
        ar = pm[..., 3:4] * 0.38 * (1 - mk)
        out[..., :3] = out[..., :3] * (1 - ar) + (pm[..., :3] / np.maximum(pm[..., 3:4], 1e-4)) * ar
    a = ch[..., 3:4]
    out[..., :3] = out[..., :3] * (1 - a) + ch[..., :3] * a
    save(os.path.join(OUT, "preview.png"), out)

if __name__ == "__main__":
    if any(s in STAGES for s in ("bg", "chars", "refl", "mask", "sprite")):
        run()
    if "comp" in STAGES:
        comp()
