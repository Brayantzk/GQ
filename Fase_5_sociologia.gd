extends Node3D

# ==============================================================================
# FASE 5: SOCIOLOGÍA CIBERNÉTICA Y ENJAMBRE FRACTAL (V12.0)
# Arquitectura: Algoritmo Boids Epigenético. Tipado Estricto Godot 4.
# ==============================================================================

var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label
var cursor_mente_colmena: Node3D

var stats_heredados: Dictionary
var poblacion_activa: Array = []
var colonias_rivales: Array = []
var biomasa_acumulada: float = 0.0
var meta_trascendencia: float = 1000.0

var juego_activo: bool = false
var tiempo_simulacion: float = 0.0

# Multiplicadores Cibernéticos basados en el Genotipo
var peso_cohesion: float = 1.0
var peso_alineacion: float = 1.0
var peso_separacion: float = 1.5
var radio_percepcion: float = 5.0
var velocidad_enjambre: float = 10.0

# ------------------------------------------------------------------------------
# CLASE ANIDADA: UNIDAD DEL ENJAMBRE (BOID)
# ------------------------------------------------------------------------------
class UnidadSimbionte extends CharacterBody3D:
	var velocidad_actual: Vector3 = Vector3.ZERO
	var velocidad_max: float = 15.0
	var fuerza_giro: float = 2.0
	var es_aliado: bool = true
	var malla_visual: MeshInstance3D
	
	func inicializar(pos_inicial: Vector3, max_vel: float, aliado: bool, color_cepa: Color) -> void:
		position = pos_inicial
		velocidad_max = max_vel
		es_aliado = aliado
		
		# Física Cinematica
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var col := CollisionShape3D.new()
		var esfer := SphereShape3D.new()
		esfer.radius = 0.5
		col.shape = esfer
		add_child(col)
		
		# Geometría Fractal (Dodecaedro aproximado/Esfera de baja resolución)
		malla_visual = MeshInstance3D.new()
		var mesh_geo := SphereMesh.new()
		mesh_geo.radial_segments = 6
		mesh_geo.rings = 3
		mesh_geo.radius = 0.6
		mesh_geo.height = 1.2
		malla_visual.mesh = mesh_geo
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color_cepa
		mat.emission_enabled = true
		mat.emission = color_cepa * 1.5
		# Material translúcido maquínico
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.7
		malla_visual.material_override = mat
		
		# Un pequeño ducto direccional para ver hacia dónde miran
		var ducto := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.2
		cyl.height = 1.0
		ducto.mesh = cyl
		var mat_ducto := StandardMaterial3D.new()
		mat_ducto.albedo_color = Color.WHITE
		ducto.material_override = mat_ducto
		ducto.rotation_degrees = Vector3(90, 0, 0)
		ducto.position = Vector3(0, 0, -0.6)
		malla_visual.add_child(ducto)
		
		add_child(malla_visual)
		velocidad_actual = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * velocidad_max

	func actualizar_boid(delta: float, boids_cercanos: Array, target_global: Vector3, pesos: Dictionary) -> void:
		var centro_masa := Vector3.ZERO
		var alinemiento_promedio := Vector3.ZERO
		var vector_separacion := Vector3.ZERO
		var total_percibidos: int = 0
		
		for otro in boids_cercanos:
			var otro_boid: UnidadSimbionte = otro as UnidadSimbionte
			if otro_boid == self or not is_instance_valid(otro_boid): 
				continue
				
			var distancia: float = global_position.distance_to(otro_boid.global_position)
			if distancia > 0.0 and distancia < pesos["radio"]:
				centro_masa += otro_boid.global_position
				alinemiento_promedio += otro_boid.velocidad_actual
				
				# Regla de Separación Crítica
				if distancia < 1.5:
					vector_separacion -= (otro_boid.global_position - global_position).normalized() / distancia
				total_percibidos += 1
				
		var fuerza_aplicada := Vector3.ZERO
		
		if total_percibidos > 0:
			centro_masa /= float(total_percibidos)
			alinemiento_promedio /= float(total_percibidos)
			
			var vector_cohesion: Vector3 = (centro_masa - global_position).normalized()
			var vector_alineacion: Vector3 = alinemiento_promedio.normalized()
			
			fuerza_aplicada += vector_cohesion * pesos["cohesion"]
			fuerza_aplicada += vector_alineacion * pesos["alineacion"]
			fuerza_aplicada += vector_separacion.normalized() * pesos["separacion"]
		
		# Regla de Objetivo (El Feromonal del Jugador)
		var direccion_target: Vector3 = (target_global - global_position).normalized()
		fuerza_aplicada += direccion_target * 2.0
		
		# Forzar movimiento planar
		fuerza_aplicada.y = 0.0
		
		velocidad_actual = velocidad_actual.lerp(velocidad_actual + fuerza_aplicada, delta * fuerza_giro)
		if velocidad_actual.length() > velocidad_max:
			velocidad_actual = velocidad_actual.normalized() * velocidad_max
			
		velocity = velocidad_actual
		move_and_slide()
		
		if velocidad_actual.length_squared() > 0.1:
			var angulo_obj: float = atan2(velocidad_actual.x, velocidad_actual.z)
			malla_visual.rotation.y = lerp_angle(malla_visual.rotation.y, angulo_obj, delta * 8.0)

# ------------------------------------------------------------------------------
# INICIALIZACIÓN Y ENTORNO
# ------------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if GestorQuimico.mazo_genetico.is_empty():
		return
		
	var memoria: Dictionary = GestorQuimico.mazo_genetico[-1]
	stats_heredados = memoria.get("fenotipo", {}).get("stats_3d", {}).duplicate()
	
	# TRADUCCIÓN CIBERNÉTICA
	# Complejidad neural dicta qué tan bien se comunica la manada
	var inteligencia: float = float(stats_heredados.get("complejidad_neural", 50.0))
	peso_cohesion = clampf(inteligencia / 50.0, 0.5, 3.0)
	peso_alineacion = clampf(inteligencia / 40.0, 0.5, 2.5)
	radio_percepcion = clampf(5.0 + (inteligencia / 20.0), 3.0, 15.0)
	velocidad_enjambre = clampf(float(stats_heredados.get("fuerza_motriz", 100.0)) / 10.0, 10.0, 30.0)
	
	_construir_entorno()
	_construir_mente_colmena()
	_instanciar_enjambre_jugador(15 + int(stats_heredados.get("energia_reserva", 100) / 100))
	_instanciar_colonias_rivales(3)
	_construir_ui()
	
	juego_activo = true

func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.05, 0.08) # Abismo Biológico
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.02, 0.1, 0.15)
	env.glow_enabled = true
	env.glow_intensity = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-70, 30, 0)
	luz.light_energy = 0.5
	add_child(luz)
	
	var sustrato := MeshInstance3D.new()
	sustrato.mesh = PlaneMesh.new()
	sustrato.mesh.size = Vector2(200, 200)
	var mat_sus := StandardMaterial3D.new()
	mat_sus.albedo_color = Color(0.01, 0.02, 0.03)
	sustrato.material_override = mat_sus
	sustrato.position.y = -5.0
	add_child(sustrato)

func _construir_mente_colmena() -> void:
	cursor_mente_colmena = Node3D.new()
	add_child(cursor_mente_colmena)
	
	# Faro Visual del Cursor
	var faro := OmniLight3D.new()
	faro.light_color = Color(0.2, 1.0, 0.5)
	faro.light_energy = 5.0
	faro.omni_range = 20.0
	cursor_mente_colmena.add_child(faro)
	
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	camara = Camera3D.new()
	camara.current = true
	camara.position = Vector3(0.0, 45.0, 20.0)
	camara.rotation_degrees = Vector3(-65, 0, 0)
	pivot_camara.add_child(camara)

func _instanciar_enjambre_jugador(cantidad: int) -> void:
	for i in range(cantidad):
		var boid := UnidadSimbionte.new()
		var radio_spawn: float = randf_range(2.0, 10.0)
		var angulo: float = randf() * TAU
		var pos_inicial := Vector3(cos(angulo) * radio_spawn, 0.0, sin(angulo) * radio_spawn)
		
		# El color de tu enjambre hereda el fenotipo visual si existiera, o verde por defecto
		boid.inicializar(pos_inicial, velocidad_enjambre, true, Color(0.2, 0.9, 0.6))
		add_child(boid)
		poblacion_activa.append(boid)

func _instanciar_colonias_rivales(cantidad_colonias: int) -> void:
	for c in range(cantidad_colonias):
		var nodo_colonia := Node3D.new()
		var angulo_col: float = randf() * TAU
		var dist_col: float = randf_range(40.0, 80.0)
		nodo_colonia.position = Vector3(cos(angulo_col) * dist_col, 0.0, sin(angulo_col) * dist_col)
		add_child(nodo_colonia)
		colonias_rivales.append(nodo_colonia)
		
		for i in range(10):
			var boid_rival := UnidadSimbionte.new()
			var pos_ini := nodo_colonia.position + Vector3(randf_range(-5,5), 0, randf_range(-5,5))
			boid_rival.inicializar(pos_ini, velocidad_enjambre * 0.7, false, Color(1.0, 0.2, 0.3))
			add_child(boid_rival)
			nodo_colonia.set_meta("boids", nodo_colonia.get_meta("boids", []) + [boid_rival])

# ------------------------------------------------------------------------------
# LÓGICA DE PROCESAMIENTO CIBERNÉTICO
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not juego_activo: 
		return
	
	tiempo_simulacion += delta
	
	# Control del Jugador (Moviendo el centro de masa objetivo / Feromona)
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1.0
	
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		var dir_mov := Vector3(input_dir.x, 0.0, input_dir.y)
		cursor_mente_colmena.position += dir_mov * (velocidad_enjambre * 1.2) * delta
		
	# Limitar fronteras
	cursor_mente_colmena.position.x = clampf(cursor_mente_colmena.position.x, -90.0, 90.0)
	cursor_mente_colmena.position.z = clampf(cursor_mente_colmena.position.z, -90.0, 90.0)
	
	pivot_camara.position = pivot_camara.position.lerp(cursor_mente_colmena.position, delta * 3.0)
	
	var params_boids: Dictionary = {
		"cohesion": peso_cohesion,
		"alineacion": peso_alineacion,
		"separacion": peso_separacion,
		"radio": radio_percepcion
	}
	
	# Actualizar Enjambre Jugador
	var a_eliminar_jugador: Array = []
	for boid in poblacion_activa:
		if not is_instance_valid(boid): continue
		boid.actualizar_boid(delta, poblacion_activa, cursor_mente_colmena.position, params_boids)
		
		# Combate y Asimilación: Revisar distancia con colonias rivales
		for col_rival in colonias_rivales:
			var boids_enemigos: Array = col_rival.get_meta("boids", []) as Array
			for b_e in boids_enemigos:
				if is_instance_valid(b_e) and is_instance_valid(boid):
					if boid.global_position.distance_to(b_e.global_position) < 1.5:
						# Cálculo de Depredación (Resuelto por Salud/Epitelio)
						var resistencia: float = float(stats_heredados.get("salud", 100.0))
						if randf() * 200.0 < resistencia:
							biomasa_acumulada += 50.0
							b_e.queue_free()
							boids_enemigos.erase(b_e)
						else:
							a_eliminar_jugador.append(boid)
							boid.queue_free()
							break
							
	for eliminado in a_eliminar_jugador:
		poblacion_activa.erase(eliminado)
		
	# Actualizar Colonias Rivales
	for col_rival in colonias_rivales:
		var boids_enemigos: Array = col_rival.get_meta("boids", []) as Array
		
		# Movimiento errático del nodo colmena enemigo
		var ruido := Vector3(sin(tiempo_simulacion + col_rival.position.x), 0, cos(tiempo_simulacion + col_rival.position.z))
		col_rival.position += ruido * delta * 5.0
		
		for b_e in boids_enemigos:
			if is_instance_valid(b_e):
				var params_rival: Dictionary = {"cohesion": 1.0, "alineacion": 1.0, "separacion": 1.5, "radio": 6.0}
				b_e.actualizar_boid(delta, boids_enemigos, col_rival.position, params_rival)
	
	_actualizar_ui()
	_verificar_condiciones()

func _verificar_condiciones() -> void:
	if poblacion_activa.is_empty():
		juego_activo = false
		ui_texto.text = "EXTINCIÓN DE LA CEPA.\nLa sociología del enjambre colapsó."
		ui_texto.modulate = Color(1.0, 0.2, 0.2)
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
		
	if biomasa_acumulada >= meta_trascendencia:
		juego_activo = false
		ui_texto.text = "¡TRASCENDENCIA BIOLÓGICA ALCANZADA!\nHas dominado la Biósfera. FIN DE LA SIMULACIÓN."
		ui_texto.modulate = Color(0.2, 1.0, 0.8)

func _construir_ui() -> void:
	var canvas := CanvasLayer.new()
	ui_texto = Label.new()
	ui_texto.position = Vector2(25, 25)
	ui_texto.add_theme_font_size_override("font_size", 22)
	ui_texto.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	canvas.add_child(ui_texto)
	add_child(canvas)

func _actualizar_ui() -> void:
	if not is_instance_valid(ui_texto): 
		return
	var text: String = "SOCIOLOGÍA CIBERNÉTICA - EÓN FANEROZOICO\n"
	text += "Unidades en Enjambre (Salud Colmena): " + str(poblacion_activa.size()) + "\n"
	text += "Biomasa Asimilada: " + str(int(biomasa_acumulada)) + " / " + str(int(meta_trascendencia)) + "\n"
	text += "Índice de Cohesión (Neuronas): " + str(snapped(peso_cohesion, 0.1)) + "x\n"
	text += "\n[WASD] Guiar Mente Colmena. Absorbe cepas rivales para trascender."
	ui_texto.text = text
