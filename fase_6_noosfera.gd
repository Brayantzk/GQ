extends Node3D

# ==============================================================================
# FASE 6: LA NOOSFERA - KARDASHEV TIPO I (V13.0)
# Arquitectura: Termodinámica Planetaria, Teoría de Grafos y Bucle Fractal.
# ==============================================================================

var pivot_planeta: Node3D
var planeta_visual: MeshInstance3D
var camara_orbital: Camera3D
var cursor_orbital: Node3D
var ui_texto: Label

var stats_heredados: Dictionary
var secuencia_tech: Array = []
var herramienta_actual: String = ""
var index_herramienta: int = 0

var puntos_kardashev: float = 0.0
var meta_kardashev: float = 10000.0
var entropia_actual: float = 0.0
var limite_entropia: float = 2000.0
var energia_planetaria: float = 0.0

var nodos_civiles: Array = []
var enlaces_red: Array = []

var res_entropica: float = 1.0
var proc_cuantico: float = 1.0
var juego_activo: bool = false
var radio_planeta: float = 25.0

# ------------------------------------------------------------------------------
# CLASE NODO ESTRUCTURAL (GRAFO)
# ------------------------------------------------------------------------------
class NodoCivilizacion extends Node3D:
	var tipo_nodo: String
	var calor_local: float = 0.0
	var malla: MeshInstance3D
	var material_nodo: StandardMaterial3D
	
	func inicializar(tipo: String) -> void:
		tipo_nodo = tipo
		
		malla = MeshInstance3D.new()
		var mesh_geo: Mesh
		if tipo == "Reactor de Fusión":
			mesh_geo = PrismMesh.new()
			(mesh_geo as PrismMesh).size = Vector3(1.5, 3.0, 1.5)
		elif tipo == "Mente Artificial":
			mesh_geo = BoxMesh.new()
			(mesh_geo as BoxMesh).size = Vector3(2.0, 2.0, 2.0)
		else:
			mesh_geo = BoxMesh.new()
			(mesh_geo as BoxMesh).size = Vector3(1.0, 4.0, 1.0)
			
		malla.mesh = mesh_geo
		
		material_nodo = StandardMaterial3D.new()
		if tipo == "Reactor de Fusión": material_nodo.albedo_color = Color(1.0, 0.4, 0.0)
		elif tipo == "Mente Artificial": material_nodo.albedo_color = Color(0.2, 0.8, 1.0)
		elif tipo == "Nodo Cuántico": material_nodo.albedo_color = Color(0.8, 0.2, 1.0)
		else: material_nodo.albedo_color = Color(0.6, 0.6, 0.6)
		
		material_nodo.emission_enabled = true
		material_nodo.emission = material_nodo.albedo_color
		malla.material_override = material_nodo
		
		malla.position.y = 1.0
		add_child(malla)

# ------------------------------------------------------------------------------
# INICIALIZACIÓN
# ------------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var gestor: Node = get_node_or_null("/root/GestorQuimico")
	if is_instance_valid(gestor) and not (gestor.get("mazo_genetico") as Array).is_empty():
		var mazo: Array = gestor.get("mazo_genetico") as Array
		var memoria: Dictionary = mazo[-1] as Dictionary
		stats_heredados = memoria.get("fenotipo", {}).get("stats_3d", {}).duplicate()
		secuencia_tech = memoria.get("secuencia", []).duplicate()
	else:
		stats_heredados = {"energia_reserva": 5000.0, "capacidad_procesamiento": 50.0, "resistencia_entropica": 1.0}
		secuencia_tech = ["Reactor de Fusión", "Nodo Cuántico", "Mente Artificial", "Escudo Planetario"]
		
	energia_planetaria = float(stats_heredados.get("energia_reserva", 2000.0))
	proc_cuantico = max(1.0, float(stats_heredados.get("capacidad_procesamiento", 10.0)) / 10.0)
	res_entropica = float(stats_heredados.get("resistencia_entropica", 1.0))
	
	# Filtrar solo tecnologías válidas de la secuencia
	var valid_techs: Array = []
	for tech in secuencia_tech:
		if str(tech) in ["Reactor de Fusión", "Nodo Cuántico", "Mente Artificial", "Escudo Planetario"]:
			valid_techs.append(str(tech))
	if valid_techs.is_empty():
		valid_techs = ["Reactor de Fusión", "Nodo Cuántico"]
		
	secuencia_tech = valid_techs
	herramienta_actual = str(secuencia_tech[0])
	
	_construir_entorno()
	_construir_planeta()
	_construir_cursor()
	_construir_ui()
	juego_activo = true

func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.0, 0.02)
	env.glow_enabled = true
	env.glow_intensity = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-30, 150, 0)
	sol.light_energy = 1.0
	add_child(sol)

func _construir_planeta() -> void:
	pivot_planeta = Node3D.new()
	add_child(pivot_planeta)
	
	planeta_visual = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radio_planeta
	mesh.height = radio_planeta * 2.0
	mesh.radial_segments = 64
	mesh.rings = 32
	planeta_visual.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.1, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.02, 0.05)
	mat.roughness = 0.8
	planeta_visual.material_override = mat
	pivot_planeta.add_child(planeta_visual)
	
	camara_orbital = Camera3D.new()
	camara_orbital.current = true
	camara_orbital.position = Vector3(0, 0, radio_planeta * 2.5)
	add_child(camara_orbital)

func _construir_cursor() -> void:
	cursor_orbital = Node3D.new()
	var anillo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.8
	anillo.mesh = torus
	
	var mat_anillo := StandardMaterial3D.new()
	mat_anillo.albedo_color = Color(0.0, 1.0, 0.8)
	mat_anillo.emission_enabled = true
	mat_anillo.emission = Color(0.0, 1.0, 0.8)
	anillo.material_override = mat_anillo
	anillo.rotation_degrees.x = 90.0
	cursor_orbital.add_child(anillo)
	add_child(cursor_orbital)

func _physics_process(delta: float) -> void:
	if not juego_activo: return
	
	# Rotación Cinemática del Planeta
	var in_x: float = 0.0
	var in_y: float = 0.0
	if Input.is_physical_key_pressed(KEY_A): in_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): in_x += 1.0
	if Input.is_physical_key_pressed(KEY_W): in_y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): in_y += 1.0
	
	pivot_planeta.rotate_y(in_x * delta * 1.5)
	pivot_planeta.rotate_x(in_y * delta * 1.5)
	
	# Raycast implícito usando el centro de la pantalla
	var dir_camara: Vector3 = -camara_orbital.global_transform.basis.z
	var pos_superficie_global: Vector3 = camara_orbital.global_position + (dir_camara * (radio_planeta * 1.5))
	
	cursor_orbital.position = pos_superficie_global
	if pos_superficie_global.length_squared() > 0.01:
		cursor_orbital.look_at(Vector3.ZERO, Vector3.UP)
		
	if Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE):
		_construir_nodo(cursor_orbital.position)
		
	_procesar_algoritmo_termodinamico(delta)
	_actualizar_ui()
	_verificar_condiciones()

func _input(event: InputEvent) -> void:
	if not juego_activo: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		index_herramienta = (index_herramienta + 1) % secuencia_tech.size()
		herramienta_actual = str(secuencia_tech[index_herramienta])

func _construir_nodo(pos_global: Vector3) -> void:
	var costo: float = 500.0
	if herramienta_actual == "Reactor de Fusión": costo = 200.0
	
	if energia_planetaria < costo: return
	energia_planetaria -= costo
	
	var nodo := NodoCivilizacion.new()
	nodo.inicializar(herramienta_actual)
	
	# Transformación para anclarlo a la superficie rotatoria del planeta
	var pos_local: Vector3 = pivot_planeta.to_local(pos_global)
	pos_local = pos_local.normalized() * radio_planeta
	nodo.position = pos_local
	
	# Orientar nodo hacia afuera de la esfera
	var up_dir: Vector3 = pos_local.normalized()
	var right_dir: Vector3 = Vector3.UP.cross(up_dir).normalized()
	if right_dir.length_squared() < 0.001: right_dir = Vector3.RIGHT
	var forward_dir: Vector3 = right_dir.cross(up_dir).normalized()
	nodo.transform.basis = Basis(right_dir, up_dir, forward_dir)
	
	pivot_planeta.add_child(nodo)
	nodos_civiles.append(nodo)
	
	_generar_enlaces(nodo)

func _generar_enlaces(nodo_nuevo: NodoCivilizacion) -> void:
	for otro in nodos_civiles:
		var n: NodoCivilizacion = otro as NodoCivilizacion
		if n == nodo_nuevo: continue
		
		var dist: float = nodo_nuevo.position.distance_to(n.position)
		if dist < 12.0:
			var linea := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.2
			cyl.height = dist
			linea.mesh = cyl
			
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 1.0, 0.5, 0.5)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.2, 1.0, 0.5)
			linea.material_override = mat
			
			var mid: Vector3 = (nodo_nuevo.position + n.position) * 0.5
			linea.position = mid
			linea.look_at_from_position(mid, n.position, mid.normalized())
			linea.rotation_degrees.x += 90.0
			
			pivot_planeta.add_child(linea)
			enlaces_red.append({"n1": nodo_nuevo, "n2": n, "mesh": linea})

func _procesar_algoritmo_termodinamico(delta: float) -> void:
	entropia_actual = 0.0
	var gen_energia: float = 0.0
	var gen_kardashev: float = 0.0
	
	for obj in nodos_civiles:
		var n: NodoCivilizacion = obj as NodoCivilizacion
		
		if n.tipo_nodo == "Reactor de Fusión":
			gen_energia += 150.0 * delta
			n.calor_local += 15.0 * delta
		elif n.tipo_nodo == "Mente Artificial":
			if energia_planetaria > 20.0 * delta:
				gen_energia -= 20.0 * delta
				n.calor_local = max(0.0, n.calor_local - 30.0 * delta)
		elif n.tipo_nodo == "Nodo Cuántico":
			if energia_planetaria > 15.0 * delta:
				gen_energia -= 15.0 * delta
				gen_kardashev += (50.0 * proc_cuantico) * delta
				n.calor_local += 5.0 * delta
		elif n.tipo_nodo == "Escudo Planetario":
			n.calor_local = max(0.0, n.calor_local - 10.0 * delta)
				
		n.calor_local += 4.0 * delta # Entropía basal por existir en el universo
		entropia_actual += n.calor_local
		
		var heat_ratio: float = clampf(n.calor_local / 100.0, 0.0, 1.0)
		n.material_nodo.emission = n.material_nodo.albedo_color.lerp(Color(1.0, 0.0, 0.0), heat_ratio)
		
	# Difusión de Calor por la Red (Teoría de Grafos)
	for link in enlaces_red:
		var d: Dictionary = link as Dictionary
		var n1: NodoCivilizacion = d["n1"] as NodoCivilizacion
		var n2: NodoCivilizacion = d["n2"] as NodoCivilizacion
		var dif: float = (n1.calor_local - n2.calor_local) * delta * 2.0
		n1.calor_local -= dif
		n2.calor_local += dif
			
	energia_planetaria += gen_energia
	puntos_kardashev += gen_kardashev
	
	var p_ratio: float = clampf(entropia_actual / (limite_entropia * res_entropica), 0.0, 1.0)
	var mat_plan: StandardMaterial3D = planeta_visual.material_override as StandardMaterial3D
	mat_plan.emission = Color(0.0, 0.02, 0.05).lerp(Color(0.8, 0.1, 0.0), p_ratio)

func _verificar_condiciones() -> void:
	if entropia_actual >= (limite_entropia * res_entropica):
		juego_activo = false
		ui_texto.text = "COLAPSO ENTRÓPICO.\nLa civilización se extinguió bajo su propio calor (Gran Filtro)."
		ui_texto.modulate = Color(1.0, 0.2, 0.2)
		await get_tree().create_timer(4.0).timeout
		var gestor: Node = get_node_or_null("/root/GestorQuimico")
		if is_instance_valid(gestor):
			gestor.set("fase_evolutiva_actual", 5) # Vuelve al draft fase 6 para un reroll
			gestor.call("transicionar_escena", 0)
			
	elif puntos_kardashev >= meta_kardashev:
		juego_activo = false
		ui_texto.text = "¡TRASCENDENCIA KARDASHEV TIPO I ALCANZADA!\nHas lanzado la Espora Cósmica. El Bucle Fractal se cierra..."
		ui_texto.modulate = Color(0.2, 1.0, 0.8)
		
		# Animación de alejamiento para simular que la galaxia entera es solo otro átomo
		var tw := create_tween()
		tw.tween_property(camara_orbital, "position:z", 500.0, 5.0).set_trans(Tween.TRANS_EXPO)
		
		await get_tree().create_timer(5.0).timeout
		var gestor: Node = get_node_or_null("/root/GestorQuimico")
		if is_instance_valid(gestor):
			gestor.set("fase_evolutiva_actual", 1) # BUCLE CERRADO: Regresamos al Caldo Químico Primordial
			gestor.call("transicionar_escena", 1) 

func _construir_ui() -> void:
	var canvas := CanvasLayer.new()
	ui_texto = Label.new()
	ui_texto.position = Vector2(25, 25)
	ui_texto.add_theme_font_size_override("font_size", 20)
	canvas.add_child(ui_texto)
	add_child(canvas)

func _actualizar_ui() -> void:
	if not is_instance_valid(ui_texto): return
	
	var txt: String = "NOOSFERA PLANETARIA - KARDASHEV TIPO I\n"
	txt += "Energía Disponible: " + str(int(energia_planetaria)) + " TW\n"
	txt += "Trascendencia Cuántica: " + str(int(puntos_kardashev)) + " / " + str(int(meta_kardashev)) + "\n"
	txt += "Entropía Global (Calor): " + str(int(entropia_actual)) + " / " + str(int(limite_entropia * res_entropica)) + "\n\n"
	txt += "Genotipo Actual: [" + herramienta_actual + "] (Pulsa 'E' para alternar)\n"
	txt += "[WASD] Rotar Planeta | [ESPACIO] Construir Infraestructura"
		
	ui_texto.text = txt
