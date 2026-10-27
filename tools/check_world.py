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


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def solid_geometry(part):
    """Exact convex vertices, separating normals and edge directions of native masonry."""
    sx, sy, sz = [value/2 for value in part['size']]
    yz = [(-sy, -sz), (-sy, sz), (sy, sz)] if part['shape'] == 'Wedge' else [
        (-sy, -sz), (-sy, sz), (sy, -sz), (sy, sz)]
    vertices = []
    for x in (-sx, sx):
        for y, z in yz:
            vertices.append([part['position'][i]+dot(part['rotation'][i], (x, y, z)) for i in range(3)])
    normals = [[part['rotation'][i][j] for i in range(3)] for j in range(3)]
    edges = list(normals)
    if part['shape'] == 'Wedge':
        height, depth = part['size'][1:]
        normals.append([part['rotation'][i][1]/height-part['rotation'][i][2]/depth for i in range(3)])
        edges.append([part['rotation'][i][1]*height+part['rotation'][i][2]*depth for i in range(3)])
    bounds = [(min(v[i] for v in vertices), max(v[i] for v in vertices)) for i in range(3)]
    return vertices, normals, edges, bounds


def touching_solids(a, b, tolerance=.02):
    """Convex separating-axis test; shared triangulation edges count as a seated joint."""
    av, an, ae, ab = a
    bv, bn, be, bb = b
    if any(amax < bmin-tolerance or bmax < amin-tolerance
           for (amin, amax), (bmin, bmax) in zip(ab, bb)):
        return False
    for axis in an+bn+[cross(x, y) for x in ae for y in be]:
        length = math.sqrt(dot(axis, axis))
        if length < EPS:
            continue
        pa, pb = [dot(axis, v) for v in av], [dot(axis, v) for v in bv]
        if max(pa) < min(pb)-tolerance*length or max(pb) < min(pa)-tolerance*length:
            return False
    return True


def polygon_side(a, b, p):
    return (b[0]-a[0])*(p[2]-a[2])-(b[2]-a[2])*(p[0]-a[0])


def inside_polygon(polygon, x, z):
    return all(polygon_side(a, polygon[(i+1) % len(polygon)], (x, 0, z)) >= -EPS
               for i, a in enumerate(polygon))


def clip_rectangle(polygon, x0, x1, z0, z1):
    """Independent polygon/air-cell intersection, including concave voxel stair steps."""
    result = [(p[0], p[2]) for p in polygon]
    for axis, limit, upper in ((0, x0, False), (0, x1, True), (1, z0, False), (1, z1, True)):
        clipped = []
        for i, b in enumerate(result):
            a = result[i-1]
            ai, bi = (a[axis] <= limit if upper else a[axis] >= limit), (b[axis] <= limit if upper else b[axis] >= limit)
            if ai != bi:
                t = (limit-a[axis])/(b[axis]-a[axis])
                clipped.append((a[0]+t*(b[0]-a[0]), a[1]+t*(b[1]-a[1])))
            if bi:
                clipped.append(b)
        result = clipped
        if not result:
            break
    return result


def validate(scene):
    parts = scene['parts']
    assert len(parts) < 10825, 'World exceeds its bounded native-geometry and fitted-shore budget'
    assert scene['terrainWrites'] == 5, 'Five native-water lagoons must be written'
    definitions=json.loads((Path(__file__).resolve().parent/'world_materials.json').read_text())['variants']
    styles={entry['name']:entry['base_material'] for entry in definitions}
    styled_parts=0
    for p in parts:
        assert p['anchored'], p['path'] + ' is not anchored'
        assert all(math.isfinite(n) and n > 0 for n in p['size']), p['path'] + ' invalid size'
        assert all(math.isfinite(n) for n in p['position']), p['path'] + ' invalid position'
        axes=[[row[i] for row in p['rotation']] for i in range(3)]
        assert all(abs(dot(axis,axis)-1)<.0001 for axis in axes), p['path']+' has a non-unit CFrame basis'
        assert all(abs(dot(axes[i],axes[j]))<.0001 for i,j in ((0,1),(0,2),(1,2))), p['path']+' has non-orthogonal CFrame axes'
        assert dot(cross(axes[0],axes[1]),axes[2])>.9999, p['path']+' has a mirrored CFrame basis'
        assert p['shape'] in ('Block', 'Wedge', 'Cylinder', 'Ball')
        if p['shape']=='Ball':
            assert p.get('meshType')=='Sphere', p['path']+' relies on a native Ball stretching into an ellipsoid'
            assert not p['collide'], p['path']+' ellipsoid mesh conceals a native block collider'
        if p['shape']=='Cylinder':
            assert abs(p['size'][1]-p['size'][2])<.001, p['path']+' relies on an elliptical native cylinder'
        style=p.get('surfaceStyle','')
        if style:
            assert style in styles and p['material']==styles[style], p['path']+' has an incompatible surface preset'
            assert p.get('surfaceTagged') and p.get('materialVariant')==style, p['path']+' lost its streamed material binding'
            assert p.get('meshType')!='Sphere', p['path']+' applies native material maps to a SpecialMesh'
            styled_parts+=1
        else:
            assert not p.get('surfaceTagged') and not p.get('materialVariant'), p['path']+' has an orphan material binding'
    assert styled_parts>0, 'The generated world lost its material surface bindings'

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

    # Visual fillets must still guide the avatar along the authored route. A
    # sound collider floor alone would not catch a hole in the visible trail.
    trails=[]
    for p in parts:
        if p['name'] != 'WornFootpath':
            continue
        assert not p['collide'] and not p['query'], p['path']+' visual trail became a physical obstacle'
        radii=[sum(abs(p['rotation'][i][j])*p['size'][j]/2 for j in range(3)) for i in range(3)]
        trails.append((p,p['position'][0]-radii[0],p['position'][0]+radii[0],p['position'][2]-radii[2],p['position'][2]+radii[2]))
    trail_samples=0
    for route in layout['Paths']:
        for a,b in zip(route['Points'],route['Points'][1:]):
            length=math.dist(a,b)
            for step in range(math.ceil(length/1.5)+1):
                t=min(1,step*1.5/length)
                for offset in (-1.3,0,1.3):
                    x,y,z=[a[i]+(b[i]-a[i])*t for i in range(3)]
                    x,z=x-(b[2]-a[2])/length*offset,z+(b[0]-a[0])/length*offset
                    covered=False
                    for p,x0,x1,z0,z1 in trails:
                        if x0-EPS<=x<=x1+EPS and z0-EPS<=z<=z1+EPS:
                            hit=interval(p,x,z)
                            if hit and y-.3<=hit[1]<=y+.35:
                                covered=True
                                break
                    assert covered, f'Visible trail gap at ({x:.2f},{y:.2f},{z:.2f})'
                    trail_samples+=1

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
        assert floor['alpha'] == 1 and floor['shadow'], floor['path']+' must remain visible when portal decoration streams out'
        assert floor['material'] == 'WoodPlanks', floor['path']+' lost its visible landing material'
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
    # Check the generated result, so an old Studs override cannot silently turn
    # a newly authored wood/plaster material back into Plastic during construction.
    surfaces = {
        'WeatheredDeckPlank': 'Wood', 'RearWall': 'Plaster',
        'IndividualSlateShingle': 'Slate', 'CanvasSail': 'Fabric',
        'SculptedLowerTrunk': 'Wood', 'SlopingStoneFace': 'Slate',
        'GalleryPromenadeDeck': 'WoodPlanks', 'ContinuousWalkSurface': 'Wood',
        'PortalUpright': 'Limestone', 'WornFootpath': 'Sand', 'TownSquare': 'Limestone',
    }
    for name, material in surfaces.items():
        matched = [p for p in parts if p['name'] == name]
        assert matched, 'Missing representative surface: '+name
        for p in matched:
            assert p['material'] == material, p['path']+' lost its authored surface'
            assert not any(p['studs'].values()), p['path']+' has studs masking its texture'
    assert not any('/PuffletPreview/' in p['path'] for p in parts), 'Prototype fish still floats above the pond'

    assert not spawn_part['collide'] and not spawn_part['query'], 'Temporary joining pad still creates an invisible raised step'
    visible_floors=0
    for p in parts:
        if '/FacetedShoreRock/' in p['path'] and p['collide']:
            assert p['alpha']==1 and p['query'], p['path']+' rock collision extends beyond the visible facets'
        if (p['collide'] and p['shape']=='Block' and p['size'][1]<=.5
                and min(p['size'][0],p['size'][2])>3 and abs(p['rotation'][1][1])>.9):
            assert p['alpha']==1, p['path']+' is an invisible walking plane'
            visible_floors+=1
    # Evaluate the actual production strength-to-depth rule across its entire
    # input range, not an unrelated hand-written list of target distances.
    # Every landing footprint must occupy real native water and be unobstructed.
    cast_samples=0
    waters={water['Id']:water for water in layout['Waters']}
    cast_depths=scene.get('castDepths', [])
    assert len(cast_depths)==101, 'Capture actual casting rules before checking the charged water lanes'
    water_surfaces = {surface['id']: surface for surface in scene['waterSurfaces']}
    for dock in layout['Docks']:
        water=waters[dock['Id']]
        surface=water_surfaces[dock['Id']]
        resolution=surface['resolution']
        occupied={(round(p[0]/resolution-.5),round(p[2]/resolution-.5)) for p in surface['cells']}
        for lane in (-3,-1,1,3):
            for sample in cast_depths:
                depth=sample['depth']
                assert math.isfinite(depth) and 12-EPS<=depth<=15.4+EPS, 'Cast rule escaped the validated water lanes'
                x=dock['Spot'][0]+math.cos(dock['Yaw'])*lane-math.sin(dock['Yaw'])*depth
                z=dock['Spot'][2]-math.sin(dock['Yaw'])*lane-math.cos(dock['Yaw'])*depth
                for dx,dz in ((0,0),(-.5,0),(.5,0),(0,-.5),(0,.5)):
                    assert (math.floor((x+dx)/resolution),math.floor((z+dz)/resolution)) in occupied, \
                        dock['Id']+' strength target misses actual occupied native water'
                    for p,x0,x1,z0,z1 in colliders:
                        if x0<=x+dx<=x1 and z0<=z+dz<=z1:
                            hit=interval(p,x+dx,z+dz)
                            assert not hit or hit[1]<water['Center'][1]+.05 or hit[0]>dock['Spot'][1]+9, \
                                dock['Id']+' casting water is obstructed by '+p['path']
                    cast_samples+=1

    # Every masonry prism must connect to the visible basin, directly or by
    # true face/edge contact with the other triangulated bank pieces. Merely
    # sampling the bounding box of an oblique wedge gives false support results.
    rim_names = {'LagoonRetainingRim', 'LagoonInnerRetainingFace', 'LagoonBoundaryReturn', 'LagoonCoping'}
    boundaries = [p for p in parts if p['name'] in rim_names]
    fence_posts = [p for p in parts if p['name'] == 'LagoonFencePost']
    basin_faces = [p for p in parts if p['name'] == 'WalkableMeadow' and '/SuspendedLagoon/' in p['path']]
    assert boundaries and fence_posts and basin_faces, 'Missing supported lagoon boundary'
    assert set(water_surfaces) == set(waters), 'Every native-water region needs its exact captured footprint'
    rim_samples, bank_samples, wet_edge_samples, air_cells = 0, 0, 0, 0
    for zone, water in waters.items():
        surface = water_surfaces[zone]
        resolution = surface['resolution']
        assert resolution == 4, 'Water footprint must use the production Terrain resolution'
        assert surface['minimum'][1] > max(p[1] for p in surface['basin'])+.5, zone+' native water extends below its basin floor'
        assert surface['maximum'][1] == water['Center'][1], zone+' water volume changed its surface height'
        cells = {(round(p[0]/resolution-.5), round(p[2]/resolution-.5)) for p in surface['cells']}
        assert len(cells) == len(surface['cells']) and cells, zone+' has missing or duplicated water cells'
        # All native water, including the waterfall channel, must remain one
        # connected surface. A detached decorative source is not a pond outlet.
        reached, frontier = {next(iter(cells))}, [next(iter(cells))]
        while frontier:
            x, z = frontier.pop()
            for candidate in ((x-1,z), (x+1,z), (x,z-1), (x,z+1)):
                if candidate in cells and candidate not in reached:
                    reached.add(candidate)
                    frontier.append(candidate)
        assert reached == cells, zone+' water source is disconnected from its lagoon'
        inner, outer = surface['inner'], surface['outer']
        assert len(inner) == len(outer) >= 12, zone+' lost its fitted bank outline'
        xmin, xmax = min(x for x,z in cells)-1, max(x for x,z in cells)+1
        zmin, zmax = min(z for x,z in cells)-1, max(z for x,z in cells)+1
        for ix in range(xmin, xmax+1):
            for iz in range(zmin, zmax+1):
                if (ix,iz) in cells:
                    continue
                # Reserve a full stud between the open wet hole and air cells;
                # this catches both diagonal voxel steps and square source lips.
                assert not clip_rectangle(inner, ix*resolution-1, (ix+1)*resolution+1,
                                          iz*resolution-1, (iz+1)*resolution+1), zone+' open pond exposes a dry Terrain cell'
                air_cells += 1
        for ix,iz in cells:
            for dx,dz in ((0,0),(0,resolution),(resolution,0),(resolution,resolution)):
                assert inside_polygon(outer,ix*resolution+dx,iz*resolution+dz), zone+' native water extends beyond its retaining bank'
        assert all(inside_polygon(surface['basin'],p[0],p[2]) for p in outer), zone+' bank extends beyond its visible basin foundation'
        bank = [p for p in boundaries if p.get('boundaryZoneId') == zone]
        assert bank, zone+' has no tagged physical bank'
        assert all(p['collide'] and p['query'] and p['alpha'] == 1 for p in bank), zone+' boundary gained hidden collision'
        geometries = [solid_geometry(p) for p in bank]
        seated = set()
        for index, geometry in enumerate(geometries):
            for vertex in geometry[0]:
                if vertex[1] > water['Center'][1]-4.5:
                    continue
                if any(hit and abs(hit[1]-(vertex[1]+.1)) < .3
                       for floor in basin_faces if (hit := interval(floor,vertex[0],vertex[2]))):
                    seated.add(index)
                    rim_samples += 1
                    break
        assert seated, zone+' retaining walls have no seated foundation'
        remaining = set(range(len(bank)))-seated
        while remaining:
            joined = {index for index in remaining
                      if any(touching_solids(geometries[index], geometries[other]) for other in seated)}
            assert joined, zone+' floating boundary pieces: '+', '.join(bank[index]['name'] for index in sorted(remaining)[:5])
            seated.update(joined)
            remaining.difference_update(joined)
        coping = [p for p in bank if p['name'] == 'LagoonCoping']
        spill = surface['spillway']
        for index, a in enumerate(outer):
            b, ia, ib = outer[(index+1)%len(outer)], inner[index], inner[(index+1)%len(inner)]
            length = math.hypot(b[0]-a[0],b[2]-a[2])
            for step in range(math.ceil(length)+1):
                along = min(1,step/length)
                outside = [a[i]+(b[i]-a[i])*along for i in range(3)]
                inside = [ia[i]+(ib[i]-ia[i])*along for i in range(3)]
                for across in (.04,.25,.5,.75,.96):
                    x,z = (outside[i]+(inside[i]-outside[i])*across for i in (0,2))
                    if spill['MinX']-.201 <= x <= spill['MaxX']+.201 and z >= spill['MinZ']-.201:
                        continue
                    assert any(hit and abs(hit[1]-(water['Center'][1]+.35)) < .02
                               for p in coping if (hit := interval(p,x,z))), zone+f' coping gap at ({x:.3f},{z:.3f})'
                    bank_samples += 1
                # A point half a stud inside each wet edge must remain real
                # selected water, with no coping laid across it.
                dx,dz = ib[0]-ia[0],ib[2]-ia[2]
                wet_length = math.hypot(dx,dz)
                x = inside[0]-dz/wet_length*.5
                z = inside[2]+dx/wet_length*.5
                assert (math.floor(x/resolution),math.floor(z/resolution)) in cells, zone+' wet bank edge misses native water'
                assert not any(hit and hit[0] < water['Center'][1]+.5 and hit[1] > water['Center'][1]-.4
                               for p in coping if (hit := interval(p,x,z))), zone+' coping covers the open pond'
                wet_edge_samples += 1
    post_samples = 0
    for post in fence_posts:
        x,_,z = post['position']
        hit = interval(post,x,z)
        assert hit and post['collide'] and post['query'] and post['alpha'] == 1
        # The complete round foot must sit on stone, including the posts beside
        # pier/portal/spillway cuts. Centre-only checks miss an overhanging foot.
        radius = min(post['size'][1:])/2
        for dx,dz in [(0,0)]+[(radius*math.cos(t*math.tau/8),radius*math.sin(t*math.tau/8)) for t in range(8)]:
            assert any(support[1] >= hit[0]-.02 and support[0] < hit[0]
                       for p in boundaries if p['name'] == 'LagoonCoping' and p.get('boundaryZoneId') == post.get('boundaryZoneId')
                       if (support := interval(p,x+dx,z+dz))), post['path']+' fence foot overhangs its coping'
            post_samples += 1
    ropes = [p for p in parts if p['name'] == 'LagoonFenceRope']
    rope_ends = [[p['position'][i]+p['rotation'][i][0]*side*p['size'][0]/2 for i in range(3)]
                 for p in ropes for side in (-1,1)]
    for index, (x,y,z) in enumerate(rope_ends):
        seated_post = any(hit and hit[0] <= y <= hit[1] for p in fence_posts if (hit := interval(p,x,z)))
        joined_rope = any(index != other and math.dist((x,y,z),end) < .001 for other,end in enumerate(rope_ends))
        assert seated_post or joined_rope, 'Shoreline rope has a detached endpoint'
    opaque = []
    for p in parts:
        if p['alpha'] < .98:
            continue
        radii = [sum(abs(p['rotation'][i][j])*p['size'][j]/2 for j in range(3)) for i in range(3)]
        opaque.append((p,p['position'][0]-radii[0],p['position'][0]+radii[0],p['position'][2]-radii[2],p['position'][2]+radii[2]))
    spillway_samples, channel_samples, falling_rays = 0, 0, 0
    for zone, water in waters.items():
        surface = water_surfaces[zone]
        spill = surface['spillway']
        source_z = spill['SourceFrontZ']
        falls = [p for p in parts if p['name'] == 'WaterfallCurtain'
                 and abs(p['position'][2]-source_z) < .01
                 and spill['MinX'] <= p['position'][0] <= spill['MaxX']]
        assert len(falls) == 3, zone+' must retain its full three-strip waterfall outlet'
        obstacles = [p for p in parts if '/'+zone+'PondTerraces/' in p['path'] and p['collide']]
        cells = {(round(p[0]/4-.5),round(p[2]/4-.5)) for p in surface['cells']}
        for fall in falls:
            top = fall['position'][1]+fall['size'][1]/2
            assert abs(top-water['Center'][1]) < .01, zone+' waterfall starts away from native-water level'
            for across in (-.49,-.25,0,.25,.49):
                x = fall['position'][0]+fall['rotation'][0][0]*across*fall['size'][0]
                z = fall['position'][2]+fall['rotation'][2][0]*across*fall['size'][0]
                assert (math.floor(x/4),math.floor((z-.1)/4)) in cells, zone+' outlet starts at an unfilled native-water cell'
                for y in (top+.1,top-.1,top-1,top-3,top-5.5):
                    for p in obstacles:
                        hit = interval(p,x,z)
                        assert not hit or not hit[0]+.01 < y < hit[1]-.01, zone+' outlet passes through '+p['name']
                spillway_samples += 1
            # Test the complete falling interval against visible geometry, also
            # the noncollidable under-cliff facets. Fixed height samples miss
            # the thin basin floor that formerly cut right through each fall.
            for lane in range(9):
                across = -.49+lane*.98/8
                for depth in (-.09,0,.09):
                    x = fall['position'][0]+fall['rotation'][0][0]*across*fall['size'][0]+fall['rotation'][0][2]*depth
                    z = fall['position'][2]+fall['rotation'][2][0]*across*fall['size'][0]+fall['rotation'][2][2]*depth
                    bottom = fall['position'][1]-fall['size'][1]/2
                    for p,x0,x1,z0,z1 in opaque:
                        if not x0-EPS <= x <= x1+EPS or not z0-EPS <= z <= z1+EPS:
                            continue
                        hit = interval(p,x,z)
                        assert not hit or max(hit[0],bottom+.1) >= min(hit[1],top-.01)-EPS, zone+' falling water crosses visible '+p['path']
                    falling_rays += 1
        # Trace the actual visible channel from the inner wet hole through the
        # new low rock tunnels to the falling front. Connectivity of Terrain
        # cells alone would allow a stone wall to block the visible outlet.
        for lane in range(21):
            x = spill['MinX']+.03+(spill['MaxX']-spill['MinX']-.06)*lane/20
            edge_hits = []
            for index,a in enumerate(surface['inner']):
                b = surface['inner'][(index+1)%len(surface['inner'])]
                if min(a[0],b[0]) <= x <= max(a[0],b[0]) and abs(a[0]-b[0]) > EPS:
                    t = (x-a[0])/(b[0]-a[0])
                    edge_hits.append(a[2]+(b[2]-a[2])*t)
            assert edge_hits, zone+' source lies outside its wet hole'
            start = max(edge_hits)-.2
            length = source_z-start
            assert length > 0, zone+' outlet is behind its source'
            steps = math.ceil(length/.5)
            for step in range(steps+1):
                z = start+length*step/steps
                # The far edge belongs to the last filled cell behind it.
                assert (math.floor(x/4),math.floor(min(z,source_z-.01)/4)) in cells, zone+' visible outlet crosses dry Terrain'
                for p in obstacles:
                    hit = interval(p,x,z)
                    assert not hit or not (hit[0]+.01 < water['Center'][1]+.1 < hit[1]-.01
                                           or hit[0]+.01 < water['Center'][1]-.1 < hit[1]-.01), zone+' source channel passes through '+p['name']
                channel_samples += 1

    shore_samples = 0
    for water in layout['Waters']:
        shore = [p for p in parts if '/'+water['Id']+'PondTerraces/' in p['path']]
        solid = [p for p in shore if p['collide']]
        assert shore and solid, water['Id']+' has no physical shoreline'
        assert all(p['alpha'] > 0 and p['query'] for p in solid), 'Invisible, full-height shore collision returned'
        assert all(p['position'][1]+p['size'][1]/2 <= water['Center'][1]+32 for p in shore), 'Scenic walls overwhelm the low shoreline'
        for p in shore:
            if p['name'] != 'PondWaterfallCurtain':
                continue
            assert abs(p['position'][1]-p['size'][1]/2-water['Center'][1]-.12) < .01, 'Waterfall ends above or below its water'
            for across in (-.49, 0, .49):
                x = p['position'][0]+p['rotation'][0][0]*p['size'][0]*across
                z = p['position'][2]+p['rotation'][2][0]*p['size'][0]*across
                surface = water_surfaces[water['Id']]
                assert inside_polygon(surface['inner'],x,z), 'Waterfall edge lands on the bank instead of the open wet hole'
                assert any(abs(x-cell[0]) <= surface['resolution']/2+EPS and abs(z-cell[2]) <= surface['resolution']/2+EPS for cell in surface['cells']), 'Waterfall edge falls onto an unfilled native-water cell'
                assert not any(hit and hit[0] < water['Center'][1]+.5 and hit[1] > water['Center'][1]-.4 for cap in boundaries if cap['name'] == 'LagoonCoping' if (hit := interval(cap,x,z))), 'Waterfall lands inside the coping'
                for vertical in (-.4, 0, .4):
                    y = p['position'][1]+p['size'][1]*vertical
                    for rock in solid:
                        hit = interval(rock, x, z)
                        assert not hit or not hit[0]+.01 < y < hit[1]-.01, p['path']+' runs inside '+rock['name']
                    shore_samples += 1
    print(f'PASS {len(parts)} bounded, anchored source parts; {len(colliders)} colliders incl. invisible floors/rails')
    print(f'PASS {styled_parts} native surface bindings across {len(styles)} shared material presets; mesh visuals excluded')
    print(f'PASS {sampled} route rays with continuous support and six-stud headroom across a 2.6-stud corridor')
    print(f'PASS {trail_samples} visible-trail samples covering the existing walking corridors')
    print(f'PASS {spawn_samples} spawn-footprint rays supported by the underlying world with six-stud headroom')
    print(f'PASS {arrival_samples} arrival-footprint rays, five persistent queryable floors, immediate fishing range and separate travel prompts')
    print(f'PASS {portal_samples} portal-approach rays through open side rails; arrivals clear of walk-in triggers')
    print('PASS native-water regions and structural canopy/cliff/roof shadow flags')
    print(f'PASS {visible_floors} visible physical walking surfaces; {cast_samples} clear bobber-lane samples; no raised spawn or hidden rock boxes')
    print(f'PASS authored materials without stud overrides; {shore_samples} visible waterfall samples reaching native water')
    print(f'PASS {rim_samples} foundation-seated masonry pieces; every bank prism connected by true convex contact')
    print(f'PASS {bank_samples} continuous mitered coping samples; {wet_edge_samples} wet-edge rays; {air_cells} expanded dry cells excluded')
    print(f'PASS {post_samples} seated fence-foot rays, {len(rope_ends)} attached rope ends; {spillway_samples} wet-fed outlet-width samples')
    print(f'PASS {channel_samples} unobstructed wet channel samples; {falling_rays} complete falling intervals clear of opaque world geometry')
    print('Geometry inspection only; Roblox physics, streaming and device frame rate require Studio/client tests.')


if __name__ == '__main__':
    validate(json.loads(Path(sys.argv[1]).read_text()))
