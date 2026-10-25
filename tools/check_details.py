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


def inside_cylinder(part, world):
    assert part['shape'] == 'Cylinder'
    x, y, z = object_point(part, world)
    sx, sy, sz = part['size']
    return abs(x) < sx/2-EPS and (y/(sy/2))**2+(z/(sz/2))**2 < 1-EPS


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

    proof = {key: [] for key in ('dockLamps', 'cottageStems', 'hatchBrackets', 'plaqueStands', 'canopyPosts', 'canvasHems',
                                  'windowFlowers', 'flowerHearts', 'planterSoil', 'planterEnds', 'pottedLeaves')}
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

    for head in by_name['WindowRosette']:
        # Find a strict common interior point in the real circular bloom and
        # the leaf's triangular prism. Box overlap would accept a floating head
        # beside the wedge's missing upper corner. Samples follow its actual
        # ramp just inside the surface, independent of the authored bloom offset.
        witness = None
        for leaf in siblings(head, 'PointedWindowLeaf'):
            if math.dist(head['position'], leaf['position']) > max(leaf['size']):
                continue
            assert leaf['shape'] == 'Wedge'
            for along, across in itertools.product((i/40 for i in range(-18, 19)), (-.25, 0, .25)):
                w = point(leaf, [leaf['size'][0]*across, leaf['size'][1]*(along-.02), leaf['size'][2]*along])
                if inside_cylinder(head, w):
                    witness = w
                    break
            if witness is not None:
                break
        assert witness is not None, head['path'] + ': flower floats off its pointed leaf'
        proof['windowFlowers'].append({'parent': head['path'].rsplit('/', 1)[0], 'commonInteriorPoint': witness})
        heart = min(siblings(head, 'FlowerHeart'), key=lambda p: math.dist(p['position'], head['position']))
        x, _, z = heart['position']
        a, b = interval(head, x, z), interval(heart, x, z)
        assert a and b and min(a[1], b[1])-max(a[0], b[0]) > EPS, heart['path'] + ': flower heart is detached'
        proof['flowerHearts'].append({'parent': heart['path'].rsplit('/', 1)[0], 'overlap': min(a[1], b[1])-max(a[0], b[0])})

    for soil in by_name['Soil']:
        box = min(siblings(soil, 'WindowFlowerBox'), key=lambda p: math.dist(p['position'], soil['position']))
        margins = []
        for sx, sz in itertools.product((-1, 1), repeat=2):
            foot = point(soil, [sx*soil['size'][0]/2, -soil['size'][1]/2, sz*soil['size'][2]/2])
            assert inside_block(box, foot), soil['path'] + ': soil overhangs its wooden planter'
            local = object_point(box, foot)
            margins.append(min(box['size'][i]/2-abs(local[i]) for i in (0, 2)))
        assert min(margins) > EPS, soil['path'] + ': planter lost its visible wooden rim'
        proof['planterSoil'].append({'parent': soil['path'].rsplit('/', 1)[0], 'minimumRim': min(margins)})

    for end in by_name['TaperedPlanterEnd']:
        box = min(siblings(end, 'WindowFlowerBox'), key=lambda p: math.dist(p['position'], end['position']))
        face = [object_point(box, point(end, [sx*end['size'][0]/2, sy*end['size'][1]/2, end['size'][2]/2]))
                for sx, sy in itertools.product((-1, 1), repeat=2)]
        side = 1 if sum(v[0] for v in face) > 0 else -1
        assert all(abs(v[0]-side*box['size'][0]/2) < EPS
                   and all(abs(abs(v[i])-box['size'][i]/2) < EPS for i in (1, 2)) for v in face), end['path'] + ': end bevel points away from its box'
        # The other two wedge vertices must taper outward while remaining in
        # the same height/depth envelope; a reversed wedge makes upright fins.
        local = [object_point(box, vertex) for vertex in polyhedron(end)[0]]
        assert all(abs(v[i]) <= box['size'][i]/2+EPS for v in local for i in (1, 2)), end['path'] + ': bevel protrudes above/beside its box'
        assert all(side*v[0] >= box['size'][0]/2-EPS for v in local), end['path'] + ': bevel folds into the planter'
        proof['planterEnds'].append({'parent': end['path'].rsplit('/', 1)[0], 'completeInnerFaceSeated': True})

    for leaf in by_name['PointedPottedLeaf']:
        stem = min(siblings(leaf, 'FlowerStem'), key=lambda p: math.dist(p['position'], leaf['position']))
        x, _, z = stem['position']
        a, b = interval(leaf, x, z), interval(stem, x, z)
        assert a and b and min(a[1], b[1])-max(a[0], b[0]) > EPS, leaf['path'] + ': leaf root floats off its stem'
        proof['pottedLeaves'].append({'parent': leaf['path'].rsplit('/', 1)[0], 'stemAxisOverlap': min(a[1], b[1])-max(a[0], b[0])})

    expected = {'dockLamps': 12, 'cottageStems': 4, 'hatchBrackets': 2, 'plaqueStands': 2, 'canopyPosts': 12, 'canvasHems': 64,
                'windowFlowers': 24, 'flowerHearts': 24, 'planterSoil': 8, 'planterEnds': 16, 'pottedLeaves': 10}
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
    print(f"Planter joins OK: {len(proof['windowFlowers'])} blooms, {len(proof['flowerHearts'])} hearts, {len(proof['planterSoil'])} contained soil beds, {len(proof['planterEnds'])} fitted bevels and {len(proof['pottedLeaves'])} stem-attached leaves. Analytic geometry only.")
