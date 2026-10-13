# Genera le animazioni walk/strut/point/laugh/taunt sullo scheletro Mixamo di assets/animations/idle.fbx.
# Uso (da Blender, nessun Python di sistema):
#   blender -b --python tools/make_anims.py -- [anim ...] [--out DIR] [--preview DIR]
# Senza nomi genera tutte. --preview scrive due strisce PNG (fronte/lato) di scheletro per controllare le pose.
# Ogni osso e' una rotazione "delta" in assi mondo (X laterale sinistra+, Y su, Z avanti) sopra la posa dell'idle;
# le gambe sono risolte con IK a 2 ossa (piedi piantati: nessuno scivolamento in `walk`/`strut`).
import bpy, sys, os, math, bisect
from mathutils import Vector, Matrix, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FPS = 30
PFX = "mixamorig:"
I3 = Matrix.Identity(3)


def R(x=0.0, y=0.0, z=0.0):
    return Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ').to_matrix()


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * u * (u * (6 * u - 15) + 10)


def table(pts, x):
    """Interpolazione a coseno tra punti (x, v)."""
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, v0), (x1, v1) in zip(pts, pts[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * (0.5 - 0.5 * math.cos(math.pi * (x - x0) / (x1 - x0)))
    return pts[-1][1]


class Rig:
    def __init__(s):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "assets", "animations", "idle.fbx"))
        s.arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
        bpy.context.view_layer.objects.active = s.arm
        bpy.context.scene.frame_set(1)
        bones = s.arm.data.bones
        s.par = {b.name: (b.parent.name if b.parent else None) for b in bones}
        s.head = {b.name: b.head_local.copy() for b in bones}
        s.M = {b.name: b.matrix_local.to_3x3() for b in bones}
        s.hips = PFX + "Hips"
        s.order = []

        def walk(n):
            s.order.append(n)
            for c in bones[n].children:
                walk(c.name)
        walk(s.hips)
        s.qi = {pb.name: pb.rotation_quaternion.copy() for pb in s.arm.pose.bones}
        s.hpi = s.head[s.hips] + s.M[s.hips] @ s.arm.pose.bones[s.hips].location
        s.Fi, s.Pi = s.fk(s.qi, s.hpi)
        for n in s.order:
            assert (s.arm.pose.bones[n].head - s.Pi[n]).length < 0.05, "FK diverso da Blender: " + n
        s.legs = {}
        for side in ("Left", "Right"):
            s.legs[side] = [PFX + side + n for n in ("UpLeg", "Leg", "Foot", "ToeBase")]
        s.legset = {n for v in s.legs.values() for n in v}

    def fk(s, quats, hpos):
        F, P = {}, {}
        for n in s.order:
            p = s.par[n]
            if p is None:
                F[n] = s.M[n] @ quats[n].to_matrix()
                P[n] = hpos
            else:
                F[n] = F[p] @ (s.M[p].inverted() @ s.M[n]) @ quats[n].to_matrix()
                P[n] = P[p] + F[p] @ (s.M[p].inverted() @ (s.head[n] - s.head[p]))
        return F, P

    def solve(s, hoff, hrot, ds, feet):
        """hoff: spostamento bacino (cm); hrot: rotazione bacino (mondo); ds: {osso: matrice delta};
        feet: {'Left'/'Right': (posizione caviglia, rotazione piede, rotazione punta)}."""
        F, P, Q = {}, {}, {}
        h = s.hips
        F[h] = hrot @ s.Fi[h]
        P[h] = s.Pi[h] + hoff
        Q[h] = (s.M[h].inverted() @ F[h]).to_quaternion()

        def place(n, Fb):
            p = s.par[n]
            F[n] = Fb
            P[n] = P[p] + F[p] @ (s.M[p].inverted() @ (s.head[n] - s.head[p]))
            Q[n] = (s.M[n].inverted() @ s.M[p] @ (F[p].inverted() @ Fb)).to_quaternion()

        for n in s.order[1:]:
            if n in s.legset:
                if not n.endswith("UpLeg"):
                    continue
                side = "Left" if "Left" in n else "Right"
                up, lg, ft, to = s.legs[side]
                ank, frot, trot = feet[side]
                pu = P[h] + F[h] @ (s.M[h].inverted() @ (s.head[up] - s.head[h]))
                L1 = (s.head[lg] - s.head[up]).length
                L2 = (s.head[ft] - s.head[lg]).length
                v = ank - pu
                d = min(v.length, (L1 + L2) * 0.999)
                u = v.normalized()
                a = math.acos(max(-1.0, min(1.0, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))))
                pole = hrot @ Vector((0.25 if side == "Left" else -0.25, 0, 1))
                pp = (pole - pole.dot(u) * u).normalized()
                knee = pu + L1 * (math.cos(a) * u + math.sin(a) * pp)
                t = (knee - pu).normalized()
                sd = (pu + u * d - knee).normalized()
                v1 = (s.head[lg] - s.head[up]).normalized()
                v2 = (s.head[ft] - s.head[lg]).normalized()
                place(up, v1.rotation_difference(t).to_matrix() @ s.M[up])
                place(lg, v2.rotation_difference(sd).to_matrix() @ s.M[lg])
                place(ft, frot @ s.Fi[ft])
                place(to, trot @ s.Fi[to])
                continue
            p = s.par[n]
            place(n, F[p] @ s.Fi[p].inverted() @ ds.get(n, I3) @ s.Fi[n])
        return Q, P, s.M[h].inverted() @ (P[h] - s.head[h])

    def planted(s):
        return {side: (s.Pi[s.legs[side][2]].copy(), I3, I3) for side in ("Left", "Right")}


# ---------------------------------------------------------------- camminate
GAIT = {
    "walk": dict(frames=24, duty=0.60, S=53.0, fx=11.0, bob=3.5, sway=2.5, yaw=6.0, roll=3.0, lift=8.0,
                 arm=22.0, elbow=14.0, lean=3.0),
    "strut": dict(frames=34, duty=0.62, S=46.0, fx=12.5, bob=4.5, sway=5.0, yaw=9.0, roll=5.0, lift=7.0,
                  arm=16.0, elbow=20.0, lean=-2.0, strut=True),
}


def gait(rig, name, k):
    p = GAIT[name]
    N = p["frames"]
    T = N / FPS
    phi = k / N
    duty, S = p["duty"], p["S"]
    Pi, B = rig.Pi, PFX
    up, lg, ft, to = rig.legs["Left"]
    w = Pi[to] - Pi[ft]
    L1 = (rig.head[lg] - rig.head[up]).length
    L2 = (rig.head[ft] - rig.head[lg]).length
    hj = Pi[up] - Pi[rig.hips]
    z0 = Pi[up].z
    ya = Pi[ft].y
    hmin = math.sqrt((0.99 * (L1 + L2)) ** 2 - (S / 2) ** 2)
    ylow = ya + hmin - hj.y
    c = math.cos(2 * math.pi * phi)
    c3 = math.cos(2 * math.pi * (phi - 0.3))
    hy = ylow + p["bob"] * (0.5 + 0.5 * math.cos(4 * math.pi * (phi - 0.3)))
    hoff = Vector((p["sway"] * c3, hy - Pi[rig.hips].y, 0.0))
    hrot = R(0, -p["yaw"] * c, p["roll"] * c3)
    V = S / (duty * T)
    feet = {}
    for side, off, sgn in (("Left", 0.0, 1), ("Right", 0.5, -1)):
        ph = (phi + off) % 1.0
        if ph < duty:
            z = z0 + S / 2 - S * ph / duty
            lift = 0.0
        else:
            u = (ph - duty) / (1 - duty)
            rear, front = z0 - S / 2, z0 + S / 2
            m = -0.6 * V * (1 - duty) * T
            z = (2 * u**3 - 3 * u**2 + 1) * rear + (u**3 - 2 * u**2 + u) * m + (-2 * u**3 + 3 * u**2) * front + (u**3 - u**2) * m
            lift = p["lift"] * math.sin(math.pi * u)
        th = table([(0, -12), (0.1, 0), (0.45, 0), (0.6, 30), (0.72, 10), (0.88, -10), (1.0, -12)], ph)
        kpiv = 1.0 if ph < duty else 1.0 - smooth((ph - duty) / 0.12)
        thp = max(th, 0.0)
        Rt = R(thp)
        ank = Vector((rig.hpi.x + sgn * p["fx"], ya + lift, z)) + kpiv * (w - Rt @ w)
        tf = (smooth((ph - duty) / 0.1) if ph >= duty else (1.0 if th < 0 else 0.0))
        feet[side] = (ank, R(th), R(th * tf))
    ds = {}
    a, e = p["arm"], p["elbow"]
    for side, sgn, ca in (("Left", 1, c), ("Right", -1, -c)):
        ds[B + side + "Arm"] = R(a * ca, 0, sgn * (p.get("strut") and 14 or 0))
        ds[B + side + "ForeArm"] = R(-(e + 0.6 * e * max(0.0, -ca)), 0, 0)
        if p.get("strut"):
            ds[B + side + "Shoulder"] = R(0, sgn * 8, 0)
    sp = (R(-p["lean"] * 0 + (-4 if p.get("strut") else 1.0), p["yaw"] * 0.4 * c, -p["roll"] * 0.3 * c3),)
    for n in ("Spine", "Spine1", "Spine2"):
        ds[B + n] = sp[0]
    ds[B + "Neck"] = R(-2 if p.get("strut") else 0, -p["yaw"] * 0.15 * c, p["roll"] * 0.3 * c3)
    ds[B + "Head"] = R(-6 if p.get("strut") else 0, -p["yaw"] * 0.15 * c, p["roll"] * 0.3 * c3 + (3 * math.sin(2 * math.pi * phi) if p.get("strut") else 0))
    return hoff, hrot, ds, feet


# ---------------------------------------------------------------- gesti una tantum
def hold(t0, t1, v):
    return [(t0, v), (t1, v)]


# Ogni spec: lista di (tempo, {nome: (x, y, z)}); nome = osso senza prefisso, "hips_off" (cm) o "hips_rot" (gradi).
POINT = [
    (0.30, dict(RightArm=(14, 0, -6), RightForeArm=(-10, 0, 0), Spine=(-2, -3, 0), Spine1=(-2, -3, 0), Spine2=(-3, -4, 0),
                Head=(0, 3, 0), hips_off=(0, -1.5, -1), hips_rot=(0, -3, 0), LeftArm=(-6, 0, 0))),
    (0.62, dict(RightArm=(-100, -20, 0), RightForeArm=(14, 0, 0), RightShoulder=(0, 8, 0), Spine=(3, 6, 0), Spine1=(3, 7, 0), Spine2=(4, 8, 0),
                Neck=(0, -8, 0), Head=(-3, -12, 0), hips_off=(0, 0.5, 2), hips_rot=(0, 7, 0), LeftArm=(14, 0, 4), LeftForeArm=(-10, 0, 0))),
    (0.85, dict(RightArm=(-92, -20, 0), RightForeArm=(8, 0, 0), RightShoulder=(0, 7, 0), Spine=(3, 5, 0), Spine1=(3, 6, 0), Spine2=(4, 7, 0),
                Neck=(0, -7, 0), Head=(-2, -10, 0), hips_off=(0, 0, 1.5), hips_rot=(0, 6, 0), LeftArm=(12, 0, 4), LeftForeArm=(-10, 0, 0))),
    (1.55, dict(RightArm=(-94, -20, 0), RightForeArm=(10, 0, 0), RightShoulder=(0, 7, 0), Spine=(3, 5, 0), Spine1=(3, 6, 0), Spine2=(4, 7, 0),
                Neck=(0, -7, 0), Head=(-2, -10, 0), hips_off=(0, 0, 1.5), hips_rot=(0, 6, 0), LeftArm=(12, 0, 4), LeftForeArm=(-10, 0, 0))),
]
POINT_DELAY = dict(RightForeArm=0.03, RightHand=0.06, Head=0.05, Neck=0.03, Spine1=0.02, Spine2=0.04, LeftArm=0.04, LeftForeArm=0.07)

LAUGH = [
    (0.35, dict(Spine=(-3, 0, 0), Spine1=(-4, 0, 0), Spine2=(-4, 0, 0), Head=(-6, 0, 0), hips_off=(0, 0.5, 0))),
    (0.8, dict(Spine=(12, 0, 0), Spine1=(14, 0, 0), Spine2=(14, 0, 0), Neck=(-6, 0, 0), Head=(-18, 0, 0), hips_off=(0, -7, 3),
               LeftArm=(-25, 0, 0), RightArm=(-25, 0, 0), LeftForeArm=(-25, 0, 0), RightForeArm=(-25, 0, 0))),
    (1.6, dict(Spine=(14, 0, 0), Spine1=(16, 0, 0), Spine2=(16, 0, 0), Neck=(-8, 0, 0), Head=(-22, 0, 4), hips_off=(0, -8, 3.5),
               LeftArm=(-30, 0, 0), RightArm=(-30, 0, 0), LeftForeArm=(-30, 0, 0), RightForeArm=(-30, 0, 0))),
    (2.0, dict(Spine=(8, 0, 0), Spine1=(9, 0, 0), Spine2=(9, 0, 0), Neck=(-4, 0, 0), Head=(-10, 0, 0), hips_off=(0, -3, 1.5),
               LeftArm=(-12, 0, 0), RightArm=(-12, 0, 0), LeftForeArm=(-15, 0, 0), RightForeArm=(-15, 0, 0))),
]
LAUGH_DELAY = dict(Head=0.04, Neck=0.02, LeftForeArm=0.03, RightForeArm=0.03)


def laugh_extra(t, T):
    env = smooth(t / 0.7) * (1 - smooth((t - 1.9) / 0.6))
    s = math.sin(2 * math.pi * 7.0 * t)
    s2 = math.sin(2 * math.pi * 3.5 * t + 1.0)
    return dict(hips_off=(0, 1.2 * env * s, 0), Spine2=(3.5 * env * s, 0, 0), Spine1=(2 * env * s, 0, 0),
                LeftShoulder=(0, 0, 5 * env * s), RightShoulder=(0, 0, -5 * env * s), Head=(-3 * env * s, 0, 2 * env * s2))


TAUNT = [
    (0.25, dict(Spine=(-2, 0, 0), Spine1=(-2, 0, 0), Spine2=(-3, 0, 0), hips_off=(0, -3, -1.5), LeftArm=(5, 0, 6), RightArm=(5, 0, -6))),
    (0.55, dict(Spine=(-4, 0, 0), Spine1=(-5, 0, 0), Spine2=(-6, 0, 0), Neck=(-2, 0, 0), Head=(-8, 0, 0), hips_off=(0, 1.0, -2.5),
                LeftArm=(-35, 0, 28), RightArm=(-35, 0, -28), LeftForeArm=(0, 0, 135), RightForeArm=(0, 0, -135),
                LeftHand=(0, 0, 0), RightHand=(0, 0, 0))),
    (1.55, dict(Spine=(-4, 0, 0), Spine1=(-5, 0, 0), Spine2=(-6, 0, 0), Neck=(-2, 0, 0), Head=(-8, 0, 0), hips_off=(0, 1.0, -2.5),
                LeftArm=(-35, 0, 28), RightArm=(-35, 0, -28), LeftForeArm=(0, 0, 135), RightForeArm=(0, 0, -135))),
    (1.85, dict(Spine=(1, 0, 0), Spine1=(1, 0, 0), Spine2=(1, 0, 0), hips_off=(0, -1, 0), LeftArm=(-8, 0, 20), RightArm=(-8, 0, -20),
                LeftForeArm=(0, 0, 30), RightForeArm=(0, 0, -30))),
]
TAUNT_DELAY = dict(Head=0.04, Neck=0.02, LeftForeArm=0.03, RightForeArm=0.03)


def taunt_extra(t, T):
    env = smooth((t - 0.4) / 0.25) * (1 - smooth((t - 1.55) / 0.25))
    s = math.sin(2 * math.pi * 3.0 * t)
    w = math.sin(2 * math.pi * 6.0 * t)
    return dict(Head=(0, 0, 14 * env * s), Neck=(0, 0, 8 * env * s), hips_off=(3 * env * s, 0.8 * env * abs(w), 0),
                hips_rot=(0, 0, 5 * env * s), Spine1=(0, 0, -4 * env * s),
                LeftHand=(0, 0, 25 * env * w), RightHand=(0, 0, 25 * env * w))


ONCE = {
    "point": (2.0, POINT, POINT_DELAY, None),
    "laugh": (2.5, LAUGH, LAUGH_DELAY, laugh_extra),
    "taunt": (2.0, TAUNT, TAUNT_DELAY, taunt_extra),
}


def cr(keys, t):
    """Catmull-Rom (tangenti nulle agli estremi) su [(t, v)] ordinati."""
    ts = [k[0] for k in keys]
    if t <= ts[0]:
        return keys[0][1]
    if t >= ts[-1]:
        return keys[-1][1]
    i = bisect.bisect_right(ts, t) - 1

    def tan(j):
        if j == 0 or j == len(keys) - 1:
            return 0.0
        return (keys[j + 1][1] - keys[j - 1][1]) / (ts[j + 1] - ts[j - 1])
    h = ts[i + 1] - ts[i]
    u = (t - ts[i]) / h
    m0, m1 = tan(i) * h, tan(i + 1) * h
    p0, p1 = keys[i][1], keys[i + 1][1]
    return (2 * u**3 - 3 * u**2 + 1) * p0 + (u**3 - 2 * u**2 + u) * m0 + (-2 * u**3 + 3 * u**2) * p1 + (u**3 - u**2) * m1


def once(rig, name, k):
    T, spec, delay, extra = ONCE[name]
    t = k / FPS
    chans = {}
    for tk, d in spec:
        for n, v in d.items():
            for i in range(3):
                chans.setdefault((n, i), []).append((tk, v[i]))
    for ch in chans.values():
        for te in (0.0, T):
            if not any(abs(a - te) < 1e-6 for a, _ in ch):
                ch.append((te, 0.0))
        ch.sort()
    vals = {}
    for (n, i), ch in chans.items():
        vals.setdefault(n, [0.0, 0.0, 0.0])[i] = cr(ch, max(0.0, t - delay.get(n, 0.0)))
    if extra:
        for n, v in extra(t, T).items():
            cur = vals.setdefault(n, [0.0, 0.0, 0.0])
            for i in range(3):
                cur[i] += v[i]
    ho = vals.pop("hips_off", [0, 0, 0])
    hr = vals.pop("hips_rot", [0, 0, 0])
    ds = {PFX + n: R(*v) for n, v in vals.items()}
    return Vector(ho), R(*hr), ds, rig.planted()


def build(rig, name):
    """Restituisce la lista di frame [(Q, P, hips_loc)]; per i loop l'ultimo frame e' uguale al primo."""
    if name in GAIT:
        n = GAIT[name]["frames"]
        fn = lambda k: gait(rig, name, k)
    else:
        n = round(ONCE[name][0] * FPS)
        fn = lambda k: once(rig, name, k)
    return [rig.solve(*fn(k)) for k in range(n + 1)]


# ---------------------------------------------------------------- export
def export(rig, frames, path):
    arm = rig.arm
    arm.animation_data_clear()
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, len(frames)
    prev = {}
    for k, (Q, P, loc) in enumerate(frames):
        f = k + 1
        for n, q in Q.items():
            if n in prev:
                q.make_compatible(prev[n])
            prev[n] = q
            pb = arm.pose.bones[n]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
        hb = arm.pose.bones[rig.hips]
        hb.location = loc
        hb.keyframe_insert("location", frame=f)
    bpy.ops.export_scene.fbx(filepath=path, object_types={'ARMATURE'}, add_leaf_bones=False, bake_anim=True,
                             bake_anim_use_all_bones=True, bake_anim_simplify_factor=0.0, bake_anim_use_nla_strips=False,
                             bake_anim_use_all_actions=False, axis_forward='-Z', axis_up='Y', apply_scale_options='FBX_SCALE_NONE')


# ---------------------------------------------------------------- anteprima (scheletro stilizzato)
def preview(rig, frames, picks, path_prefix):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.light = 'FLAT'
    sc.render.resolution_x, sc.render.resolution_y = 2400, 900
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.85, 0.87, 0.9)
    mats = {}
    for k, col in (("L", (0.9, 0.2, 0.2, 1)), ("R", (0.2, 0.4, 0.95, 1)), ("C", (0.25, 0.25, 0.25, 1)), ("G", (0.5, 0.7, 0.4, 1))):
        m = bpy.data.materials.new(k)
        m.diffuse_color = col
        mats[k] = m
    skip = ("Thumb", "Index", "Ring", "Pinky", "HandMiddle2", "HandMiddle3", "HandMiddle4", "Toe_End", "HeadTop")
    for axis in ("front", "side"):
        for o in list(bpy.data.objects):
            if o.type != 'ARMATURE':
                bpy.data.objects.remove(o)
        verts, faces, mi = {"L": [], "R": [], "C": [], "G": []}, {"L": [], "R": [], "C": [], "G": []}, None

        def box(key, a, b, r):
            d = b - a
            if d.length < 1e-3:
                return
            d.normalize()
            x = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized() * r
            y = d.cross(x).normalized() * r
            base = len(verts[key])
            verts[key] += [a + x + y, a - x + y, a - x - y, a + x - y, b + x + y, b - x + y, b - x - y, b + x - y]
            faces[key] += [(base + i, base + (i + 1) % 4, base + 4 + (i + 1) % 4, base + 4 + i) for i in range(4)]
        for j, fi in enumerate(picks):
            Q, P, loc = frames[fi]
            off = Vector((95 * j, 0, 0)) if axis == "front" else Vector((0, 0, 70 * j))
            for n in rig.order[1:]:
                if any(sk in n for sk in skip):
                    continue
                p = rig.par[n]
                key = "L" if "Left" in n else "R" if "Right" in n else "C"
                r = 2.2 if ("Hand" in n or "Toe" in n) else 3.2 if "Spine" in n or "Head" in n else 2.6
                box(key, P[p] + off, P[n] + off, r)
        for z0, gx in ((-1, 0),):
            ext = 95 * len(picks) if axis == "front" else 70 * len(picks)
            a = Vector((-60, -1, -60)) if axis == "front" else Vector((-40, -1, -60))
            b = Vector((-60 + ext + 100, 0, 60)) if axis == "front" else Vector((40, 0, -60 + ext + 100))
            box("G", Vector((a.x, -2, 0)), Vector((b.x, -2, 0)) if axis == "front" else Vector((a.x, -2, b.z)), 1.0)
        for key in verts:
            me = bpy.data.meshes.new(key)
            me.from_pydata([tuple(v) for v in verts[key]], [], faces[key])
            ob = bpy.data.objects.new(key, me)
            ob.data.materials.append(mats[key])
            sc.collection.objects.link(ob)
        cam = bpy.data.cameras.new("c")
        cam.type = 'ORTHO'
        cam.ortho_scale = 95 * len(picks) + 40 if axis == "front" else 70 * len(picks) + 40
        co = bpy.data.objects.new("c", cam)
        sc.collection.objects.link(co)
        sc.camera = co
        if axis == "front":
            co.location = (47 * len(picks) - 20, 95, 500)
        else:
            co.rotation_euler = (0, math.radians(90), 0)
            co.location = (500, 95, 35 * len(picks) - 20)
        sc.render.filepath = path_prefix + "_" + axis + ".png"
        bpy.ops.render.render(write_still=True)
        for o in list(bpy.data.objects):
            if o.type != 'ARMATURE':
                bpy.data.objects.remove(o)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.join(ROOT, "assets", "animations")
    prev = None
    names = []
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out = argv[i + 1]
            i += 1
        elif argv[i] == "--preview":
            prev = argv[i + 1]
            i += 1
        else:
            names.append(argv[i])
        i += 1
    for name in names or ["walk", "strut", "point", "laugh", "taunt"]:
        rig = Rig()
        frames = build(rig, name)
        if name in GAIT:
            p = GAIT[name]
            print("SPEED", name, "m/s (scala Mixamo) =", round(p["S"] / (p["duty"] * p["frames"] / FPS) / 100, 3))
        if prev:
            n = len(frames) - 1
            picks = [round(n * j / 8) for j in range(8)] if name in GAIT else [round(n * f) for f in (0.0, 0.1, 0.22, 0.33, 0.45, 0.6, 0.78, 1.0)]
            preview(rig, frames, picks, os.path.join(prev, name))
        else:
            export(rig, frames, os.path.join(out, name + ".fbx"))
            print("OK", name, len(frames), "frame")


main()
