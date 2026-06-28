extends Node3D

# ==============================================================================
# FASE 2: PROTOCÉLULA (V5.2 - FIX DE TIPADO ESTRICTO Y ECOSISTEMA)
# Errores de inferencia eliminados. Casteo seguro garantizado.
# ==============================================================================

var celula_jugador: RigidBody3D
var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label

var stats: Dictionary
var integridad_membrana: float
var energia_libre: float = 1000.0
var energia_maxima: float = 1000.0 
var genoma_secuencia: Array

var vesiculas_absorbidas: int = 0
var meta_conjugacion: int = 8
var juego_activo: bool = false
var codex_abierto: bool = false 

var lista_bacterias_rojas: Array = []

const SHADER_MEMBRANA = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;
uniform vec4 albedo_color : source_color = vec4(0.2, 0.7, 0.5, 0.4);
void vertex() {
	VERTEX += NORMAL * sin(VERTEX.x * 4.0 + TIME * 3.0) * 0.08;
}
void fragment() {
	ALBEDO = albedo_color.rgb;
	ALPHA = albedo_color.a;
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
	EMISSION = albedo_color.rgb * fresnel * 2.5;
}
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Extracción Segura Anti-Crash
	var gestor = get_node_or_null("/root/GestorQuimico")
	if not is_instance_valid(gestor) or gestor.get("mazo_genetico") == null or gestor.mazo_genetico.is_empty():
		stats = {"velocidad_ciliar": 50.0, "integridad_membrana": 100.0, "radio_celular": 1.5, "masa_celular": 50.0}
		genoma_secuencia = ["Lípido", "Lípido", "ARN_m", "Péptido", "Péptido"]
	else:
		var genoma = gestor.mazo_genetico[-1]
		stats = genoma["fenotipo"]["stats_3d"].duplicate()
		genoma_secuencia = genoma["secuencia"]
	
	integridad_membrana = float(stats.get("integridad_membrana", 100.0))
	
	var bono_energia: float = 1.0
	if is_instance_valid(gestor) and gestor.get("bonos_ancestrales") != null:
		bono_energia = float(gestor.bonos_ancestrales.get("capacidad_energetica", 1.0))
		
	energia_maxima = max(float(stats.get("masa_celular", 50.0)) * 100.0, 1000.0) * bono_energia
	energia_libre = energia_maxima
	
	_construir_entorno()
	_construir_protocelula()
	
	# Población inicial del Ecosistema
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
	env.volumetric_fog_albedo = Color(0.01, 0.02, 0.02)
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
	
	var radio: float = float(stats.get("radio_celular", 1.5))
	var membrana := MeshInstance3D.new()
	membrana.mesh = SphereMesh.new()
	membrana.mesh.radius = radio
	membrana.mesh.height = radio * 2.0
	
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_MEMBRANA
	mat.shader = sh
	membrana.material_override = mat
	celula_jugador.add_child(membrana)
	
	var col := CollisionShape3D.new()
	var col_shape := SphereShape3D.new()
	col_shape.radius = radio
	col.shape = col_shape
	celula_jugador.add_child(col)
	
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	camara = Camera3D.new()
	camara.current = true
	camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	camara.fov = 45.0
	camara.position = Vector3(0, 40.0, 12.0)
	camara.rotation_degrees = Vector3(-75, 0, 0)
	pivot_camara.add_child(camara)
	
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

# ----------------- ECOSISTEMA DINÁMICO -----------------
func _generar_vesiculas_nutrientes(cantidad: int) -> void:
	for i in range(cantidad):
		_instanciar_una_vesicula()

func _instanciar_una_vesicula() -> void:
	var v := RigidBody3D.new()
	v.gravity_scale = 0.0
	v.axis_lock_linear_y = true
	v.linear_damp = 1.0
	
	var ang: float = randf() * TAU
	var d: float = randf_range(30.0, 200.0)
	var base_pos: Vector3 = celula_jugador.position if is_instance_valid(celula_jugador) else Vector3.ZERO
	v.position = base_pos + Vector3(cos(ang)*d, 0, sin(ang)*d)
	
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
		var base_pos: Vector3 = celula_jugador.position if is_instance_valid(celula_jugador) else Vector3.ZERO
		rival.position = base_pos + Vector3(cos(ang)*d, 0, sin(ang)*d)
		
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

# ----------------- RESOLVEDOR DE COLISIONES -----------------
func _on_cell_collision(body: Node) -> void:
	if not juego_activo: 
		return
		
	if body.has_meta("es_vesicula"):
		vesiculas_absorbidas += 1
		energia_libre = min(energia_libre + 150.0, energia_maxima)
		body.queue_free()
		
		# Mantener el equilibrio de masa: Instanciar una nueva vesícula lejos
		call_deferred("_instanciar_una_vesicula")
		
		if celula_jugador.get_child_count() > 1:
			var visual = celula_jugador.get_child(0)
			if visual is Node3D:
				visual.scale += Vector3(0.08, 0.08, 0.08)
			var collision = celula_jugador.get_child(1)
			if collision is CollisionShape3D and collision.shape is SphereShape3D:
				(collision.shape as SphereShape3D).radius += 0.08
		_actualizar_ui()
		
	elif body.has_meta("es_conjugador"):
		if vesiculas_absorbidas >= meta_conjugacion:
			_intercambio_adn_exitoso(body)
		else:
			# FIX DE TIPADO LÍNEA 249: Confirmamos que el body es Node3D y lo casteamos antes de acceder a global_position
			var rival_3d: Node3D = body as Node3D
			if rival_3d != null:
				var dir: Vector3 = (celula_jugador.global_position - rival_3d.global_position).normalized()
				celula_jugador.apply_central_impulse(dir * 60.0)
				if body is RigidBody3D:
					(body as RigidBody3D).apply_central_impulse(-dir * 60.0)

func _intercambio_adn_exitoso(rival: Node) -> void:
	juego_activo = false
	ui_texto.text = "¡CONJUGACIÓN INICIADA!\nBuscando afinidad electromagnética. Entrando al Duelo Genético..."
	ui_texto.modulate = Color(0.6, 0.2, 1.0)
	
	if rival.get_child_count() > 0:
		var visual = rival.get_child(0)
		if visual is Node3D:
			var t := create_tween()
			t.tween_property(visual, "scale", Vector3.ZERO, 1.5)
			
	await get_tree().create_timer(2.0).timeout
	
	var gestor = get_node_or_null("/root/GestorQuimico")
	if is_instance_valid(gestor):
		gestor.set("fase_evolutiva_actual", 3)
		if gestor.has_method("transicionar_escena"):
			gestor.transicionar_escena(3)

func _physics_process(delta: float) -> void:
	if codex_abierto: return
	
	# Simular movimiento browniano/nado para el enjambre de Bacterias Rojas
	for bacteria in lista_bacterias_rojas:
		if is_instance_valid(bacteria) and bacteria is RigidBody3D:
			var ruido: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			(bacteria as RigidBody3D).apply_central_force(ruido * 40.0)
	
	if not is_instance_valid(celula_jugador) or not juego_activo: 
		return
		
	pivot_camara.position = pivot_camara.position.lerp(celula_jugador.position, delta * 5.0)
	
	var input_dir: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1.0
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var mov_3d: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
		
		# FIX DE TIPADO LÍNEA 292: Conversión estricta a float en tiempo de compilación.
		var vel_ciliar: float = float(stats.get("velocidad_ciliar", 30.0))
		var fuerza: Vector3 = mov_3d * vel_ciliar * 3.0 
		
		celula_jugador.apply_central_force(fuerza)
		
		var ang_obj: float = atan2(mov_3d.x, mov_3d.z)
		celula_jugador.rotation.y = lerp_angle(celula_jugador.rotation.y, ang_obj, delta * 5.0)
	
	energia_libre -= delta * 12.0
	_actualizar_ui()
	
	if energia_libre <= 0.0:
		juego_activo = false
		ui_texto.text = "LISIS OSMÓTICA. Fallo de membrana."
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_TAB:
		_alternar_codex()

func _alternar_codex() -> void:
	codex_abierto = not codex_abierto
	var layer = get_node_or_null("CanvasCodex")
	if layer: 
		layer.queue_free()
		get_tree().paused = false 
	else:
		get_tree().paused = true 
		var cc := CanvasLayer.new()
		cc.name = "CanvasCodex"
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.02, 0.95)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.add_child(bg)
		
		var lbl := RichTextLabel.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = 50
		lbl.offset_top = 50
		lbl.offset_right = -50
		lbl.offset_bottom = -50
		lbl.text = "[center][b]CÓDEX ARCAICO - ENCICLOPEDIA[/b][/center]\n\n[b]Mecánica Actual:[/b]\nAbsorbe Vesículas Orgánicas mediante fagocitosis. Al expandir tu membrana, liberarás plásmidos que atraerán a las Bacterias Rojas para realizar la [b]Conjugación[/b] (Intercambio de ADN cooperativo).\n\n[b]Historial de Convergencia Fósil:[/b]\n"
		
		var gestor = get_node_or_null("/root/GestorQuimico")
		if is_instance_valid(gestor) and gestor.get("registro_fosil") != null:
			var fosiles: Array = gestor.get("registro_fosil") as Array
			for f in fosiles:
				var df: Dictionary = f as Dictionary
				lbl.text += "- Especie " + str(df.get("era", "")) + " | Genoma: " + str(df.get("genotipo", "")) + "\n"
				
		lbl.text += "\n\n[i]Presiona TAB para volver al fluido.[/i]"
		bg.add_child(lbl)
		add_child(cc)

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
	
	if vesiculas_absorbidas >= meta_conjugacion: 
		text += "¡ALERTA! Masa Crítica. Impacta una Bacteria Roja para conjugar.\n"
		ui_texto.modulate = Color(0.2, 1.0, 0.2)
	else:
		text += "Caza alimento. Las células rojas te repelerán.\n"
		ui_texto.modulate = Color(0.8, 0.8, 0.2)
		
	text += "\n[WASD] Navegar | [TAB] Abrir Enciclopedia (Pausa)."
	ui_texto.text = text
