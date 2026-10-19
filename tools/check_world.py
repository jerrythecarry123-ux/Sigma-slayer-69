#!/usr/bin/env python3
"""Check captured production colliders with vertical analytic rays, not Studio physics.

python tools/check_world.py /tmp/world.json
Includes invisible floors/rails and exact oriented wedges, cylinders and balls.
"""
import json
import math
from pathlib import Path
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
                    hits=[]
                    for p,x0,x1,z0,z1 in colliders:
                        if x0-EPS<=x<=x1+EPS and z0-EPS<=z<=z1+EPS:
                            hit=interval(p,x,z)
                            if hit:
                                hits.append((hit,p['path']))
                    floors=[hi for (lo,hi),_ in hits if y-1 <= hi <= y+1]
                    if not floors:
                        failures.append(f'No supported route at ({x:.2f},{y:.2f},{z:.2f})')
                    else:
                        floor=max(floors)
                        obstacles=[name for (lo,hi),name in hits if lo<floor+6 and hi>floor+.45]
                        if obstacles:
                            failures.append(f'Blocked route at ({x:.2f},{y:.2f},{z:.2f}): {obstacles[0]}')
                    sampled+=1
    assert not failures, '\n'.join(failures[:15]) + f'\n{len(failures)} failed samples of {sampled}'
    shade_names={'LeafShoulder','EvergreenBough','PalmLeaf','StratifiedCliff','RoofUnderlay'}
    for p in parts:
        if p['name'] in shade_names:
            assert p['shadow'],p['path']+' loses required shade'
    print(f'PASS {len(parts)} bounded, anchored source parts; {len(colliders)} colliders incl. invisible floors/rails')
    print(f'PASS {sampled} route rays with continuous support and six-stud headroom across a 2.6-stud corridor')
    print('PASS native-water regions and structural canopy/cliff/roof shadow flags')
    print('Geometry inspection only; Roblox physics, streaming and device frame rate require Studio/client tests.')


if __name__ == '__main__':
    validate(json.loads(Path(sys.argv[1]).read_text()))
