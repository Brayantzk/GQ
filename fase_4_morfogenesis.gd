extends Node3D

var bestia_jugador: RigidBody3D
var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label

var stats: Dictionary
var energia_maxima: float
var energia_actual: float
var salud_actual: float
var genoma_secuencia: Array
var semillas_voronoi: Array = []

var plancton_devorado: int = 0
var meta_colonizacion: int = 20
var juego_activo: bool = false
var lista_nodos_visuales: Array = []

const SHADER_VORONOI = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;
uniform vec4 albedo_color : source_color;
void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = albedo_color.rgb; 
	ALPHA = 0.4 + fresnel * 0.6; 
	EMISSION = albedo_color.rgb * fresnel * 1.5;
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if GestorQuimico.mazo_genetico.is_empty():
		return
		
	var memoria = GestorQuimico.mazo_genetico[-1]
	genoma_secuencia = memoria.get("secuencia", [])
	stats = memoria["fenotipo"].get("stats_3d", {}).duplicate()
	semillas_voronoi = memoria["fenotipo"].get("fenotipo_visual", {}).get("semillas_voronoi", [])
	
	energia_maxima = stats.get("energia_reserva", 1500.0)
	energia_actual = energia_maxima
	salud_actual = stats.get("salud", 250.0)
	
	_construir_entorno()
	_ensamblar_organismo_voronoi()
	_generar_ecosistema_plancton()
	_construir_ui()
	
	juego_activo = true

func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.002, 0.01, 0.018)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.005, 0.03, 0.05)
	env.glow_enabled = true
	env.glow_intensity = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-65, 50, 0)
	luz.light_energy = 0.8
	add_child(luz)

func _ensamblar_organismo_voronoi() -> void:
	bestia_jugador = RigidBody3D.new()
	bestia_jugador.gravity_scale = 0.0
	bestia_jugador.linear_damp = 1.5
	bestia_jugador.angular_damp = 4.0
	bestia_jugador.axis_lock_angular_x = true 
	bestia_jugador.axis_lock_angular_z = true
	bestia_jugador.axis_lock_linear_y = true
	bestia_jugador.contact_monitor = true
	bestia_jugador.max_contacts_reported = 15
	bestia_jugador.body_entered.connect(_on_bestia_collision)
	add_child(bestia_jugador)
	
	var offset_global_z: float = -(semillas_voronoi.size() * 0.5)
	
	# PASO 1: Instanciar Nodos Espaciales
	for i in range(semillas_voronoi.size()):
		var semilla: Dictionary = semillas_voronoi[i]
		var pos_local: Vector3 = semilla["posicion_semilla"]
		pos_local.z += offset_global_z
		
		var nodo := MeshInstance3D.new()
		nodo.mesh = SphereMesh.new()
		nodo.mesh.radius = 0.7
		nodo.mesh.height = 1.4
		
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER_VORONOI
		mat.shader = sh
		
		var col := Color.WHITE
		match str(semilla["tipo"]):
			"Epitelio": col = Color(0.2, 0.6, 0.75)
			"Miocito": col = Color(0.8, 0.15, 0.15)
			"Neurona": col = Color(0.9, 0.85, 0.05)
			"Adipocito": col = Color(0.75, 0.4, 0.1)
			
		mat.set_shader_parameter("albedo_color", col)
		nodo.material_override = mat
		nodo.position = pos_local
		bestia_jugador.add_child(nodo)
		lista_nodos_visuales.append(nodo)
		
		var col_shape := CollisionShape3D.new()
		col_shape.shape = SphereShape3D.new()
		col_shape.shape.radius = 0.7
		col_shape.position = pos_local
		bestia_jugador.add_child(col_shape)
	
	# PASO 2: Trazar Ductos Maquínicos (Tejido Conectivo)
	for i in range(lista_nodos_visuales.size() - 1):
		var n_actual: Node3D = lista_nodos_visuales[i]
		var n_siguiente: Node3D = lista_nodos_visuales[i+1]
		var dist: float = n_actual.position.distance_to(n_siguiente.position)
		
		var ducto := MeshInstance3D.new()
		ducto.mesh = CylinderMesh.new()
		ducto.mesh.top_radius = 0.15
		ducto.mesh.bottom_radius = 0.15
		ducto.mesh.height = dist
		
		var mat_ducto := ShaderMaterial.new()
		var sh_ducto := Shader.new()
		sh_ducto.code = SHADER_VORONOI
		mat_ducto.shader = sh_ducto
		mat_ducto.set_shader_parameter("albedo_color", Color(0.5, 0.9, 0.4, 0.8)) 
		ducto.material_override = mat_ducto
		
		ducto.position = n_actual.position.lerp(n_siguiente.position, 0.5)
		var up_vec := Vector3.UP
		var dir := (n_siguiente.position - n_actual.position).normalized()
		var axis := up_vec.cross(dir).normalized()
		var ang := acos(up_vec.dot(dir))
		if axis.length_squared() > 0.001: 
			ducto.transform.basis = Basis(axis, ang)
		
		bestia_jugador.add_child(ducto)
		
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	camara = Camera3D.new()
	camara.current = true
	camara.position = Vector3(0.0, 18.0, 15.0)
	camara.rotation_degrees = Vector3(-65, 0, 0)
	pivot_camara.add_child(camara)

func _generar_ecosistema_plancton() -> void:
	for i in range(120):
		var presa := RigidBody3D.new()
		presa.gravity_scale = 0.0
		presa.linear_damp = 1.0
		presa.axis_lock_linear_y = true
		
		var angulo: float = randf() * TAU
		var distancia: float = randf_range(25.0, 280.0)
		presa.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		
		var mesh := MeshInstance3D.new()
		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = 0.55
		cap_mesh.height = 1.5
		mesh.mesh = cap_mesh
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.7, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.01, 0.2, 0.1)
		mesh.material_override = mat
		presa.add_child(mesh)
		
		var col := CollisionShape3D.new()
		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.55
		cap_shape.height = 1.5
		col.shape = cap_shape
		presa.add_child(col)
		
		presa.set_meta("es_plancton", true)
		presa.apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 12.0)
		add_child(presa)

func _on_bestia_collision(body: Node) -> void:
	if not juego_activo: 
		return
	
	if body.has_meta("es_plancton"):
		plancton_devorado += 1
		energia_actual = min(energia_actual + 80.0, energia_maxima)
		
		var t := create_tween()
		t.tween_property(body, "scale", Vector3.ZERO, 0.1)
		t.tween_callback(body.queue_free)
		
		_actualizar_ui()
		
		if plancton_devorado >= meta_colonizacion:
			_conquistar_ecosistema()

func _conquistar_ecosistema() -> void:
	juego_activo = false
	ui_texto.text = "¡DOMINIO ECOLÓGICO ALCANZADO!\nTu sistema de ductos y orgánulos sobrevive al Proterozoico."
	ui_texto.modulate = Color(0.2, 1.0, 0.5)
	await get_tree().create_timer(4.0).timeout
	
	# Transición a la Fase 5: Sociología Cibernética
	GestorQuimico.fase_evolutiva_actual = 5
	GestorQuimico.transicionar_escena(0) # Lo mandamos al hub para que el jugador vea su evolución sociológica

func _physics_process(delta: float) -> void:
	if not is_instance_valid(bestia_jugador) or not juego_activo: 
		return
	
	pivot_camara.position = pivot_camara.position.lerp(bestia_jugador.position, delta * 4.0)
	
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1.0
	
	var velocidad_impulsion: float = max(150.0, float(stats.get("fuerza_motriz", 150.0)) * 2.0)
	var esta_nadando: bool = (input_dir != Vector2.ZERO)
	var costo_basal: float = 15.0 if esta_nadando else 4.0
	
	if esta_nadando:
		input_dir = input_dir.normalized()
		var direccion_deseada := Vector3(input_dir.x, 0.0, input_dir.y)
		
		bestia_jugador.apply_central_force(direccion_deseada * velocidad_impulsion)
		
		var angulo_obj: float = atan2(-direccion_deseada.x, -direccion_deseada.z)
		bestia_jugador.rotation.y = lerp_angle(bestia_jugador.rotation.y, angulo_obj, delta * 2.5)
		
	energia_actual -= delta * costo_basal
	_actualizar_ui()
	
	if energia_actual <= 0.0:
		juego_activo = false
		ui_texto.text = "INANICIÓN. Fallo en los ductos sistémicos."
		ui_texto.modulate = Color(1.0, 0.2, 0.2)
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()

func _construir_ui() -> void:
	var canvas := CanvasLayer.new()
	ui_texto = Label.new()
	ui_texto.position = Vector2(25, 25)
	ui_texto.add_theme_font_size_override("font_size", 20)
	ui_texto.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	canvas.add_child(ui_texto)
	add_child(canvas)

func _actualizar_ui() -> void:
	if not is_instance_valid(ui_texto): 
		return
		
	var text: String = "ESTADIO ANIMAL - RED VORONOI\n"
	text += "Energía Sistémica (ATP): " + str(int(energia_actual)) + " / " + str(int(energia_maxima)) + "\n"
	text += "Salud de Ductos: " + str(int(salud_actual)) + "\n"
	text += "Plancton Devorado: " + str(plancton_devorado) + " / " + str(meta_colonizacion) + "\n"
	text += "\n[WASD] Nadar. Mantén la red viva."
	ui_texto.text = text
