-- Geometry capture shim for offline art inspection, not a Roblox runtime emulator.
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then return t / t.Magnitude end
	return V[k]
end
local Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V) end
function V.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function V.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function V.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function V.__mul(a,b)
	if type(a)=="number" then return b*a end
	if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
	return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
function V.__div(a,b) return a*(1/b) end
function V:Lerp(b,t) return self+(b-self)*t end
function V:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
Vector3.zero, Vector3.yAxis = Vector3.new(), Vector3.new(0,1,0)
Vector3.one = Vector3.new(1,1,1)
Vector3.xAxis, Vector3.zAxis = Vector3.new(1,0,0), Vector3.new(0,0,1)
local Vector2 = {new=function(x,y) return setmetatable({X=x,Y=y},{__index=function(t,k) if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y) end end}) end}
local CF = {}
local identity = {{1,0,0},{0,1,0},{0,0,1}}
local function matmul(a,b)
	local out = {{0,0,0},{0,0,0},{0,0,0}}
	for i=1,3 do for j=1,3 do for k=1,3 do out[i][j]+=a[i][k]*b[k][j] end end end
	return out
end
local function transform(m,v) return Vector3.new(m[1][1]*v.X+m[1][2]*v.Y+m[1][3]*v.Z,m[2][1]*v.X+m[2][2]*v.Y+m[2][3]*v.Z,m[3][1]*v.X+m[3][2]*v.Y+m[3][3]*v.Z) end
local function frame(p,r) return setmetatable({p=p,r=r or identity},CF) end
CF.__index=function(t,k)
 if k=="Position" then return t.p end
 if k=="UpVector" then return Vector3.new(t.r[1][2],t.r[2][2],t.r[3][2]) end
 if k=="RightVector" then return Vector3.new(t.r[1][1],t.r[2][1],t.r[3][1]) end
 if k=="LookVector" then return Vector3.new(-t.r[1][3],-t.r[2][3],-t.r[3][3]) end
 return CF[k]
end
local CFrame = {}
function CFrame.new(x,y,z) return frame(if type(x)=="table" then x else Vector3.new(x,y,z)) end
CFrame.identity = CFrame.new()
function CFrame.fromMatrix(p,x,y,z)
 z=z or x:Cross(y)
 return frame(p,{{x.X,y.X,z.X},{x.Y,y.Y,z.Y},{x.Z,y.Z,z.Z}})
end
function CF:PointToWorldSpace(p) return self*p end
function CF:PointToObjectSpace(p) return self:Inverse()*p end
function CF.__sub(a,b) return frame(a.p-b,a.r) end
function CFrame.Angles(x,y,z)
	local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
	return frame(Vector3.zero,matmul(matmul({{1,0,0},{0,cx,-sx},{0,sx,cx}},{{cy,0,sy},{0,1,0},{-sy,0,cy}}),{{cz,-sz,0},{sz,cz,0},{0,0,1}}))
end
function CFrame.lookAt(a,b)
	local z=(a-b).Unit
	local up=if math.abs(z.Y)>0.999 then Vector3.new(1,0,0) else Vector3.yAxis
	local x=up:Cross(z).Unit
	local y=z:Cross(x)
	return frame(a,{{x.X,y.X,z.X},{x.Y,y.Y,z.Y},{x.Z,y.Z,z.Z}})
end
function CF.__mul(a,b)
	if getmetatable(b)==V then return a.p+transform(a.r,b) end
	return frame(a.p+transform(a.r,b.p),matmul(a.r,b.r))
end
function CF.__add(a,b) return frame(a.p+b,a.r) end
function CF:Inverse()
	local r=self.r
	local transpose={{r[1][1],r[2][1],r[3][1]},{r[1][2],r[2][2],r[3][2]},{r[1][3],r[2][3],r[3][3]}}
	return frame(transform(transpose,-self.p),transpose)
end
local Color = {}
Color.__index=Color
local Color3 = {}
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},Color) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color:Lerp(b,t) return Color3.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t) end
-- Sequence values are retained as data; this geometry-only shim does not render Beams.
local ColorSequence = {new=function(value) return {Value=value} end}
local NumberSequence = {new=function(value) return {Value=value} end}
local Region3={}
local regionMt={}
regionMt.__index=regionMt
function Region3.new(lo,hi) return setmetatable({lo=lo,hi=hi,Size=hi-lo,CFrame=CFrame.new((hi+lo)/2)},regionMt) end
function regionMt:ExpandToGrid(r)
 return Region3.new(Vector3.new(math.floor(self.lo.X/r)*r,math.floor(self.lo.Y/r)*r,math.floor(self.lo.Z/r)*r),Vector3.new(math.ceil(self.hi.X/r)*r,math.ceil(self.hi.Y/r)*r,math.ceil(self.hi.Z/r)*r))
end
local UDim={new=function(scale,offset) return {Scale=scale,Offset=offset} end}
local UDim2 = {fromScale=function(x,y) return {x,y} end, fromOffset=function(x,y) return {x,y} end}
local Enum=setmetatable({}, {__index=function(t,k) local e=setmetatable({}, {__index=function(_,v) return v end}); rawset(t,k,e); return e end})
local Random = {}
function Random.new(seed)
	local state=seed or 31
	return {NextNumber=function(_,lo,hi) state=(state*16807)%2147483647; local n=state/2147483647; return (lo or 0)+n*((hi or 1)-(lo or 0)) end}
end
local all = {}
local methods = {}
local mt = {}
mt.__index=function(t,k)
	if methods[k] then return methods[k] end
	if k=="Position" and (t.props.ClassName=="Part" or t.props.ClassName=="SpawnLocation" or t.props.ClassName=="WedgePart" or t.props.ClassName=="Attachment") then return t.props.CFrame.p end
	if t.props.ClassName=="Attachment" and (k=="WorldCFrame" or k=="WorldPosition") then
		local parent=t.props.Parent
		local parentFrame=if parent and parent:IsA("BasePart") then parent.CFrame
			elseif parent and parent:IsA("Attachment") then parent.WorldCFrame else CFrame.identity
		local worldFrame=parentFrame*t.props.CFrame
		return if k=="WorldPosition" then worldFrame.Position else worldFrame
	end
	return t.props[k]
end
mt.__newindex=function(t,k,v)
	if k=="Parent" then
		local old=t.props.Parent
		if old then local idx=table.find(old.children,t); if idx then table.remove(old.children,idx) end end
		if v then table.insert(v.children,t) end
	elseif k=="Position" and (t.props.ClassName=="Part" or t.props.ClassName=="SpawnLocation" or t.props.ClassName=="WedgePart" or t.props.ClassName=="Attachment") then t.props.CFrame=frame(v,t.props.CFrame.r); return end
	t.props[k]=v
end
local Instance={}
function Instance.new(class)
	local inst=setmetatable({props={ClassName=class,Name=class,CFrame=CFrame.identity,Size=Vector3.new(1,1,1),Color=Color3.new(0.5,0.5,0.5),CanCollide=true,Transparency=0,Shape="Block",Material="SmoothPlastic"},children={},attributes={}},mt)
	table.insert(all,inst)
	return inst
end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation" or self.ClassName=="WedgePart")) end
function methods:SetAttribute(k,v) self.attributes[k]=v end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:AddTag(tag) self.tags=self.tags or {};self.tags[tag]=true end
function methods:RemoveTag(tag) if self.tags then self.tags[tag]=nil end end
function methods:HasTag(tag) return self.tags~=nil and self.tags[tag]==true end
function methods:GetTags()
	local tags={}
	if self.tags then for tag in self.tags do table.insert(tags,tag) end end
	return tags
end
function methods:GetChildren() return self.children end
function methods:GetDescendants()
	local out={}
	local function visit(node) for _,child in node.children do table.insert(out,child); visit(child) end end
	visit(self)
	return out
end
function methods:FindFirstChild(name) for _,child in self.children do if child.Name==name then return child end end return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:Clone()
	local clone=Instance.new(self.ClassName)
	for k,v in self.props do if k~="Parent" then clone.props[k]=v end end
	for _,child in self.children do child:Clone().Parent=clone end
	return clone
end
function methods:GetPivot() return if self.PrimaryPart then self.PrimaryPart.CFrame else self.WorldPivot or CFrame.identity end
function methods:PivotTo(cf)
	local delta=cf*self:GetPivot():Inverse()
	for _,p in self:GetDescendants() do if p:IsA("BasePart") then p.CFrame=delta*p.CFrame end end
	if not self.PrimaryPart then self.WorldPivot=cf end
end
local workspace=Instance.new("Workspace")
local terrain=Instance.new("Terrain")
terrain.Parent=workspace
workspace.Terrain=terrain
local waterWrites={}
function methods:WriteVoxels(region,res,materials,occupancy)
 local filled=0
 for _,x in occupancy do for _,y in x do for _,cell in y do if cell>0 then filled+=1 end end end end
 table.insert(waterWrites,{region=region,resolution=res,filled=filled})
end
local Lighting=Instance.new("Lighting")
local shared=Instance.new("Folder")
shared.Name="FishingShared"
local ReplicatedStorage=Instance.new("ReplicatedStorage")
shared.Parent=ReplicatedStorage
local game={GetService=function(_,name) return if name=="Lighting" then Lighting else ReplicatedStorage end}
local modules={}
local require=function(token) return modules[token.Name] end
local script={Parent=shared}
