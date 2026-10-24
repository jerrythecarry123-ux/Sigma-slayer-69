#!/usr/bin/env python3
"""Check fitted scenery joins in a production geometry capture, not Studio physics.

python tools/check_details.py /tmp/world.json [--proof /tmp/detail-proof.json]
"""
import argparse
from collections import defaultdict
import itertools
import json
import math
from pathlib import Path

from check_world import interval

EPS = 1e-7


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def direction(part, vector):
    return [dot(row, vector) for row in part['rotation']]


def point(part, local):
    return [a + b for a, b in zip(part['position'], direction(part, local))]


def object_point(part, world):
    delta = [a - b for a, b in zip(world, part['position'])]
    return [dot([row[i] for row in part['rotation']], delta) for i in range(3)]


def inside_block(part, world):
    assert part['shape'] == 'Block'
    return all(abs(value) <= width/2 + EPS for value, width in zip(object_point(part, world), part['size']))


def polyhedron(part):
    """Actual block/wedge vertices and complete face-normal and edge directions."""
    assert part['shape'] in ('Block', 'Wedge')
    size = part['size']
    local = [[sign[i]*size[i]/2 for i in range(3)] for sign in itertools.product((-1, 1), repeat=3)]
    normals = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    edges = list(normals)
    if part['shape'] == 'Wedge':
        local = [v for v in local if v[1]/size[1] <= v[2]/size[2] + EPS]
        normals += [[0, 1/size[1], -1/size[2]]]
        edges += [[0, size[1], size[2]]]
    return [point(part, v) for v in local], [direction(part, v) for v in normals], [direction(part, v) for v in edges]


def intersect_polyhedra(first, second):
    """Separating-axis test, including wedge slopes and edge-cross-edge axes."""
    av, an, ae = polyhedron(first)
    bv, bn, be = polyhedron(second)
    axes = an + bn + [cross(a, b) for a in ae for b in be]
    minimum = math.inf
    for axis in axes:
        length = math.sqrt(dot(axis, axis))
        if length < EPS:
            continue
        a = [dot(v, axis)/length for v in av]
        b = [dot(v, axis)/length for v in bv]
        overlap = min(max(a), max(b))-max(min(a), min(b))
        if overlap <= EPS:
            return None
        minimum = min(minimum, overlap)
    return minimum


def validate(scene):
    parts = scene['parts']
    by_name = defaultdict(list)
    for part in parts:
        by_name[part['name']].append(part)

    def siblings(part, name):
        parent = part['path'].rsplit('/', 1)[0]
        return [p for p in by_name[name] if p['path'].rsplit('/', 1)[0] == parent]

    proof = {key: [] for key in ('dockLamps', 'cottageStems', 'hatchBrackets', 'plaqueStands', 'canopyPosts', 'canvasHems')}
    for rim in by_name['LanternRim']:
        parent = rim['path'].rsplit('/', 2)[0]
        caps = [p for p in by_name['PostCap'] if p['path'].rsplit('/', 1)[0] == parent]
        if not caps:
            continue
        lamp_rims = [p for p in by_name['LanternRim'] if p['path'] == rim['path']]
        if rim['position'][1] != min(p['position'][1] for p in lamp_rims):
            continue
        overlaps = [intersect_polyhedra(rim, cap) for cap in caps]
        contacts = [v for v in overlaps if v is not None]
        assert len(contacts) == 1, parent + ': lantern rim must sit on one post cap'
        proof['dockLamps'].append({'parent': parent, 'overlap': contacts[0]})

    for stem in by_name['HangingStem']:
        house = stem['path'].split('/HarborLantern')[0]
        canopies = [p for p in by_name['PorchCanopy'] if p['path'].rsplit('/', 1)[0] == house]
        if not canopies:
            continue
        assert len(canopies) == 1
        x, _, z = stem['position']
        a, b = interval(stem, x, z), interval(canopies[0], x, z)
        assert a and b and min(a[1], b[1])-max(a[0], b[0]) > EPS, house + ': stem ends below canvas'
        proof['cottageStems'].append({'parent': house, 'overlap': min(a[1], b[1])-max(a[0], b[0])})

    for bracket in by_name['HatchCanopyBracket']:
        canopy, = siblings(bracket, 'CafeHatchCanvas')
        assert bracket['shape'] == 'Cylinder' and abs(bracket['size'][1]-bracket['size'][2]) < EPS
        ends = [point(bracket, [sign*bracket['size'][0]/2, 0, 0]) for sign in (-1, 1)]
        lower, upper = sorted(ends, key=lambda v: v[1])
        assert any(inside_block(wall, lower) for wall in siblings(bracket, 'RearWall')), bracket['path'] + ': lower bracket floats off wall'
        axis = [row[0] for row in bracket['rotation']]
        normal = [row[1] for row in canopy['rotation']]
        radial = [normal[i]-dot(axis, normal)*axis[i] for i in range(3)]
        length = math.sqrt(dot(radial, radial))
        assert length > EPS
        local = object_point(canopy, upper)
        # A point inside the true circular end cap must also lie within the
        # canvas. This checks cylinder geometry rather than its bounding box.
        toward_panel = -1 if local[1] > 0 else 1
        sample = [upper[i] + toward_panel*radial[i]/length*bracket['size'][1]/2*.9 for i in range(3)]
        assert inside_block(canopy, sample), bracket['path'] + ': bracket ends below canvas'
        overlap = canopy['size'][1]/2 + length*bracket['size'][1]/2-abs(local[1])
        proof['hatchBrackets'].append({'parent': bracket['path'].rsplit('/', 1)[0], 'overlap': overlap})

    for stand in by_name['ObservatoryPlaqueStand']:
        plaque, = siblings(stand, 'ObservatoryPlaque')
        floor, = siblings(stand, 'WeatheredObservatoryFloor')
        overlap = intersect_polyhedra(stand, plaque)
        assert overlap, stand['path'] + ': plaque is detached from stand'
        bottom = min(v[1] for v in polyhedron(stand)[0])
        # All four actual upright corners must enter the circular floor. The
        # smaller circular native cylinder, not a stretched ellipse, is used.
        contacts = []
        for sx, sz in itertools.product((-1, 1), repeat=2):
            corner = point(stand, [sx*stand['size'][0]/2, -stand['size'][1]/2, sz*stand['size'][2]/2])
            hit = interval(floor, corner[0], corner[2])
            assert hit and hit[0] < bottom < hit[1], stand['path'] + ': stand foot leaves circular floor'
            contacts.append(hit[1]-bottom)
        proof['plaqueStands'].append({'parent': stand['path'].rsplit('/', 1)[0], 'boardOverlap': overlap, 'floorOverlap': min(contacts)})

    for name, canvas in (('PorchPost', 'PorchCanopy'), ('StallAwningPost', 'StripedCanvasAwning')):
        for post in by_name[name]:
            contacts = [intersect_polyhedra(post, panel) for panel in siblings(post, canvas)]
            contacts = [v for v in contacts if v is not None]
            assert contacts, post['path'] + ': support post does not reach canvas'
            proof['canopyPosts'].append({'parent': post['path'].rsplit('/', 1)[0], 'overlap': max(contacts)})

    for hem in by_name['DrapedCanvasHem']:
        panels = siblings(hem, 'PorchCanopy') + siblings(hem, 'StripedCanvasAwning')
        contacts = [intersect_polyhedra(hem, panel) for panel in panels]
        contacts = [v for v in contacts if v is not None]
        assert contacts, hem['path'] + ': triangular cloth hem is detached from canopy'
        proof['canvasHems'].append({'parent': hem['path'].rsplit('/', 1)[0], 'overlap': max(contacts)})

    expected = {'dockLamps': 12, 'cottageStems': 4, 'hatchBrackets': 2, 'plaqueStands': 2, 'canopyPosts': 12, 'canvasHems': 64}
    for name, count in expected.items():
        assert len(proof[name]) == count, f'{name}: exercised {len(proof[name])}/{count} production joins'
    return proof


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--proof', type=Path)
    args = parser.parse_args()
    proof = validate(json.loads(args.capture.read_text()))
    if args.proof:
        args.proof.write_text(json.dumps(proof, indent=2) + '\n')
    print(f"Detail joins OK: {len(proof['dockLamps'])} dock lamps, {len(proof['cottageStems'])} hanging stems, {len(proof['hatchBrackets'])} café brackets, {len(proof['plaqueStands'])} plaque stands, {len(proof['canopyPosts'])} canopy posts, {len(proof['canvasHems'])} fitted cloth hems. Analytic geometry only.")
