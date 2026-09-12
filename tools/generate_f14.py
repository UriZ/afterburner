#!/usr/bin/env python3
"""
Generate a low-poly F-14 Tomcat 3D model as GLB using pygltflib.
The model is built from triangulated polygon meshes representing:
- Fuselage (tapered cylinder approximation)
- Swept wings (variable-sweep F-14 shape at ~55° sweep)
- Twin vertical tails
- Horizontal stabilizers
- Engine nacelles

Coordinate convention:
  +X = right, +Y = up, +Z = toward camera (rear of jet)
  Nose points in -Z direction.
  This matches the Godot project convention.

License: CC0 (public domain) — generated procedurally.
"""

import struct
import json
import base64
import numpy as np

# ---------------------------------------------------------------------------
# Low-level GLB builder
# ---------------------------------------------------------------------------

def pack_f32(data):
    return struct.pack(f'<{len(data)}f', *data)

def pack_u16(data):
    return struct.pack(f'<{len(data)}H', *data)


def build_glb(meshes):
    """
    meshes: list of dict with keys:
        name: str
        vertices: list of (x,y,z) tuples
        indices: list of ints (triangles)
        color: (r,g,b) 0-1 floats
    Returns: bytes (GLB binary)
    """

    # We'll build the asset manually.
    accessors = []
    buffer_views = []
    mesh_defs = []
    materials = []
    nodes = []
    binary_chunks = []
    byte_offset = 0

    for mesh in meshes:
        verts = np.array(mesh['vertices'], dtype=np.float32)
        idxs = np.array(mesh['indices'], dtype=np.uint16)

        # Vertex buffer view
        vert_bytes = verts.tobytes()
        buffer_views.append({
            "buffer": 0,
            "byteOffset": byte_offset,
            "byteLength": len(vert_bytes),
            "target": 34962  # ARRAY_BUFFER
        })
        vert_bv_idx = len(buffer_views) - 1
        binary_chunks.append(vert_bytes)
        byte_offset += len(vert_bytes)

        # Accessor for vertices
        mn = verts.min(axis=0).tolist()
        mx = verts.max(axis=0).tolist()
        accessors.append({
            "bufferView": vert_bv_idx,
            "componentType": 5126,  # FLOAT
            "count": len(verts),
            "type": "VEC3",
            "min": mn,
            "max": mx
        })
        vert_acc_idx = len(accessors) - 1

        # Index buffer view
        idx_bytes = idxs.tobytes()
        # Pad to 4-byte alignment
        pad = (4 - len(idx_bytes) % 4) % 4
        idx_bytes_padded = idx_bytes + b'\x00' * pad

        buffer_views.append({
            "buffer": 0,
            "byteOffset": byte_offset,
            "byteLength": len(idx_bytes),
            "target": 34963  # ELEMENT_ARRAY_BUFFER
        })
        idx_bv_idx = len(buffer_views) - 1
        binary_chunks.append(idx_bytes_padded)
        byte_offset += len(idx_bytes_padded)

        # Accessor for indices
        accessors.append({
            "bufferView": idx_bv_idx,
            "componentType": 5123,  # UNSIGNED_SHORT
            "count": len(idxs),
            "type": "SCALAR"
        })
        idx_acc_idx = len(accessors) - 1

        # Material (flat color via baseColorFactor)
        r, g, b = mesh['color']
        materials.append({
            "name": mesh['name'] + "_mat",
            "pbrMetallicRoughness": {
                "baseColorFactor": [r, g, b, 1.0],
                "metallicFactor": mesh.get('metallic', 0.3),
                "roughnessFactor": mesh.get('roughness', 0.7)
            }
        })
        mat_idx = len(materials) - 1

        mesh_defs.append({
            "name": mesh['name'],
            "primitives": [{
                "attributes": {"POSITION": vert_acc_idx},
                "indices": idx_acc_idx,
                "material": mat_idx
            }]
        })
        nodes.append({
            "name": mesh['name'],
            "mesh": len(mesh_defs) - 1
        })

    # Combine binary data
    binary_data = b''.join(binary_chunks)
    # Pad to 4-byte boundary
    pad = (4 - len(binary_data) % 4) % 4
    binary_data += b'\x00' * pad

    gltf_json = {
        "asset": {"version": "2.0", "generator": "afterburner-f14-generator"},
        "scene": 0,
        "scenes": [{"name": "F14Scene", "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": mesh_defs,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "materials": materials,
        "buffers": [{"byteLength": len(binary_data)}]
    }

    json_bytes = json.dumps(gltf_json, separators=(',', ':')).encode('utf-8')
    # Pad JSON to 4-byte boundary with spaces
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b' ' * json_pad

    # GLB header
    MAGIC = b'glTF'
    VERSION = struct.pack('<I', 2)
    # Chunk 0: JSON
    chunk0_type = b'JSON'
    chunk0_len = struct.pack('<I', len(json_bytes))
    # Chunk 1: BIN
    chunk1_type = b'BIN\x00'
    chunk1_len = struct.pack('<I', len(binary_data))

    total_length = 12 + 8 + len(json_bytes) + 8 + len(binary_data)
    header = MAGIC + VERSION + struct.pack('<I', total_length)

    return header + chunk0_len + chunk0_type + json_bytes + chunk1_len + chunk1_type + binary_data


# ---------------------------------------------------------------------------
# Shape builders
# ---------------------------------------------------------------------------

def extrude_polygon_along_z(polygon_xz, z_positions, scale_fn=None):
    """
    polygon_xz: list of (x, y) cross-section points (in XY plane)
    z_positions: list of z values to extrude through
    scale_fn: optional function(z) -> scale factor
    Returns vertices and indices for the extruded shape.
    """
    verts = []
    n = len(polygon_xz)

    for z in z_positions:
        s = scale_fn(z) if scale_fn else 1.0
        for (x, y) in polygon_xz:
            verts.append((x * s, y * s, z))

    indices = []
    num_rings = len(z_positions)
    for ring in range(num_rings - 1):
        base = ring * n
        next_base = (ring + 1) * n
        for i in range(n):
            a = base + i
            b = base + (i + 1) % n
            c = next_base + (i + 1) % n
            d = next_base + i
            # Two triangles per quad
            indices += [a, b, c, a, c, d]

    return verts, indices


def cap_polygon(polygon_xz, z, scale=1.0, flip=False):
    """Generate a flat cap (fan triangulation) for a polygon."""
    cx = sum(p[0] for p in polygon_xz) / len(polygon_xz)
    cy = sum(p[1] for p in polygon_xz) / len(polygon_xz)
    center = (cx * scale, cy * scale, z)
    verts = [center] + [(p[0] * scale, p[1] * scale, z) for p in polygon_xz]
    indices = []
    n = len(polygon_xz)
    for i in range(n):
        a = 0  # center
        b = 1 + i
        c = 1 + (i + 1) % n
        if flip:
            indices += [a, c, b]
        else:
            indices += [a, b, c]
    return verts, indices


def make_circle(radius, segments=8):
    """Return polygon points for a circle in XY plane."""
    import math
    pts = []
    for i in range(segments):
        angle = 2 * math.pi * i / segments
        pts.append((math.cos(angle) * radius, math.sin(angle) * radius))
    return pts


def make_oval(rx, ry, segments=8):
    """Return polygon points for an oval in XY plane."""
    import math
    pts = []
    for i in range(segments):
        angle = 2 * math.pi * i / segments
        pts.append((math.cos(angle) * rx, math.sin(angle) * ry))
    return pts


def combine(vert_list, idx_list):
    """Combine multiple (verts, indices) pairs into one mesh."""
    all_verts = []
    all_indices = []
    offset = 0
    for verts, idxs in zip(vert_list, idx_list):
        all_verts.extend(verts)
        all_indices.extend(i + offset for i in idxs)
        offset += len(verts)
    return all_verts, all_indices


def flat_quad(corners):
    """corners: 4 points [tl, tr, br, bl] -> 2 triangles"""
    a, b, c, d = corners
    verts = [a, b, c, d]
    indices = [0, 1, 2, 0, 2, 3]
    return verts, indices


def make_wing_panel(
    root_le, root_te, tip_le, tip_te,
    thickness=0.08
):
    """
    Build a thin wing panel with 4 corners (leading edge root/tip, trailing edge root/tip).
    Returns (verts, indices).
    Each corner is (x, y, z). The wing is extruded in Y by thickness.
    """
    import numpy as np

    def offset_y(pts, dy):
        return [(p[0], p[1] + dy, p[2]) for p in pts]

    top = [root_le, tip_le, tip_te, root_te]
    bot = offset_y(top, -thickness)

    # Top face
    tv, ti = flat_quad(top)
    # Bottom face (reversed winding)
    bv = bot
    bi_raw = [0, 2, 1, 0, 3, 2]

    # Side faces (4 sides)
    sides = []
    sides_i = []
    pairs = [(top[i], top[(i+1)%4], bot[(i+1)%4], bot[i]) for i in range(4)]
    for quad in pairs:
        sv, si = flat_quad(quad)
        sides.append((sv, si))

    v_all = tv + bv
    i_all = ti + [b + len(tv) for b in bi_raw]
    off = len(v_all)
    for sv, si in sides:
        i_all += [s + off for s in si]
        v_all += sv
        off += len(sv)

    return v_all, i_all


# ---------------------------------------------------------------------------
# F-14 Tomcat geometry
# ---------------------------------------------------------------------------

def build_fuselage():
    """
    F-14 fuselage: tapered body from nose to tail.
    Nose at Z=-4.0, tail at Z=+1.6.
    Cross-section: oval, wider than tall.
    """
    # Cross-section at each Z station: (width, height) scale
    # Z=-4.0 nose tip, Z=+1.6 tail end
    z_stations = [-4.0, -3.2, -2.4, -1.6, -0.6, 0.2, 0.8, 1.2, 1.6]
    # (rx, ry) for oval cross section
    cross_sections = [
        (0.03, 0.03),  # nose tip
        (0.12, 0.10),
        (0.22, 0.17),
        (0.32, 0.24),
        (0.38, 0.28),  # widest at cockpit
        (0.34, 0.26),
        (0.26, 0.20),
        (0.20, 0.16),
        (0.14, 0.12),  # tail end
    ]
    segs = 10
    verts = []
    indices = []

    for si in range(len(z_stations) - 1):
        z0 = z_stations[si]
        z1 = z_stations[si + 1]
        rx0, ry0 = cross_sections[si]
        rx1, ry1 = cross_sections[si + 1]

        ring0 = make_oval(rx0, ry0, segs)
        ring1 = make_oval(rx1, ry1, segs)

        n = segs
        base = len(verts)
        for (x, y) in ring0:
            verts.append((x, y, z0))
        for (x, y) in ring1:
            verts.append((x, y, z1))

        for i in range(n):
            a = base + i
            b = base + (i + 1) % n
            c = base + n + (i + 1) % n
            d = base + n + i
            indices += [a, b, c, a, c, d]

    # Nose cap
    cap_v, cap_i = cap_polygon(make_oval(0.03, 0.03, segs), -4.0, flip=True)
    off = len(verts)
    verts += cap_v
    indices += [i + off for i in cap_i]

    # Tail cap
    cap_v2, cap_i2 = cap_polygon(make_oval(0.14, 0.12, segs), 1.6, flip=False)
    off = len(verts)
    verts += cap_v2
    indices += [i + off for i in cap_i2]

    return verts, indices


def build_spine():
    """Dorsal spine running along the top of the fuselage."""
    # Simple box-like spine
    verts = [
        # Front to back along Z
        (-0.04, 0.28, -2.0), (0.04, 0.28, -2.0),  # front top
        (-0.04, 0.30, -1.2), (0.04, 0.30, -1.2),  # peak
        (-0.04, 0.26, 1.0), (0.04, 0.26, 1.0),    # tail
        (-0.04, 0.18, 1.4), (0.04, 0.18, 1.4),    # tail end
    ]
    # Simplified: just the top surface strip
    indices = [
        0,1,3, 0,3,2,
        2,3,5, 2,5,4,
        4,5,7, 4,7,6,
    ]
    return verts, indices


def build_wing(side=1):
    """
    F-14 variable-sweep wing at ~55° sweep (combat position).
    side: +1 = right, -1 = left
    Wing glove (fixed section) + outer swept panel.
    """
    s = side
    verts = []
    indices = []

    # Glove (fixed wing root) — spans from body to pivot point
    # root_le = leading edge at body
    # tip_le = leading edge at pivot
    glove = make_wing_panel(
        root_le=(s * 0.35, -0.04, -0.60),
        root_te=(s * 0.35, -0.04, 0.30),
        tip_le=(s * 0.80, -0.06, -0.30),
        tip_te=(s * 0.80, -0.06, 0.50),
        thickness=0.07
    )
    v, i = glove
    off = len(verts)
    verts += v
    indices += [x + off for x in i]

    # Outer swept panel — swept at ~55°
    # Leading edge sweeps sharply forward
    outer = make_wing_panel(
        root_le=(s * 0.80, -0.07, -0.30),
        root_te=(s * 0.82, -0.07, 0.50),
        tip_le=(s * 1.90, -0.10, 0.80),
        tip_te=(s * 1.90, -0.10, 1.30),
        thickness=0.045
    )
    v, i = outer
    off = len(verts)
    verts += v
    indices += [x + off for x in i]

    # Wing tip
    tip = make_wing_panel(
        root_le=(s * 1.88, -0.10, 0.78),
        root_te=(s * 1.88, -0.10, 1.30),
        tip_le=(s * 2.05, -0.10, 0.85),
        tip_te=(s * 2.05, -0.10, 1.28),
        thickness=0.025
    )
    v, i = tip
    off = len(verts)
    verts += v
    indices += [x + off for x in i]

    return verts, indices


def build_hstab(side=1):
    """Horizontal stabilizer (all-moving slab on tail)."""
    s = side
    return make_wing_panel(
        root_le=(s * 0.36, -0.06, 0.80),
        root_te=(s * 0.36, -0.06, 1.40),
        tip_le=(s * 0.95, -0.09, 0.95),
        tip_te=(s * 0.95, -0.09, 1.42),
        thickness=0.030
    )


def build_vtail(side=1):
    """Vertical tail fin — canted slightly outward."""
    s = side
    cant = 0.12  # horizontal offset at fin tip for cant
    # Root at Z=0.7, tip at Z=1.1 (fin height in Y)
    verts = [
        # Root leading edge (bottom), root trailing edge (bottom)
        (s * 0.22,  0.05, 0.65),
        (s * 0.22,  0.05, 1.20),
        # Tip leading edge (top), tip trailing edge (top)
        (s * (0.22 + cant), 0.58, 0.80),
        (s * (0.22 + cant), 0.58, 1.18),
    ]
    # Single quad panel (very thin fin)
    indices = [0, 2, 3, 0, 3, 1]  # front face

    # Back face (inverted winding)
    back_verts = [(v[0] + s * 0.02, v[1], v[2]) for v in verts]
    off = len(verts)
    verts += back_verts
    indices += [4+0, 4+3, 4+2, 4+0, 4+1, 4+3]

    # Cap edges
    # Top edge
    verts += [verts[2], verts[3], back_verts[2], back_verts[3]]
    off2 = len(verts) - 4
    indices += [off2, off2+2, off2+3, off2, off2+3, off2+1]

    return verts, indices


def build_nacelle(side=1):
    """Engine nacelle — cylindrical pod."""
    s = side
    x_center = s * 0.44
    y_center = -0.10

    segs = 8
    circle = make_oval(0.175, 0.155, segs)
    z_stations = [0.10, 0.45, 0.85, 1.20, 1.48]
    radii = [1.0, 1.0, 0.95, 0.88, 0.80]

    verts = []
    indices = []

    for si in range(len(z_stations) - 1):
        z0 = z_stations[si]
        z1 = z_stations[si + 1]
        r0 = radii[si]
        r1 = radii[si + 1]

        n = segs
        base = len(verts)
        for (x, y) in circle:
            verts.append((x_center + x * r0, y_center + y * r0, z0))
        for (x, y) in circle:
            verts.append((x_center + x * r1, y_center + y * r1, z1))

        for i in range(n):
            a = base + i
            b = base + (i + 1) % n
            c = base + n + (i + 1) % n
            d = base + n + i
            indices += [a, b, c, a, c, d]

    # Front cap (intake opening)
    cap_pts = [(x_center + x, y_center + y) for (x, y) in circle]
    cap_verts = [(p[0], p[1], 0.10) for p in cap_pts]
    cx = sum(p[0] for p in cap_pts) / len(cap_pts)
    cy = sum(p[1] for p in cap_pts) / len(cap_pts)
    center_v = (cx, cy, 0.10)
    off = len(verts)
    verts.append(center_v)
    verts += cap_verts
    for i in range(segs):
        a = off
        b = off + 1 + i
        c = off + 1 + (i + 1) % segs
        indices += [a, c, b]  # facing forward (flip)

    # Rear cap (nozzle)
    cap_verts2 = [(x_center + x * 0.80, y_center + y * 0.80, 1.48) for (x, y) in circle]
    cx2 = x_center
    cy2 = y_center
    center_v2 = (cx2, cy2, 1.52)  # slightly inset
    off2 = len(verts)
    verts.append(center_v2)
    verts += cap_verts2
    for i in range(segs):
        a = off2
        b = off2 + 1 + i
        c = off2 + 1 + (i + 1) % segs
        indices += [a, b, c]

    return verts, indices


def build_nozzle(side=1):
    """Afterburner nozzle ring."""
    s = side
    x_center = s * 0.44
    y_center = -0.10
    segs = 8
    circle_outer = make_oval(0.155, 0.138, segs)
    circle_inner = make_oval(0.105, 0.092, segs)

    z = 1.52
    verts = []
    indices = []

    off = 0
    for (x, y) in circle_outer:
        verts.append((x_center + x, y_center + y, z))
    for (x, y) in circle_inner:
        verts.append((x_center + x, y_center + y, z + 0.04))
    off = segs * 2

    for i in range(segs):
        a = i
        b = (i + 1) % segs
        c = segs + (i + 1) % segs
        d = segs + i
        indices += [a, b, c, a, c, d]

    return verts, indices


def build_canopy():
    """Cockpit canopy — elongated bubble shape."""
    segs = 8
    # Three cross-sections
    z_stations = [-1.40, -1.10, -0.85, -0.60]
    cross_sections = [
        (0.10, 0.08),  # front
        (0.14, 0.13),  # main
        (0.13, 0.11),
        (0.08, 0.06),  # rear
    ]
    y_offsets = [0.28, 0.34, 0.32, 0.25]

    verts = []
    indices = []

    for si in range(len(z_stations) - 1):
        z0 = z_stations[si]
        z1 = z_stations[si + 1]
        rx0, ry0 = cross_sections[si]
        rx1, ry1 = cross_sections[si + 1]
        yo0 = y_offsets[si]
        yo1 = y_offsets[si + 1]

        ring0 = make_oval(rx0, ry0, segs)
        ring1 = make_oval(rx1, ry1, segs)

        n = segs
        base = len(verts)
        for (x, y) in ring0:
            verts.append((x, y + yo0, z0))
        for (x, y) in ring1:
            verts.append((x, y + yo1, z1))

        for i in range(n):
            a = base + i
            b = base + (i + 1) % n
            c = base + n + (i + 1) % n
            d = base + n + i
            indices += [a, b, c, a, c, d]

    return verts, indices


def build_intake_ramp(side=1):
    """Intake ramp — the distinctive orange/red rectangles on F-14's sides."""
    s = side
    verts = [
        (s * 0.22, -0.10, -1.50),
        (s * 0.28, -0.10, -1.50),
        (s * 0.22, 0.08, -1.50),
        (s * 0.28, 0.08, -1.50),
        (s * 0.22, -0.10, -0.90),
        (s * 0.28, -0.10, -0.90),
        (s * 0.22, 0.08, -0.90),
        (s * 0.28, 0.08, -0.90),
    ]
    # Outer face visible from camera side
    indices = [
        0, 2, 3, 0, 3, 1,  # front face
        4, 5, 7, 4, 7, 6,  # rear face
        0, 1, 5, 0, 5, 4,  # bottom
        2, 6, 7, 2, 7, 3,  # top
        0, 4, 6, 0, 6, 2,  # inner
        1, 3, 7, 1, 7, 5,  # outer
    ]
    return verts, indices


def build_flame(side=1):
    """Afterburner flame cone — bright orange cone trailing behind nozzle."""
    s = side
    x_center = s * 0.44
    y_center = -0.10
    segs = 8
    circle = make_oval(0.115, 0.102, segs)

    z_base = 1.52
    z_tip = 2.60

    verts = []
    indices = []

    base = len(verts)
    for (x, y) in circle:
        verts.append((x_center + x, y_center + y, z_base))
    # Tip — slightly offset toward camera center for convergence look
    tip = (x_center * 0.5, y_center, z_tip)
    verts.append(tip)
    tip_idx = base + segs

    for i in range(segs):
        a = base + i
        b = base + (i + 1) % segs
        c = tip_idx
        indices += [a, b, c]

    # Base cap
    cx = x_center
    cy = y_center
    verts.append((cx, cy, z_base))
    center_idx = len(verts) - 1
    for i in range(segs):
        a = center_idx
        b = base + i
        c = base + (i + 1) % segs
        indices += [a, c, b]

    return verts, indices


def build_central_flame():
    """Large central merged flame plume."""
    segs = 10
    circle = make_oval(0.38, 0.28, segs)

    z_base = 1.52
    z_tip = 3.20
    y_offset = -0.15

    verts = []
    indices = []

    base = 0
    for (x, y) in circle:
        verts.append((x, y + y_offset, z_base))
    tip = (0.0, y_offset, z_tip)
    verts.append(tip)
    tip_idx = segs

    for i in range(segs):
        a = base + i
        b = base + (i + 1) % segs
        c = tip_idx
        indices += [a, b, c]

    # Base cap
    verts.append((0.0, y_offset, z_base))
    center_idx = len(verts) - 1
    for i in range(segs):
        a = center_idx
        b = base + i
        c = base + (i + 1) % segs
        indices += [a, c, b]

    return verts, indices


# ---------------------------------------------------------------------------
# Assemble everything
# ---------------------------------------------------------------------------

def build_f14():
    """Return list of mesh dicts for GLB generation."""
    meshes = []

    # Fuselage
    fv, fi = build_fuselage()
    meshes.append({
        'name': 'Fuselage',
        'vertices': fv,
        'indices': fi,
        'color': (0.85, 0.86, 0.92),
        'metallic': 0.25,
        'roughness': 0.55
    })

    # Spine
    sv, si = build_spine()
    meshes.append({
        'name': 'Spine',
        'vertices': sv,
        'indices': si,
        'color': (0.88, 0.89, 0.94),
        'metallic': 0.15,
        'roughness': 0.60
    })

    # Canopy
    cv, ci = build_canopy()
    meshes.append({
        'name': 'Canopy',
        'vertices': cv,
        'indices': ci,
        'color': (0.22, 0.30, 0.75),
        'metallic': 0.05,
        'roughness': 0.05
    })

    # Wings
    for side in [1, -1]:
        wv, wi = build_wing(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}Wing',
            'vertices': wv,
            'indices': wi,
            'color': (0.82, 0.83, 0.90),
            'metallic': 0.15,
            'roughness': 0.65
        })

    # Horizontal stabilizers
    for side in [1, -1]:
        hv, hi = build_hstab(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}HStab',
            'vertices': hv,
            'indices': hi,
            'color': (0.82, 0.83, 0.90),
            'metallic': 0.15,
            'roughness': 0.65
        })

    # Vertical tails
    for side in [1, -1]:
        vtv, vti = build_vtail(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}VTail',
            'vertices': vtv,
            'indices': vti,
            'color': (0.80, 0.82, 0.88),
            'metallic': 0.18,
            'roughness': 0.55
        })

    # Nacelles
    for side in [1, -1]:
        nv, ni = build_nacelle(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}Nacelle',
            'vertices': nv,
            'indices': ni,
            'color': (0.55, 0.54, 0.52),
            'metallic': 0.30,
            'roughness': 0.50
        })

    # Nozzles
    for side in [1, -1]:
        nzv, nzi = build_nozzle(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}Nozzle',
            'vertices': nzv,
            'indices': nzi,
            'color': (0.12, 0.11, 0.10),
            'metallic': 0.45,
            'roughness': 0.25
        })

    # Intake ramps
    for side in [1, -1]:
        iv, ii = build_intake_ramp(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}IntakeRamp',
            'vertices': iv,
            'indices': ii,
            'color': (0.82, 0.32, 0.10),  # orange/red
            'metallic': 0.10,
            'roughness': 0.70
        })

    # Afterburner flames
    for side in [1, -1]:
        fv2, fi2 = build_flame(side)
        label = 'Right' if side == 1 else 'Left'
        meshes.append({
            'name': f'{label}Flame',
            'vertices': fv2,
            'indices': fi2,
            'color': (1.0, 0.6, 0.05),  # orange
            'metallic': 0.0,
            'roughness': 1.0
        })

    # Central flame plume
    cfv, cfi = build_central_flame()
    meshes.append({
        'name': 'CentralFlame',
        'vertices': cfv,
        'indices': cfi,
        'color': (1.0, 0.85, 0.10),  # bright yellow-orange
        'metallic': 0.0,
        'roughness': 1.0
    })

    return meshes


if __name__ == '__main__':
    import sys
    print("Building F-14 Tomcat GLB model...")
    meshes = build_f14()
    total_verts = sum(len(m['vertices']) for m in meshes)
    total_tris = sum(len(m['indices']) // 3 for m in meshes)
    print(f"  {len(meshes)} mesh parts, {total_verts} vertices, {total_tris} triangles")

    glb_data = build_glb(meshes)

    output_path = '/Users/urizonens/dev/afterburner/assets/models/f14_player.glb'
    with open(output_path, 'wb') as f:
        f.write(glb_data)

    print(f"  Written {len(glb_data):,} bytes to {output_path}")
    print("Done.")
