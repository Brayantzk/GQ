extends Node3D

var jugador_molecula: RigidBody3D
var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label

var stats_actuales: Dictionary
var energia_maxima: float
var energia_actual: float
var entropia_tasa: float 

var atomos_devorados: Array = []
var juego_activo: bool = true

var posicion_punta_polimero: Vector3 = Vector3.ZERO
var indice_enlace_actual: int = 0
var umbral_saturacion_dinamico: int = 12

const SHADER_NUBE_CUANTICA = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;
uniform vec3 color_emision;
uniform float radio_orbital;
vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yxz+33.33);
	return fract((p3.xxy + p3.yxx)*p3.zyx);
}
float simplex_noise(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}
void fragment() {
	vec3 coord = VERTEX * 5.0 + (TIME * 2.0);
	float ruido = simplex_noise(coord);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float densidad = fresnel * (0.5 + ruido * 0.5);
	ALBEDO = color_emision * densidad;
	ALPHA = clamp(densidad * 1.5, 0.0, 0.8);
}
"""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GestorQuimico.mazo_genetico.is_empty(): return
		
	var memoria_genetica = GestorQuimico.mazo_genetico[-1]
	var secuencia_atomos = memoria_genetica["secuencia"]
	stats_actuales = memoria_genetica["fenotipo"]["stats_3d"].duplicate()
	
	energia_maxima = max(memoria_genetica["fenotipo"]["energia_metabolica"] * 10.0, 500.0)
	energia_actual = energia_maxima
	entropia_tasa = stats_actuales["consumo_atp"] 
	umbral_saturacion_dinamico = clamp(10 + int(memoria_genetica["fenotipo"]["valencia_residual"]), 12, 25)
	
	_construir_entorno_cuantico()
	_construir_jugador_molecular(secuencia_atomos)
	_generar_caldo_nutrientes()
	_generar_radicales_libres() 
	_construir_ui()

func _construir_entorno_cuantico():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.02, 0.04) 
	env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.02; env.volumetric_fog_albedo = Color(0.02, 0.04, 0.06)
	env.glow_enabled = true; env.glow_intensity = 2.0; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	
	var luz_global = DirectionalLight3D.new(); luz_global.rotation_degrees = Vector3(-75, 30, 0); luz_global.light_energy = 0.5; add_child(luz_global)
	
	pivot_camara = Node3D.new(); add_child(pivot_camara)
	camara = Camera3D.new(); camara.current = true; camara.projection = Camera3D.PROJECTION_PERSPECTIVE; camara.fov = 50.0
	camara.position = Vector3(0, 30.0, 10.0); camara.rotation_degrees = Vector3(-75, 0, 0); pivot_camara.add_child(camara)

func _construir_jugador_molecular(secuencia: Array):
	jugador_molecula = RigidBody3D.new()
	jugador_molecula.gravity_scale = 0.0; jugador_molecula.linear_damp = 4.0; jugador_molecula.angular_damp = 5.0
	jugador_molecula.axis_lock_linear_y = true; jugador_molecula.axis_lock_angular_x = true; jugador_molecula.axis_lock_angular_z = true  
	jugador_molecula.contact_monitor = true; jugador_molecula.max_contacts_reported = 10
	jugador_molecula.body_entered.connect(_on_molecula_choca); add_child(jugador_molecula)
	
	var luz_propia = OmniLight3D.new(); luz_propia.light_color = Color(0.4, 0.8, 1.0); luz_propia.light_energy = 2.0; luz_propia.omni_range = 30.0; jugador_molecula.add_child(luz_propia)
	for i in range(secuencia.size()): _enlazar_nuevo_atomo(secuencia[i], false)

func _enlazar_nuevo_atomo(simbolo: String, es_asimilado: bool):
	var data = GestorQuimico.TABLA_PERIODICA[simbolo]
	var radio_atomo = log(data["masa"]) * 0.2 + 0.2
	
	if indice_enlace_actual > 0:
		var angulo = (TAU / 4.0) * indice_enlace_actual 
		var offset = Vector3(cos(angulo), 0.0, sin(angulo)).normalized() * (radio_atomo + 0.6)
		posicion_punta_polimero += offset
		
		var enlace = MeshInstance3D.new(); enlace.mesh = CylinderMesh.new(); enlace.mesh.top_radius = 0.05; enlace.mesh.bottom_radius = 0.05; enlace.mesh.height = offset.length()
		var mat_enlace = StandardMaterial3D.new(); mat_enlace.albedo_color = Color(1.0, 1.0, 1.0, 0.6); mat_enlace.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_enlace.emission_enabled = true; mat_enlace.emission = Color(0.8, 0.8, 1.0) if not es_asimilado else Color(0.2, 1.0, 0.5)
		enlace.material_override = mat_enlace; enlace.position = posicion_punta_polimero - (offset / 2.0)
		
		var up = Vector3.UP; var axis = up.cross(offset.normalized()).normalized(); var angle = acos(up.dot(offset.normalized()))
		if axis.length_squared() > 0.001: enlace.transform.basis = Basis(axis, angle)
		jugador_molecula.add_child(enlace)
		
	var atomo_visual = _crear_atomo_visual(simbolo, radio_atomo); atomo_visual.position = posicion_punta_polimero; jugador_molecula.add_child(atomo_visual)
	var col = CollisionShape3D.new(); col.shape = SphereShape3D.new(); col.shape.radius = radio_atomo; col.position = posicion_punta_polimero; jugador_molecula.add_child(col)
	indice_enlace_actual += 1

func _crear_atomo_visual(simbolo: String, radio: float) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new(); mesh_inst.mesh = SphereMesh.new(); mesh_inst.mesh.radius = radio; mesh_inst.mesh.height = radio * 2.0
	var mat_shader = ShaderMaterial.new(); var sh = Shader.new(); sh.code = SHADER_NUBE_CUANTICA; mat_shader.shader = sh
	var data = GestorQuimico.TABLA_PERIODICA[simbolo]; var color = Color.WHITE
	match data["rol"]:
		"estructural", "estructural_pesado": color = Color(0.4, 0.4, 0.4)
		"energia": color = Color(1.0, 0.9, 0.2)
		"radiactivo": color = Color(0.2, 1.0, 0.2)
		"oxidante": color = Color(1.0, 0.3, 0.3)
		"reactivo": color = Color(0.3, 0.5, 1.0)
		"catalizador": color = Color(0.8, 0.6, 0.2)
		"comodin", "inerte": color = Color(0.6, 0.1, 1.0)
		"radical": color = Color(1.0, 0.0, 0.4) 
		
	mat_shader.set_shader_parameter("color_emision", color); mat_shader.set_shader_parameter("radio_orbital", radio); mesh_inst.material_override = mat_shader
	var nucleo = MeshInstance3D.new(); nucleo.mesh = SphereMesh.new(); nucleo.mesh.radius = radio * 0.15; nucleo.mesh.height = radio * 0.3
	var mat_nuc = StandardMaterial3D.new(); mat_nuc.albedo_color = Color.WHITE; mat_nuc.emission_enabled = true; mat_nuc.emission = color * 2.0
	nucleo.material_override = mat_nuc; mesh_inst.add_child(nucleo)
	return mesh_inst

func _generar_caldo_nutrientes():
	for i in range(250):
		var ion = RigidBody3D.new(); ion.gravity_scale = 0.0; ion.linear_damp = 2.0; ion.axis_lock_linear_y = true; ion.axis_lock_angular_x = true; ion.axis_lock_angular_z = true
		var angulo = randf() * TAU; var distancia = randf_range(15.0, 250.0); ion.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		var simbolo = GestorQuimico.extraer_atomo_cuantico(); var visual = _crear_atomo_visual(simbolo, 0.6); ion.add_child(visual)
		var col = CollisionShape3D.new(); col.shape = SphereShape3D.new(); col.shape.radius = 0.7; ion.add_child(col)
		ion.set_meta("es_nutriente", true); ion.set_meta("simbolo", simbolo); ion.set_meta("energia", GestorQuimico.TABLA_PERIODICA[simbolo]["energia"]); add_child(ion)

func _generar_radicales_libres():
	for i in range(60):
		var radical = RigidBody3D.new(); radical.gravity_scale = 0.0; radical.linear_damp = 1.0; radical.axis_lock_linear_y = true
		var angulo = randf() * TAU; var distancia = randf_range(30.0, 250.0); radical.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		var data_temp = GestorQuimico.TABLA_PERIODICA["O"].duplicate(); data_temp["rol"] = "radical"; GestorQuimico.TABLA_PERIODICA["ROS"] = data_temp 
		var visual = _crear_atomo_visual("ROS", 0.8)
		var t = create_tween().set_loops(); t.tween_property(visual, "scale", Vector3(1.2, 1.2, 1.2), 0.2); t.tween_property(visual, "scale", Vector3(0.8, 0.8, 0.8), 0.2); radical.add_child(visual)
		var col = CollisionShape3D.new(); col.shape = SphereShape3D.new(); col.shape.radius = 0.9; radical.add_child(col)
		radical.set_meta("es_enemigo", true); radical.apply_central_impulse(Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized() * 50.0); add_child(radical)

func _on_molecula_choca(body: Node):
	if not juego_activo: return
	if body.has_meta("es_nutriente"):
		var simbolo = body.get_meta("simbolo"); energia_actual = min(energia_actual + body.get_meta("energia") * 5.0, energia_maxima)
		atomos_devorados.append(simbolo); call_deferred("_enlazar_nuevo_atomo", simbolo, true)
		var tween = create_tween(); tween.tween_property(body, "scale", Vector3.ZERO, 0.1); tween.tween_callback(body.queue_free)
		stats_actuales["radio_colision"] += 0.4; _actualizar_ui()
		if atomos_devorados.size() >= umbral_saturacion_dinamico: _ejecutar_replicacion_autocatalitica()
	elif body.has_meta("es_enemigo"):
		energia_actual -= 120.0 
		var luz = jugador_molecula.get_child(0) as OmniLight3D
		if luz:
			var color_orig = luz.light_color; luz.light_color = Color(1.0, 0.0, 0.0)
			get_tree().create_timer(0.3).timeout.connect(func(): luz.light_color = color_orig)
		var dir_empuje = (jugador_molecula.global_position - body.global_position).normalized()
		jugador_molecula.apply_central_impulse(dir_empuje * 200.0); body.queue_free(); _actualizar_ui()

func _physics_process(delta):
	if not is_instance_valid(jugador_molecula) or not juego_activo: return
	pivot_camara.position = pivot_camara.position.lerp(Vector3(jugador_molecula.position.x, 0, jugador_molecula.position.z), delta * 5.0)
	
	# ZOOM ESTRECHO Y CLAUSTROFÓBICO (+12.0 en vez de +25.0)
	camara.position.y = lerp(camara.position.y, stats_actuales["radio_colision"] * 2.0 + 12.0, delta * 2.0)
	
	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	
	var mov_3d = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized(); mov_3d = Vector3(input_dir.x, 0, input_dir.y)
		var fuerza_base = stats_actuales["velocidad"] * 3.0
		if Input.is_physical_key_pressed(KEY_SPACE) and "ADAPTABILIDAD_CUÁNTICA" in stats_actuales["poderes"]:
			if energia_actual > 20.0: fuerza_base *= 8.0; energia_actual -= delta * 150.0 
		var fuerza = mov_3d * fuerza_base; jugador_molecula.apply_central_force(fuerza)
		var angulo_objetivo = atan2(mov_3d.x, mov_3d.z); jugador_molecula.rotation.y = lerp_angle(jugador_molecula.rotation.y, angulo_objetivo, delta * 5.0)

	var ruido_browniano = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 15.0
	jugador_molecula.apply_central_force(ruido_browniano)

	energia_actual -= delta * entropia_tasa; _actualizar_ui()
	if energia_actual <= 0:
		juego_activo = false; ui_texto.text = "ENTROPÍA TOTAL.\nHas sufrido muerte térmica. Enlaces colapsados..."
		ui_texto.modulate = Color(1.0, 0.2, 0.2); await get_tree().create_timer(3.0).timeout; get_tree().reload_current_scene() 

# ¡AQUÍ ESTÁ LA TRANSICIÓN PERFECTA!
func _ejecutar_replicacion_autocatalitica():
	juego_activo = false
	ui_texto.text = "¡SITUACIÓN DE SATURACIÓN ALCANZADA!\nCatalizando duplicación de cadena helicoidal..."
	ui_texto.modulate = Color(0.2, 1.0, 0.5)
	
	var clon_visual = jugador_molecula.duplicate(); clon_visual.position.z += 4.0; add_child(clon_visual)
	var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(clon_visual, "position:x", jugador_molecula.position.x + 10.0, 2.0); t.parallel().tween_property(jugador_molecula, "position:x", jugador_molecula.position.x - 10.0, 2.0)
	
	await get_tree().create_timer(4.0).timeout
	
	var gen_base = GestorQuimico.mazo_genetico[-1]["secuencia"].duplicate()
	gen_base.append_array(atomos_devorados)
	GestorQuimico.mazo_genetico[-1]["secuencia"] = gen_base
	
	GestorQuimico.fase_evolutiva_actual = 2
	GestorQuimico.transicionar_escena(0) # Va a la escena de la Mesa, pero la Era es la 2

func _construir_ui():
	var canvas = CanvasLayer.new(); ui_texto = Label.new(); ui_texto.	position = Vector2(20, 20); ui_texto.add_theme_font_size_override("font_size", 22); ui_texto.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8)); canvas.add_child(ui_texto); add_child(canvas)

func _actualizar_ui():
	var text = "MATRIZ DE POLIMERIZACIÓN (Mundo de ARN)\n"
	text += "Energía Libre (∆G): " + str(int(energia_actual)) + " / " + str(int(energia_maxima)) + "\n"
	text += "Monómeros Enlazados: " + str(atomos_devorados.size()) + " / " + str(umbral_saturacion_dinamico) + "\n"
	if "ADAPTABILIDAD_CUÁNTICA" in stats_actuales["poderes"]: text += "[ESPACIO] Salto Relativista.\n"
	text += "[WASD] Navegar fluido. Esquiva Daño Oxidativo."
	ui_texto.text = text
