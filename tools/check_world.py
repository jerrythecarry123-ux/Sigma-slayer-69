#!/usr/bin/env python3
"""Check captured production colliders with vertical analytic rays, not Studio physics.

python tools/check_world.py /tmp/world.json
Includes invisible floors/rails and exact oriented wedges, cylinders and balls.
"""
import json
import math
from pathlib import Path
import re
import sys

EPS = 1e-7


def interval(part, x, z):
    # Transform the world vertical line (x,t,z) to the part's local coordinates.
    r, p = part['rotation'], part['position']
    q = [sum(r[j][i] * ([x, 0, z][j] - p[j]) for j in range(3)) for i in range(3)]
    d = [r[1][i] for i in range(3)]
    size = part['size']
    lo, hi = -math.inf, math.inf

    def clip(a, b):
        nonlocal lo, hi
        # a*t <= b
        if abs(a) < EPS:
            return b >= -EPS
        if a > 0:
            hi = min(hi, b / a)
        else:
            lo = max(lo, b / a)
        return lo <= hi + EPS

    def slab(i):
        return clip(d[i], size[i]/2-q[i]) and clip(-d[i], size[i]/2+q[i])

    shape = part['shape']
    if shape in ('Block', 'Wedge'):
        for i in range(3):
            if not slab(i):
                return None
        if shape == 'Wedge' and not clip(d[1]/size[1]-d[2]/size[2], -q[1]/size[1]+q[2]/size[2]):
            return None
    else:
        axes = [0, 1, 2] if shape == 'Ball' else [1, 2]
        if shape == 'Cylinder' and not slab(0):
            return None
        a = sum((d[i]/(size[i]/2))**2 for i in axes)
        b = 2*sum(q[i]*d[i]/(size[i]/2)**2 for i in axes)
        c = sum((q[i]/(size[i]/2))**2 for i in axes)-1
        if abs(a) < EPS:
            if c > EPS:
                return None
        else:
            disc = b*b-4*a*c
            if disc < -EPS:
                return None
            delta = math.sqrt(max(0, disc))
            lo, hi = max(lo, (-b-delta)/(2*a)), min(hi, (-b+delta)/(2*a))
    return (lo, hi) if lo <= hi + EPS else None


def walking_surface(colliders, x, y, z, label, tolerance=1):
    """Find actual collider support and six studs of clear avatar space above it."""
    hits = []
    for part, x0, x1, z0, z1 in colliders:
        if x0-EPS <= x <= x1+EPS and z0-EPS <= z <= z1+EPS:
            hit = interval(part, x, z)
            if hit:
                hits.append((hit, part['path']))
    floors = [hi for (lo, hi), _ in hits if y-tolerance <= hi <= y+tolerance]
    if not floors:
        return f'No supported {label} at ({x:.2f},{y:.2f},{z:.2f})'
    floor = max(floors)
    obstacles = [name for (lo, hi), name in hits if lo < floor+6 and hi > floor+.45]
    if obstacles:
        return f'Blocked {label} at ({x:.2f},{y:.2f},{z:.2f}): {obstacles[0]}'
    return None


def validate(scene):
    parts = scene['parts']
    assert len(parts) < 10000, 'World exceeds its source-part budget'
    assert scene['terrainWrites'] == 5, 'Five native-water lagoons must be written'
    for p in parts:
        assert p['anchored'], p['path'] + ' is not anchored'
        assert all(math.isfinite(n) and n > 0 for n in p['size']), p['path'] + ' invalid size'
        assert all(math.isfinite(n) for n in p['position']), p['path'] + ' invalid position'
        assert p['shape'] in ('Block', 'Wedge', 'Cylinder', 'Ball')
    # Broad phase in world X/Z, including transparent colliders.
    colliders = []
    for p in parts:
        if not p['collide']:
            continue
        radii = [sum(abs(p['rotation'][i][j])*p['size'][j]/2 for j in range(3)) for i in range(3)]
        colliders.append((p, p['position'][0]-radii[0], p['position'][0]+radii[0], p['position'][2]-radii[2], p['position'][2]+radii[2]))
    layout = scene['layout']
    routes = [dict(Points=route['Points'], Width=route['Width']) for route in layout['Paths']]
    routes += [dict(Points=r['Points'],Width=r['Width']) for r in layout['Bridges']]
    routes += [dict(Points=[r['A'],r['B']],Width=r['Width']) for r in layout['Docks']]
    sampled = 0
    failures = []
    for route in routes:
        for a, b in zip(route['Points'], route['Points'][1:]):
            length = math.dist(a,b)
            side = [-(b[2]-a[2])/length, (b[0]-a[0])/length]
            for step in range(math.ceil(length/1.5)+1):
                t = min(1,step*1.5/length)
                for offset in (-1.3,0,1.3):
                    x,y,z = [a[i]+(b[i]-a[i])*t for i in range(3)]
                    x,z = x+side[0]*offset,z+side[1]*offset
                    failure = walking_surface(colliders, x, y, z, 'route')
                    if failure:
                        failures.append(failure)
                    sampled+=1
    assert not failures, '\n'.join(failures[:15]) + f'\n{len(failures)} failed samples of {sampled}'

    spawn = layout['Spawn']
    spawn_parts = [p for p in parts if p['name'] == 'HarborSpawn']
    assert len(spawn_parts) == 1, 'Exactly one harbor spawn must be captured'
    spawn_part = spawn_parts[0]
    assert math.dist([spawn_part['position'][0], spawn_part['position'][2]], [spawn[0], spawn[2]]) < .01, 'Spawn collider disagrees with the configured spawn'
    assert spawn_part['size'][0] >= 14 and spawn_part['size'][2] >= 14, 'Harbor spawn must retain its full 14-by-14 footprint'
    # Exclude the spawn plate itself: it must overlay a continuous walkable deck,
    # rather than conceal a gap that a player falls through when stepping off.
    spawn_colliders = [entry for entry in colliders if entry[0] is not spawn_part]
    spawn_samples = 0
    for dx in range(-7, 8):
        for dz in range(-7, 8):
            failure = walking_surface(spawn_colliders, spawn[0]+dx, spawn[1], spawn[2]+dz, 'spawn footprint', .25)
            assert failure is None, failure
            spawn_samples += 1

    docks = {dock['Id']: dock for dock in layout['Docks']}
    travel = scene['travel']
    assert len(travel) == 5 and {entry['id'] for entry in travel} == set(docks), 'Every island needs exactly one captured travel destination'
    assert scene['persistentTravelSupport'], 'Arrival support model must remain persistent while scenery streams'
    supports = [p for p in parts if '/TravelArrivalSupports/' in p['path']]
    assert len(supports) == 5, 'Exactly five persistent arrival floors must exist'
    support_by_id = {}
    for destination in docks:
        matching = [p for p in supports if p['name'] == destination+'ArrivalFloor']
        assert len(matching) == 1, destination+' needs its own persistent arrival floor'
        floor = matching[0]
        assert floor['anchored'] and floor['collide'] and floor.get('query') is True, floor['path']+' must be anchored, collidable and queryable'
        assert floor['alpha'] == 0 and not floor['shadow'], floor['path']+' must remain invisible without casting a shadow'
        assert floor['shape'] == 'Block' and 0 < floor['size'][1] <= .3, floor['path']+' must remain a thin collision plate'
        support_by_id[destination] = floor
    config_source = (Path(__file__).resolve().parents[1]/'src/shared/FishingConfig.luau').read_text()
    config_match = re.search(r'\bMaxDistance\s*=\s*([0-9]+(?:\.[0-9]+)?)', config_source)
    assert config_match, 'Capture checker could not read the production fishing distance'
    fishing_range = float(config_match.group(1))
    arrival_samples = 0
    portal_samples = 0
    arrived_positions = []
    for entry in travel:
        destination, arrival, kiosk = entry['id'], entry['arrival'], entry['kiosk']
        assert all(math.isfinite(value) for point in (arrival, kiosk) for value in point), destination+' has a nonfinite travel position'
        assert all(math.dist(arrival, other) > 1 for other in arrived_positions), 'Travel destinations must have distinct arrival positions'
        arrived_positions.append(arrival)
        spot = docks[destination]['Spot']
        ground = spot[1]-.1
        assert 3 <= arrival[1]-ground <= 6, destination+' arrival root has insufficient or excessive ground clearance'
        assert math.dist(arrival, spot) <= fishing_range, destination+' arrival must be ready to fish in its own pond'
        # Horizontal separation keeps the native E prompt off the casting marker
        # for different avatar heights; arriving players must also retain E to fish.
        assert math.hypot(kiosk[0]-spot[0], kiosk[2]-spot[2]) > 5+EPS, destination+' travel prompt overlaps the fishing marker'
        assert math.dist(kiosk, arrival) > 5+EPS, destination+' travel prompt intercepts fishing immediately after arrival'
        floor = support_by_id[destination]
        # Follow the authored sideways approach through the actual rail gap.
        # Sampling a full avatar corridor catches an invisible rail left across a bay.
        start, end = entry['approach'], entry['entry']
        length = math.hypot(end[0]-start[0], end[2]-start[2])
        side = [-(end[2]-start[2])/length, (end[0]-start[0])/length]
        for step in range(math.ceil(length/.5)+1):
            t = min(1, step*.5/length)
            for offset in (-1.3, 0, 1.3):
                x = start[0]+(end[0]-start[0])*t+side[0]*offset
                z = start[2]+(end[2]-start[2])*t+side[1]*offset
                failure = walking_surface(colliders, x, ground, z, destination+' portal approach', .25)
                assert failure is None, failure
                portal_samples += 1
        r = entry['entryRotation']
        local_arrival = [sum(r[j][i]*(arrival[j]-end[j]) for j in range(3)) for i in range(3)]
        assert abs(local_arrival[2]) > 2.3, destination+' arrival overlaps its walk-in trigger'
        # The 3.6-by-3.6 footprint includes the +/-0.8-stud multiplayer lanes and
        # a one-stud avatar half-width. Persistent floors must support it alone.
        for dx in (-1.8, -1, 0, 1, 1.8):
            for dz in (-1.8, -1, 0, 1, 1.8):
                x, z = arrival[0]+dx, arrival[2]+dz
                failure = walking_surface(colliders, x, ground, z, destination+' arrival footprint', .25)
                assert failure is None, failure
                support_hit = interval(floor, x, z)
                assert support_hit and abs(support_hit[1]-ground) < .05, destination+' arrival footprint loses persistent support when the pier streams out'
                assert math.dist([x, arrival[1], z], spot) <= fishing_range, destination+' arrival footprint extends outside fishing range'
                arrival_samples += 1

    shade_names={'LeafShoulder','EvergreenBough','PalmLeaf','StratifiedCliff','RoofUnderlay',
                 'FacetedLeafCrown','TaperedPalmFrond','TaperedPalmTip',
                 'TaperedShoreButtress','UpperShoreRockFacet','UnevenMossLedge',
                 'BrickLeafShelf','BrickNeedleShelf','BrickPalmFrond','StoneBrickBase','StoneBrickCrown',
                 'LowerPondCliffBrick','UpperPondCliffBrick'}
    for p in parts:
        if p['name'] in shade_names:
            assert p['shadow'],p['path']+' loses required shade'
    print(f'PASS {len(parts)} bounded, anchored source parts; {len(colliders)} colliders incl. invisible floors/rails')
    print(f'PASS {sampled} route rays with continuous support and six-stud headroom across a 2.6-stud corridor')
    print(f'PASS {spawn_samples} spawn-footprint rays supported by the underlying world with six-stud headroom')
    print(f'PASS {arrival_samples} arrival-footprint rays, five persistent queryable floors, immediate fishing range and separate travel prompts')
    print(f'PASS {portal_samples} portal-approach rays through open side rails; arrivals clear of walk-in triggers')
    print('PASS native-water regions and structural canopy/cliff/roof shadow flags')
    print('Geometry inspection only; Roblox physics, streaming and device frame rate require Studio/client tests.')


if __name__ == '__main__':
    validate(json.loads(Path(sys.argv[1]).read_text()))
