# Native geometry and preview limits — v1.5

The gull wings use solid WedgeParts and Blocks. Their white surfaces overlap the
body and the dark feather roots. Gray coverts and primaries belong to the same
animated shoulder model. The animation check measures both extremes and detaches
and restores a whole gull, then a delayed shoulder PrimaryPart. These checks run
production generation and animation with spatial/event doubles; they are not a
Roblox render or replication test.

Cosmetic ellipsoids use `SpecialMesh.MeshType = Sphere`, with `Scale = (1,1,1)`
inside the sized parent Part. Roblox documents this built-in mesh as independently
resizable on each axis. There is no external MeshId or upload. These Parts have
collision, touch and queries disabled. Solid floors and rails continue to use
visible native Blocks, WedgeParts and circular Cylinders with matching collision.
Cosmetic oval dishes use shallow sphere meshes; solid disk floors use circles.

References:

- [SpecialMesh](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/SpecialMesh.yaml)
- [DataModelMesh and Scale](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/DataModelMesh.yaml)
- [CylinderMesh](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/CylinderMesh.yaml)

The earlier Blender exporter rendered every native Ball as a freely stretched
ellipsoid and every Cylinder as independently stretchable across its cross-section.
That approximation did not prove what Roblox displayed. The exporter now records
the native shape separately from explicit Sphere mesh visuals; checks reject
unexplained ellipsoids and non-circular native cylinder cross-sections. The exact
numerical native Ball sizing rule was not measured in Roblox here.

`WorldLayout.waterGeometry` supplies the same occupied four-stud cells to Terrain
generation and the bank/basin builder. The outer coping encloses their corners;
the inner opening avoids every air cell with clearance. Stone facets share miter
vertices. Waterfall sources use the same grid-aligned wet channel. The offline
preview shows these cells instead of drawing an unrelated smooth water ellipse.
The native water is one full four-stud layer; the former eight-stud volume
protruded below the basin's tapered underside near outer cell corners. Its surface
height is retained and its bottom now remains above the floor.

Blender previews inspect geometry, joins, colors and selected animation poses.
They do not reproduce Roblox terrain smoothing, waves, shaders, SurfaceGui text,
streaming, sound, native collision or device performance. SpecialMesh material
appearance can also differ from an ordinary Part's procedural material. Actual
Studio/client inspection is still required, especially for water against stone,
wing visibility at normal camera distance, cloth surfaces and sign legibility.
