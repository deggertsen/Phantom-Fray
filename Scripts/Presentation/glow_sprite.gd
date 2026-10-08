class_name GlowSprite
extends RefCounted

## Additive camera-facing halos. This is how things glow without a bloom pass,
## which is too expensive in stereo on Quest.

static var _texture: Texture2D
static var _ring_texture: Texture2D

## A soft round halo quad. `strength` is how much light it adds at its center.
static func create(color: Color, size: float, strength: float) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	halo.mesh = quad
	halo.material_override = material(color, strength)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo

static func material(color: Color, strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	mat.disable_fog = true
	mat.albedo_texture = texture()
	mat.albedo_color = Color(color.r, color.g, color.b, strength)
	return mat

## A thin bright ring with a soft inner edge, for shockwaves.
static func ring_texture() -> Texture2D:
	if _ring_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.86, 0.93, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.08), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_ring_texture = tex
	return _ring_texture

static func texture() -> Texture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_texture = tex
	return _texture
