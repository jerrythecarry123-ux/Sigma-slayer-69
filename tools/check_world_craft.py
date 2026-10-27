#!/usr/bin/env python3
"""Check visible trunk collision and tapered fern roots in captured production geometry.

This checks native primitive geometry, not Roblox physics, shaders or device FPS.
Optional --baseline compares the previous hidden tree cores with the new visible
trunks, including their complete size, transform and collision/query properties.
"""
import argparse
from collections import defaultdict
import copy
import json
import math
from pathlib import Path

from check_details import inside_block, point
from check_world import interval

EPS = 1e-7
TRUNKS = {
    'LowerTrunk': 'SculptedLowerTrunk',
    'UpperTrunk': 'TaperedUpperTrunk',
    'PineTrunk': 'TaperedPineTrunk',
    'CurvedPalmTrunk': 'SculptedPalmTrunk',
}


def parent(part):
    return part['path'].rsplit('/', 1)[0]


def validate(scene, baseline=None):
    parts = scene['parts']
    by_parent = defaultdict(list)
    for part in parts:
        by_parent[parent(part)].append(part)
    assert not any(p['name'] in TRUNKS for p in parts), 'Duplicate hidden trunk cores returned'
    trunks = [p for p in parts if p['name'] in TRUNKS.values()]
    assert len(trunks) == 79, 'Not all 79 authored trunk sections were exercised'
    physical_trunks = 0
    for trunk in trunks:
        decorative = any(name in trunk['path'].split('/') for name in ('YoungOakCluster', 'YoungBlossomCluster'))
        assert trunk['alpha'] == 1 and trunk['anchored'], trunk['path'] + ': trunk is invisible or unanchored'
        assert trunk['collide'] == (not decorative) and trunk['query'] == (not decorative), trunk['path'] + ': visible trunk collision does not match its authored role'
        assert trunk['shape'] == 'Cylinder' and trunk['material'] == 'Wood', trunk['path'] + ': native circular timber geometry lost'
        assert abs(trunk['size'][1] - trunk['size'][2]) < EPS
        physical_trunks += not decorative
    assert physical_trunks == 67
    compared = 0
    if baseline is not None:
        cores = [p for p in baseline['parts'] if p['name'] in TRUNKS]
        assert len(cores) == len(trunks)
        for core in cores:
            candidates = [p for p in by_parent[parent(core)]
                          if p['name'] == TRUNKS[core['name']] and math.dist(p['position'], core['position']) < EPS]
            assert len(candidates) == 1, core['path'] + ': old core has no unique visible replacement'
            visible = candidates[0]
            for key in ('size', 'position', 'rotation', 'shape', 'collide', 'query', 'anchored'):
                assert visible[key] == core[key], core['path'] + ': collision property changed: ' + key
            compared += 1

    leaves = [p for p in parts if p['name'] == 'TaperedFernFrond']
    assert len(leaves) == 64, 'Not all 32 paired fern leaves were exercised'
    remaining = list(leaves)
    joined = 0
    ground_witnesses = 0
    minimum_embed = math.inf
    while remaining:
        first = remaining.pop()
        assert first['shape'] == 'Wedge' and not first['collide'] and not first['query']
        sx, sy, sz = first['size']
        assert sx < sy * .2 and sy < sz * .2, first['path'] + ': fern reverted to a thick rectangular ramp'
        root = point(first, [0, -sy/2, sz/2])
        tip = point(first, [0, -sy/2, -sz/2])
        matches = []
        for second in remaining:
            if parent(second) != parent(first):
                continue
            tx, ty, tz = second['size']
            if math.dist(root, point(second, [0, -ty/2, tz/2])) < EPS and math.dist(tip, point(second, [0, -ty/2, -tz/2])) < EPS:
                matches.append(second)
        assert len(matches) == 1, first['path'] + ': triangular halves do not share the complete root-to-tip edge'
        second = matches[0]
        remaining.remove(second)
        assert second['shape'] == 'Wedge' and second['size'] == first['size'] and not second['collide'] and not second['query']
        outer_a = point(first, [0, sy/2, sz/2])
        outer_b = point(second, [0, sy/2, sz/2])
        assert math.dist([(a+b)/2 for a, b in zip(outer_a, outer_b)], root) < EPS, first['path'] + ': halves fold onto the same side'
        assert math.dist(outer_a, outer_b) > sy * 1.99, first['path'] + ': broad root lost its taper'
        assert tip[1] > root[1] + sy, first['path'] + ': fern tip is buried or inverted'
        # Both native wedge halves have a complete rectangular root end. Its
        # lower corners must enter the actual visible terrain while its upper
        # corners emerge, rather than moving the whole leaf above the meadow.
        for leaf in (first, second):
            for sign in (-1, 1):
                bottom = point(leaf, [sx/2, sign*sy/2, sz/2])
                # The +/- local X points lie on opposite sides of the thin leaf;
                # pair them to find the actual vertical end thickness.
                opposite = point(leaf, [-sx/2, sign*sy/2, sz/2])
                low, high = sorted((bottom[1], opposite[1]))
                horizontal = [(bottom[i] + opposite[i])/2 for i in range(3)]
                floors = []
                for floor in parts:
                    if not floor['collide'] or floor['alpha'] <= 0:
                        continue
                    hit = interval(floor, horizontal[0], horizontal[2])
                    if hit and low < hit[1] < high:
                        floors.append(hit[1])
                assert floors, first['path'] + ': broad fern root floats off visible terrain'
                minimum_embed = min(minimum_embed, max(floors)-low)
                ground_witnesses += 1
        joined += 1
    pottery_feet = 0
    pots = [p for p in parts if p['name'] == 'GlazedStoragePot']
    assert len(pots) == 12
    for pot in pots:
        shelves = [p for p in by_parent[parent(pot)] if p['name'] == 'RearDisplayShelf']
        assert len(shelves) == 1 and pot['shape'] == 'Cylinder'
        shelf = shelves[0]
        # Sample the native circular base, rather than accepting the pot's
        # centre above a shelf whose edges might not support its full foot.
        for index in range(8):
            angle = index * math.pi / 4
            foot = point(pot, [-pot['size'][0]/2,
                               math.cos(angle)*pot['size'][1]/2,
                               math.sin(angle)*pot['size'][2]/2])
            assert inside_block(shelf, foot), pot['path'] + ': storage pot floats or overhangs shelf'
            pottery_feet += 1
    return {'visibleTrunks': len(trunks), 'physicalTrunks': physical_trunks, 'exactBaselineMatches': compared,
            'pairedLeaves': joined, 'rootGroundWitnesses': ground_witnesses,
            'minimumRootEmbed': minimum_embed, 'seatedPottery': len(pots), 'potteryFootSamples': pottery_feet}


def mutations(scene):
    bad = copy.deepcopy(scene)
    next(p for p in bad['parts'] if p['name'] in TRUNKS.values())['collide'] = False
    checks = [('disabled visible trunk collision', bad)]
    bad = copy.deepcopy(scene)
    # Lift a whole native pair, not just one half: a shared-edge test alone
    # should not accept a plant floating in mid-air.
    first = next(p for p in bad['parts'] if p['name'] == 'TaperedFernFrond')
    _, sy, sz = first['size']
    root, tip = point(first, [0, -sy/2, sz/2]), point(first, [0, -sy/2, -sz/2])
    for leaf in bad['parts']:
        if leaf['name'] != first['name'] or parent(leaf) != parent(first):
            continue
        _, ty, tz = leaf['size']
        if math.dist(root, point(leaf, [0, -ty/2, tz/2])) < EPS and math.dist(tip, point(leaf, [0, -ty/2, -tz/2])) < EPS:
            leaf['position'][1] += .3
    checks.append(('floating complete fern pair', bad))
    bad = copy.deepcopy(scene)
    leaf = next(p for p in bad['parts'] if p['name'] == 'TaperedFernFrond')
    leaf['rotation'] = [[-v if col in (0, 1) else v for col, v in enumerate(row)] for row in leaf['rotation']]
    checks.append(('mirrored fern root', bad))
    bad = copy.deepcopy(scene)
    next(p for p in bad['parts'] if p['name'] == 'GlazedStoragePot')['position'][1] += .02
    checks.append(('former floating shelf pot', bad))
    for name, scene in checks:
        try:
            validate(scene)
        except AssertionError:
            continue
        raise AssertionError('Regression mutation was accepted: ' + name)
    return len(checks)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--proof', type=Path)
    parser.add_argument('--mutations', action='store_true')
    args = parser.parse_args()
    scene = json.loads(args.capture.read_text())
    proof = validate(scene, json.loads(args.baseline.read_text()) if args.baseline else None)
    if args.mutations:
        proof['rejectedRegressions'] = mutations(scene)
    if args.proof:
        args.proof.write_text(json.dumps(proof, indent=2) + '\n')
    print('PASS visible trunk collision and tapered fern craft:', proof)
    print('Analytic native primitive geometry only; actual Roblox appearance, physics and FPS require a client.')
