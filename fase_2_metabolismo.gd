extends Node3D

var celula_jugador: RigidBody3D
var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label

var stats: Dictionary
var energia_libre: float = 1000.0
var energia_maxima: float = 1000.0 
var genoma_secuencia: Array

var vesiculas_absorbidas: int = 0
var meta_conjugacion: int = 8
var juego_activo: bool = false
var meta_lipidos_alcanzada: bool = false
var visual_membrana: MeshInstance3D

var lista_bacterias_rojas: Array = []

const SHADER_MEMBRANA = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;
uniform vec4 albedo_color : source_color = vec4(0.2, 0.7, 0.5, 0.4);
void vertex() {
	VERTEX += NORMAL * sin(VERTEX.x * 4.0 + TIME * 3.0) * 0.08;
}
void fragment() {
	float fresnel = sqrt(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	ALBEDO = albedo_color.rgb;
	// Transparencia dinámica en el centro para ver los organelos, denso en bordes
	ALPHA = (albedo_color.a * 0.3) + (fresnel * 0.6); 
	EMISSION = albedo_color.rgb * fresnel * 2.0;
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if GestorQuimico.mazo_genetico.is_empty():
		return
		
	var genoma = GestorQuimico.mazo_genetico[-1]
	stats = genoma["fenotipo"]["stats_3d"].duplicate()
	genoma_secuencia = genoma["secuencia"]
	
	energia_maxima = max(float(stats.get("masa_celular", 50.0)) * 100.0, 1000.0)
	energia_libre = energia_maxima
	
	_construir_entorno()
	_construir_protocelula()
	_generar_anillo_lipidos()
	
	# Ecosistema completo de la Fase 2 original
	_generar_vesiculas_nutrientes(60)
	_generar_enjambre_bacterias_rojas(15)
	
	_construir_ui()
	juego_activo = true

func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.01, 0.01)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.glow_enabled = true
	env.glow_intensity = 2.5
	
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-90, 0, 0)
	luz.light_energy = 0.2
	add_child(luz)

func _construir_protocelula() -> void:
	celula_jugador = RigidBody3D.new()
	celula_jugador.gravity_scale = 0.0
	celula_jugador.linear_damp = 3.0
	celula_jugador.axis_lock_linear_y = true
	celula_jugador.axis_lock_angular_x = true
	celula_jugador.axis_lock_angular_z = true
	celula_jugador.contact_monitor = true
	celula_jugador.max_contacts_reported = 10
	celula_jugador.body_entered.connect(_on_cell_collision)
	add_child(celula_jugador)
	
	# MEMBRANA TRANSLÚCIDA (Invisible hasta hallar el anillo)
	var radio: float = float(stats.get("radio_celular", 1.5))
	visual_membrana = MeshInstance3D.new()
	visual_membrana.mesh = SphereMesh.new()
	visual_membrana.mesh.radius = radio
	visual_membrana.mesh.height = radio * 2.0
	
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_MEMBRANA
	mat.shader = sh
	mat.set_shader_parameter("albedo_color", Color(0.0, 0.0, 0.0, 0.0))
	visual_membrana.material_override = mat
	celula_jugador.add_child(visual_membrana)
	
	var col := CollisionShape3D.new()
	var col_shape := SphereShape3D.new()
	col_shape.radius = radio
	col.shape = col_shape
	celula_jugador.add_child(col)
	
	# NÚCLEO INTERNO DE LA FASE 1
	var nucleo := MeshInstance3D.new()
	nucleo.mesh = SphereMesh.new()
	nucleo.mesh.radius = radio * 0.4
	nucleo.mesh.height = radio * 0.8
	var mat_nuc := StandardMaterial3D.new()
	mat_nuc.albedo_color = Color(0.2, 0.8, 1.0)
	mat_nuc.emission_enabled = true
	mat_nuc.emission = Color(0.2, 0.8, 1.0)
	nucleo.material_override = mat_nuc
	celula_jugador.add_child(nucleo)
	
	# APÉNDICES (Flagelos)
	var conteo_peptidos: int = 0
	for macro in genoma_secuencia: 
		if str(macro) == "Péptido": conteo_peptidos += 1
		
	for i in range(conteo_peptidos):
		var flagelo := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.0
		cyl.height = 2.0
		flagelo.mesh = cyl
		var mat_f := StandardMaterial3D.new()
		mat_f.albedo_color = Color(0.8, 0.3, 0.3)
		flagelo.material_override = mat_f
		var angulo: float = (TAU / float(max(1, conteo_peptidos))) * float(i)
		flagelo.position = Vector3(cos(angulo) * radio, 0, sin(angulo) * radio)
		celula_jugador.add_child(flagelo)
	
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	camara = Camera3D.new()
	camara.current = true
	camara.position = Vector3(0, 40.0, 12.0)
	camara.rotation_degrees = Vector3(-75, 0, 0)
	pivot_camara.add_child(camara)

func _generar_anillo_lipidos() -> void:
	var anillo = RigidBody3D.new()
	anillo.gravity_scale = 0.0
	anillo.axis_lock_linear_y = true
	
	var angulo = randf() * TAU
	var distancia = randf_range(30.0, 60.0)
	anillo.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
	
	var mesh = MeshInstance3D.new()
	mesh.mesh = TorusMesh.new()
	mesh.mesh.inner_radius = 4.0
	mesh.mesh.outer_radius = 5.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.2)
	mesh.material_override = mat
	anillo.add_child(mesh)
	
	var col = CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 5.5
	anillo.add_child(col)
	
	anillo.set_meta("es_anillo", true)
	add_child(anillo)

func _generar_vesiculas_nutrientes(cantidad: int) -> void:
	for i in range(cantidad):
		_instanciar_una_vesicula()

func _instanciar_una_vesicula() -> void:
	var v := RigidBody3D.new()
	v.gravity_scale = 0.0
	v.axis_lock_linear_y = true
	v.linear_damp = 1.0
	
	var ang: float = randf() * TAU
	var d: float = randf_range(40.0, 200.0)
	v.position = Vector3(cos(ang)*d, 0, sin(ang)*d)
	
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	mesh.mesh = sph
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3)
	mesh.material_override = mat
	v.add_child(mesh)
	
	var col := CollisionShape3D.new()
	var c_shape := SphereShape3D.new()
	c_shape.radius = 0.6
	col.shape = c_shape
	v.add_child(col)
	
	v.set_meta("es_vesicula", true)
	add_child(v)

func _generar_enjambre_bacterias_rojas(cantidad: int) -> void:
	for i in range(cantidad):
		var rival := RigidBody3D.new()
		rival.gravity_scale = 0.0
		rival.axis_lock_linear_y = true
		rival.linear_damp = 2.0
		
		var ang: float = randf() * TAU
		var d: float = randf_range(50.0, 250.0)
		rival.position = Vector3(cos(ang)*d, 0, sin(ang)*d)
		
		var mesh := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 2.5
		sph.height = 5.0
		mesh.mesh = sph
		
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER_MEMBRANA
		mat.shader = sh
		mat.set_shader_parameter("albedo_color", Color(1.0, 0.2, 0.1, 0.6))
		mesh.material_override = mat
		rival.add_child(mesh)
		
		var col := CollisionShape3D.new()
		var c_shape := SphereShape3D.new()
		c_shape.radius = 2.5
		col.shape = c_shape
		rival.add_child(col)
		
		rival.set_meta("es_conjugador", true)
		add_child(rival)
		lista_bacterias_rojas.append(rival)

func _on_cell_collision(body: Node) -> void:
	if not juego_activo: 
		return
		
	if body.has_meta("es_anillo") and not meta_lipidos_alcanzada:
		meta_lipidos_alcanzada = true
		body.queue_free()
		
		var mat = visual_membrana.material_override as ShaderMaterial
		var t = create_tween()
		t.tween_method(func(val): mat.set_shader_parameter("albedo_color", val), Color(0.0,0.0,0.0,0.0), Color(0.2, 0.7, 0.5, 0.8), 2.0)
		energia_libre = energia_maxima
		
	elif body.has_meta("es_vesicula") and meta_lipidos_alcanzada:
		vesiculas_absorbidas += 1
		energia_libre = min(energia_libre + 150.0, energia_maxima)
		body.queue_free()
		call_deferred("_instanciar_una_vesicula")
		_actualizar_ui()
		
	elif body.has_meta("es_conjugador") and meta_lipidos_alcanzada:
		if vesiculas_absorbidas >= meta_conjugacion:
			_intercambio_adn_exitoso(body)
		else:
			var rival_3d: Node3D = body as Node3D
			if rival_3d != null:
				var dir: Vector3 = (celula_jugador.global_position - rival_3d.global_position).normalized()
				celula_jugador.apply_central_impulse(dir * 60.0)

func _intercambio_adn_exitoso(rival: Node) -> void:
	juego_activo = false
	ui_texto.text = "¡CONJUGACIÓN INICIADA!\nBuscando afinidad electromagnética..."
	ui_texto.modulate = Color(0.6, 0.2, 1.0)
	
	if rival.get_child_count() > 0:
		var visual = rival.get_child(0)
		if visual is Node3D:
			var t := create_tween()
			t.tween_property(visual, "scale", Vector3.ZERO, 1.5)
			
	await get_tree().create_timer(2.0).timeout
	GestorQuimico.transicionar_escena(3)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(celula_jugador) or not juego_activo: 
		return
		
	for bacteria in lista_bacterias_rojas:
		if is_instance_valid(bacteria) and bacteria is RigidBody3D:
			var ruido := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			(bacteria as RigidBody3D).apply_central_force(ruido * 40.0)
			
	pivot_camara.position = pivot_camara.position.lerp(celula_jugador.position, delta * 5.0)
	
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1.0
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var mov_3d := Vector3(input_dir.x, 0.0, input_dir.y)
		var vel_ciliar: float = float(stats.get("velocidad_ciliar", 30.0))
		celula_jugador.apply_central_force(mov_3d * vel_ciliar * 3.0)
		celula_jugador.rotation.y = lerp_angle(celula_jugador.rotation.y, atan2(mov_3d.x, mov_3d.z), delta * 5.0)
	
	# Drenaje brutal si el polímero está desnudo
	energia_libre -= delta * (12.0 if meta_lipidos_alcanzada else 40.0)
	_actualizar_ui()
	
	if energia_libre <= 0.0:
		juego_activo = false
		ui_texto.text = "LISIS OSMÓTICA. Membrana destruida."
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func _construir_ui() -> void:
	var canvas := CanvasLayer.new()
	ui_texto = Label.new()
	ui_texto.position = Vector2(20, 20)
	ui_texto.add_theme_font_size_override("font_size", 22)
	ui_texto.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
	canvas.add_child(ui_texto)
	add_child(canvas)

func _actualizar_ui() -> void:
	if not is_instance_valid(ui_texto): return
	var text: String = "ESTADIO CELULAR - ERA DE LUCA\n"
	text += "Energía Termodinámica (∆G): " + str(int(energia_libre)) + " / " + str(int(energia_maxima)) + "\n"
	text += "Vesículas Fagocitadas: " + str(vesiculas_absorbidas) + " / " + str(meta_conjugacion) + "\n"
	
	if not meta_lipidos_alcanzada:
		text += "\n[ALERTA CRÍTICA] ¡ENCUENTRA EL ANILLO DE LÍPIDOS PARA SELLAR TU MEMBRANA!"
		ui_texto.modulate = Color(1.0, 0.2, 0.2)
	else:
		if vesiculas_absorbidas >= meta_conjugacion: 
			text += "\nMasa Crítica. Impacta una Bacteria Roja para conjugar."
			ui_texto.modulate = Color(0.2, 1.0, 0.2)
		else:
			text += "\nCaza alimento. Las células rojas te repelerán."
			ui_texto.modulate = Color(0.8, 0.8, 0.2)
			
	ui_texto.text = text
