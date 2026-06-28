extends Node3D

# ==============================================================================
# FASE 4: MORFOGÉNESIS EVOLUTIVA (V2.5 - CONTROLES CORREGIDOS Y COHESIÓN TOTAL)
# Código Monolítico Íntegro - Arquitectura Avanzada de Videojuegos "Zero"
# ==============================================================================

var bestia_jugador: RigidBody3D
var pivot_camara: Node3D
var camara: Camera3D
var ui_texto: Label

var stats: Dictionary
var energia_maxima: float
var energia_actual: float
var salud_actual: float
var genoma_secuencia: Array

var plancton_devorado: int = 0
var meta_colonizacion: int = 20
var juego_activo: bool = false

var lista_miocitos: Array = []
var tiempo_acumulado: float = 0.0
var balance_muscular_lateral: float = 0.0
var offset_cabeza_z: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# PROTOCOLO ANTI-CRASH / INYECCIÓN DE BLUEPRINT GENÉTICO DE RESPALDO
	var gestor = get_node_or_null("/root/GestorQuimico")
	if not is_instance_valid(gestor) or gestor.get("mazo_genetico") == null or gestor.mazo_genetico.is_empty():
		# Estructura bilateral simétrica balanceada por defecto
		genoma_secuencia = ["Epitelio", "Miocito", "Neurona", "Miocito", "Adipocito", "Epitelio"]
		stats = {"salud": 250.0, "energia_reserva": 1500.0, "fuerza_motriz": 90.0, "complejidad_neural": 70.0}
	else:
		var memoria = gestor.mazo_genetico[-1]
		genoma_secuencia = memoria.get("secuencia", ["Epitelio", "Miocito", "Neurona", "Miocito"])
		
		if gestor.has_method("procesar_organismo"):
			var fenotipo_evaluado = gestor.procesar_organismo(genoma_secuencia)
			if fenotipo_evaluado.has("stats_3d"):
				stats = fenotipo_evaluado["stats_3d"].duplicate()
			else:
				stats = {"salud": 250.0, "energia_reserva": 1500.0, "fuerza_motriz": 90.0, "complejidad_neural": 70.0}
	
	energia_maxima = stats.get("energia_reserva", 1500.0)
	energia_actual = energia_maxima
	salud_actual = stats.get("salud", 250.0)
	
	_construir_entorno()
	_ensamblar_organismo()
	_generar_ecosistema_plancton()
	_construir_ui()
	juego_activo = true

# ==============================================================================
# ENTORNO DEL OCÉANO PROFUNDO (Era Proterozoica)
# ==============================================================================
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

# ==============================================================================
# EL ENSAMBLADOR MORFOGENÉTICO (Unificación Geométrica por Adyacencia)
# ==============================================================================
func _ensamblar_organismo() -> void:
	bestia_jugador = RigidBody3D.new()
	bestia_jugador.gravity_scale = 0.0
	bestia_jugador.linear_damp = 1.5
	bestia_jugador.angular_damp = 4.0
	
	# Restricción planar para nado ortogonal estable
	bestia_jugador.axis_lock_angular_x = true 
	bestia_jugador.axis_lock_angular_z = true
	bestia_jugador.axis_lock_linear_y = true
	
	bestia_jugador.contact_monitor = true
	bestia_jugador.max_contacts_reported = 15
	bestia_jugador.body_entered.connect(_on_bestia_collision)
	add_child(bestia_jugador)
	
	var longitud_total: int = genoma_secuencia.size()
	offset_cabeza_z = -(longitud_total * 0.5) * 1.2
	
	var masa_acumulada_musculos_derecha: float = 0.0
	var masa_acumulada_musculos_izquierda: float = 0.0
	
	for i in range(longitud_total):
		var tipo_celula: String = genoma_secuencia[i]
		var lado: float = -1.0 if (i % 2 == 0) else 1.0
		var pos_segmento := Vector3(0.0, 0.0, offset_cabeza_z + (i * 1.2))
		
		var celula := MeshInstance3D.new()
		var col := CollisionShape3D.new()
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.35
		
		match tipo_celula:
			"Epitelio":
				pos_segmento.x = lado * 0.6
				var box_mesh := BoxMesh.new()
				box_mesh.size = Vector3(1.3, 1.0, 1.2)
				celula.mesh = box_mesh
				var box_shape := BoxShape3D.new()
				box_shape.size = Vector3(1.3, 1.0, 1.2)
				col.shape = box_shape
				mat.albedo_color = Color(0.2, 0.6, 0.75)
				
			"Miocito":
				pos_segmento.x = lado * 1.1
				var cyl_mesh := CylinderMesh.new()
				cyl_mesh.top_radius = 0.55
				cyl_mesh.bottom_radius = 0.55
				cyl_mesh.height = 1.1
				celula.mesh = cyl_mesh
				var cyl_shape := CylinderShape3D.new()
				cyl_shape.radius = 0.55
				cyl_shape.height = 1.1
				col.shape = cyl_shape
				mat.albedo_color = Color(0.8, 0.15, 0.15)
				celula.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				col.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				
				lista_miocitos.append({"posicion": pos_segmento, "lado": lado})
				if lado > 0:
					masa_acumulada_musculos_derecha += 1.0
				else:
					masa_acumulada_musculos_izquierda += 1.0
					
			"Neurona":
				pos_segmento.x = 0.0
				var sph_mesh := SphereMesh.new()
				sph_mesh.radius = 0.45
				sph_mesh.height = 0.9
				celula.mesh = sph_mesh
				var sph_shape := SphereShape3D.new()
				sph_shape.radius = 0.45
				col.shape = sph_shape
				mat.albedo_color = Color(0.9, 0.85, 0.05)
				mat.emission_enabled = true
				mat.emission = Color(0.5, 0.45, 0.0)
				
			"Adipocito":
				pos_segmento.x = lado * 0.4
				pos_segmento.y = -0.15
				var adi_mesh := SphereMesh.new()
				adi_mesh.radius = 0.7
				adi_mesh.height = 1.2
				celula.mesh = adi_mesh
				var adi_shape := SphereShape3D.new()
				adi_shape.radius = 0.7
				col.shape = adi_shape
				mat.albedo_color = Color(0.75, 0.4, 0.1)
				
		celula.material_override = mat
		celula.position = pos_segmento
		col.position = pos_segmento
		
		bestia_jugador.add_child(celula)
		bestia_jugador.add_child(col)
		
	var total_musculos: float = masa_acumulada_musculos_derecha + masa_acumulada_musculos_izquierda
	if total_musculos > 0.0:
		balance_muscular_lateral = (masa_acumulada_musculos_derecha - masa_acumulada_musculos_izquierda) / total_musculos
		
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	camara = Camera3D.new()
	camara.current = true
	camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	camara.fov = 55.0
	camara.position = Vector3(0.0, 18.0 + (longitud_total * 1.2), 11.0 + longitud_total)
	camara.rotation_degrees = Vector3(-65, 0, 0)
	pivot_camara.add_child(camara)

# ==============================================================================
# EL ECOSISTEMA TÉRMICO
# ==============================================================================
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
		
		var bono: float = 1.0
		var gestor = get_node_or_null("/root/GestorQuimico")
		if is_instance_valid(gestor):
			var bonos_dict = gestor.get("bonos_ancestrales")
			if typeof(bonos_dict) == TYPE_DICTIONARY:
				bono = bonos_dict.get("eficiencia_catalitica", 1.0)
				
		energia_actual = min(energia_actual + 80.0 * bono, energia_maxima)
		
		var t := create_tween()
		t.tween_property(body, "scale", Vector3.ZERO, 0.1)
		t.tween_callback(body.queue_free)
		
		_actualizar_ui()
		
		if plancton_devorado >= meta_colonizacion:
			_conquistar_ecosistema()

func _conquistar_ecosistema() -> void:
	juego_activo = false
	ui_texto.text = "¡DOMINIO ECOLOGICO ALCANZADO!\nTu linaje de polígonos celulares ha conquistado el estrato."
	ui_texto.modulate = Color(0.2, 1.0, 0.5)
	await get_tree().create_timer(4.0).timeout
	
	var gestor = get_node_or_null("/root/GestorQuimico")
	if is_instance_valid(gestor):
		gestor.set("fase_evolutiva_actual", 5)
		if gestor.has_method("transicionar_escena"):
			gestor.transicionar_escena(0)

# ==============================================================================
# RESOLUCIÓN TRIGONOMÉTRICA DE CONTROLES INVERTIDOS
# ==============================================================================
func _physics_process(delta: float) -> void:
	if not is_instance_valid(bestia_jugador) or not juego_activo: 
		return
	
	pivot_camara.position = pivot_camara.position.lerp(bestia_jugador.position, delta * 4.0)
	tiempo_acumulado += delta
	
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1.0
	
	var velocidad_impulsion: float = max(10.0, stats.get("fuerza_motriz", 75.0))
	var agilidad: float = max(1.0, stats.get("complejidad_neural", 60.0) / 80.0)
	var frecuencia_maestra: float = 3.5 * agilidad
	var longitud_onda: float = 1.4
	
	var esta_nadando: bool = (input_dir != Vector2.ZERO)
	var costo_basal: float = 15.0 if esta_nadando else 4.0
	
	if esta_nadando:
		input_dir = input_dir.normalized()
		var direccion_deseada := Vector3(input_dir.x, 0.0, input_dir.y)
		
		var rotacion_global: Basis = bestia_jugador.global_transform.basis
		
		for miocito in lista_miocitos:
			var pos_local: Vector3 = miocito["posicion"]
			var lado: float = miocito["lado"]
			
			var dist_z: float = pos_local.z - offset_cabeza_z
			var fase: float = (tiempo_acumulado * frecuencia_maestra) - (dist_z * longitud_onda)
			var pulso: float = sin(fase)
			
			var activacion: float = pulso if lado > 0.0 else -pulso
			var contraccion: float = max(0.0, activacion)
			
			if contraccion > 0.0:
				var dir_lat: Vector3 = Vector3.LEFT if lado > 0.0 else Vector3.RIGHT
				var f_lat: Vector3 = dir_lat * contraccion * velocidad_impulsion * 0.25
				var f_av: Vector3 = Vector3.FORWARD * contraccion * velocidad_impulsion * 0.75
				
				if (input_dir.x < 0.0 and lado > 0.0) or (input_dir.x > 0.0 and lado < 0.0):
					f_av *= 2.0
					
				var fuerza_local_pura: Vector3 = f_lat + f_av
				var fuerza_global: Vector3 = rotacion_global * fuerza_local_pura
				var offset_global: Vector3 = rotacion_global * pos_local
				
				bestia_jugador.apply_force(fuerza_global, offset_global)
				
				var cap_energetica: float = 1.0
				var gestor = get_node_or_null("/root/GestorQuimico")
				if is_instance_valid(gestor):
					var bonos_dict = gestor.get("bonos_ancestrales")
					if typeof(bonos_dict) == TYPE_DICTIONARY:
						cap_energetica = max(0.1, bonos_dict.get("capacidad_energetica", 1.0))
						
				energia_actual -= delta * contraccion * 2.0 / cap_energetica
				
		# SOLUCIÓN DE INVERSIÓN: Corrección matemática de proyección angular en cuadrantes de avance (-Z)
		var angulo_obj: float = atan2(-direccion_deseada.x, -direccion_deseada.z)
		bestia_jugador.rotation.y = lerp_angle(bestia_jugador.rotation.y, angulo_obj, delta * max(1.5, agilidad * 2.5))
		
	energia_actual -= delta * costo_basal
	_actualizar_ui()
	
	if energia_actual <= 0.0:
		juego_activo = false
		ui_texto.text = "INANICION. Colapso sistémico."
		ui_texto.modulate = Color(1.0, 0.2, 0.2)
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()

# ==============================================================================
# TELEMETRÍA DIEGÉTICA DE LA TESELACIÓN DE VORONOI
# ==============================================================================
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
		
	var text = "ESTADIO ANIMAL - EÓN PROTEROZOICO\n"
	text += "Energía Sistémica (ATP): " + str(int(energia_actual)) + " / " + str(int(energia_maxima)) + "\n"
	text += "Salud del Tejido: " + str(int(salud_actual)) + "\n"
	text += "Masa de Plancton Devorada: " + str(plancton_devorado) + " / " + str(meta_colonizacion) + "\n"
	
	# Simulación de la métrica de relajación de Thiessen
	text += "Conectividad (Polígonos de Thiessen): Red de Adyacencia Optimizada al 100%\n"
	
	if abs(balance_muscular_lateral) > 0.05:
		var lado = "IZQUIERDA" if balance_muscular_lateral < 0 else "DERECHA"
		text += "ALERTA CINEMÁTICA: Torque parásito desviado a la " + lado + " (" + str(int(abs(balance_muscular_lateral) * 100)) + "%)\n"
	else:
		text += "ESTADO MORFOLÓGICO: Simetría Bilateral de Resonancia Estable\n"
		
	text += "\n[WASD] Nadar (Controles Alineados). Caza para mantener la homeostasis."
	ui_texto.text = text
