extends Node3D

# ==============================================================================
# FASE 3: EL COMPILADOR ÓNTICO (V4.0 - CONJUGACIÓN BACTERIANA)
# - Cámara orbital de libre movimiento (Estilo Card Master)
# - Tooltips Biológicos Diegéticos
# - UI 2D para diálogos (Evita textos cortados en 3D)
# ==============================================================================

var pivot_camara: Node3D
var camara: Camera3D
var luz_cenital: SpotLight3D

# Elementos de UI 2D
var ui_layer: CanvasLayer
var label_dialogo: RichTextLabel
var panel_tooltip: Panel
var label_tooltip_titulo: Label
var label_tooltip_desc: RichTextLabel
var label_sistema: Label

var mazo_jugador: Array = []
var mazo_rival: Array = []
var cartas_tablero_jugador: Array = []
var cartas_tablero_rival: Array = []

var ray_hovered: Node3D = null
var seleccionada: CartaNucleotido = null
var juego_activo: bool = false
var escribiendo: bool = false

var secuencia_objetivo_rival: Array = ["Lípido", "ARN_m", "Ribozima", "Péptido", "Lípido"]
var indice_alineacion_actual: float = 0.0

# Variables para control de cámara libre
var rotacion_camara_x: float = -45.0
var rotacion_camara_y: float = 0.0
var distancia_camara: float = 12.0
var moviendo_camara: bool = false

# DICCIONARIO DE CONOCIMIENTO BIOLÓGICO (TOOLTIPS)
const BIO_DATA = {
	"Lípido": {
		"color": Color(0.8, 0.8, 0.2),
		"desc": "Cadena de ácidos grasos hidrofóbicos. En el agua, se agrupan automáticamente.\n[color=#aaffaa]Sinergia:[/color] Se une a otro [b]Lípido[/b] para cerrar y expandir la bicapa de la membrana celular."
	},
	"ARN_m": {
		"color": Color(0.2, 0.6, 0.9),
		"desc": "Ácido Ribonucleico mensajero. Es un plano de instrucciones (código puro).\n[color=#aaffaa]Sinergia:[/color] Necesita una [b]Ribozima[/b] (máquina lectora) para traducir este plano y producir acción."
	},
	"Ribozima": {
		"color": Color(0.7, 0.2, 0.8),
		"desc": "Enzima primitiva de ARN capaz de catalizar reacciones químicas (la abuela del Ribosoma).\n[color=#aaffaa]Sinergia:[/color] Se acopla al [b]ARN_m[/b] para leerlo, o al [b]Péptido[/b] para ensamblarlo."
	},
	"Péptido": {
		"color": Color(0.9, 0.3, 0.3),
		"desc": "Cadena corta de aminoácidos. Es el ladrillo estructural básico (motor, armadura, flagelo).\n[color=#aaffaa]Sinergia:[/color] Es el producto final. Se apila sobre el [b]ARN_m[/b] para proteger la información genética."
	}
}

class CartaNucleotido extends StaticBody3D:
	var tipo_macro: String
	var es_jugador: bool
	var pos_base: Vector3
	var en_tablero: bool = false
	var malla: MeshInstance3D
	var material_inst: StandardMaterial3D
	
	func inicializar(tipo: String, pos: Vector3, propiedad_jugador: bool) -> void:
		tipo_macro = tipo
		pos_base = pos
		position = pos
		es_jugador = propiedad_jugador
		add_to_group("cartas_duelo")
		
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 0.15, 1.6)
		col.shape = box
		add_child(col)
		
		malla = MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(1.1, 0.15, 1.6)
		malla.mesh = b_mesh
		
		material_inst = StandardMaterial3D.new()
		material_inst.roughness = 0.5
		material_inst.emission_enabled = true
		material_inst.emission = Color.BLACK
		
		var c_base: Color = Color.WHITE
		# Referencia al diccionario externo de ser posible, si no, fallback
		if tipo == "Lípido": c_base = Color(0.8, 0.8, 0.2)
		elif tipo == "ARN_m": c_base = Color(0.2, 0.6, 0.9)
		elif tipo == "Ribozima": c_base = Color(0.7, 0.2, 0.8)
		elif tipo == "Péptido": c_base = Color(0.9, 0.3, 0.3)
			
		material_inst.albedo_color = c_base
		material_inst.set_meta("glow_color", c_base)
		malla.material_override = material_inst
		add_child(malla)
		
		var lbl := Label3D.new()
		lbl.text = tipo_macro
		lbl.font_size = 45
		lbl.outline_size = 8
		lbl.position = Vector3(0, 0.09, 0)
		lbl.rotation_degrees.x = -90
		add_child(lbl)

	func set_glow(active: bool) -> void:
		if en_tablero: return
		if active: 
			var gc = material_inst.get_meta("glow_color")
			if typeof(gc) == TYPE_COLOR:
				material_inst.emission = gc * 0.4
			position.y = pos_base.y + 0.2
		else: 
			material_inst.emission = Color.BLACK
			position.y = pos_base.y

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_ui_2d()
	_construir_tablero_3d()
	_preparar_mazos_autorreferenciales()
	juego_activo = true
	_ejecutar_introduccion_ente()

# ==============================================================================
# UI 2D MEJORADA (Textos Legibles y Tooltips de Biología)
# ==============================================================================
func _construir_ui_2d() -> void:
	ui_layer = CanvasLayer.new()
	
	# Franja cinemática superior para el diálogo del Plásmido (Bacteria)
	var bg_dialogo := ColorRect.new()
	bg_dialogo.color = Color(0.0, 0.0, 0.0, 0.7)
	bg_dialogo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg_dialogo.custom_minimum_size.y = 120
	ui_layer.add_child(bg_dialogo)
	
	label_dialogo = RichTextLabel.new()
	label_dialogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	label_dialogo.offset_left = 40
	label_dialogo.offset_right = -40
	label_dialogo.offset_top = 20
	label_dialogo.add_theme_font_size_override("normal_font_size", 28)
	label_dialogo.bbcode_enabled = true
	label_dialogo.text = ""
	bg_dialogo.add_child(label_dialogo)
	
	# Interfaz del sistema (Puntuación)
	label_sistema = Label.new()
	label_sistema.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label_sistema.offset_top = -100
	label_sistema.offset_left = 30
	label_sistema.add_theme_font_size_override("font_size", 22)
	label_sistema.add_theme_color_override("font_color", Color(0.2, 0.9, 0.6))
	ui_layer.add_child(label_sistema)
	
	# Panel de Tooltip Biológico (Oculto por defecto)
	panel_tooltip = Panel.new()
	panel_tooltip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel_tooltip.offset_left = -450
	panel_tooltip.offset_top = -220
	panel_tooltip.offset_right = -30
	panel_tooltip.offset_bottom = -30
	panel_tooltip.visible = false
	
	var estilo_panel := StyleBoxFlat.new()
	estilo_panel.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	estilo_panel.border_width_left = 2; estilo_panel.border_width_top = 2
	estilo_panel.border_width_right = 2; estilo_panel.border_width_bottom = 2
	estilo_panel.border_color = Color(0.4, 0.4, 0.4)
	estilo_panel.corner_radius_top_left = 8; estilo_panel.corner_radius_top_right = 8
	estilo_panel.corner_radius_bottom_left = 8; estilo_panel.corner_radius_bottom_right = 8
	panel_tooltip.add_theme_stylebox_override("panel", estilo_panel)
	
	label_tooltip_titulo = Label.new()
	label_tooltip_titulo.position = Vector2(20, 15)
	label_tooltip_titulo.add_theme_font_size_override("font_size", 24)
	panel_tooltip.add_child(label_tooltip_titulo)
	
	label_tooltip_desc = RichTextLabel.new()
	label_tooltip_desc.position = Vector2(20, 55)
	label_tooltip_desc.size = Vector2(380, 120)
	label_tooltip_desc.add_theme_font_size_override("normal_font_size", 16)
	label_tooltip_desc.bbcode_enabled = true
	panel_tooltip.add_child(label_tooltip_desc)
	
	ui_layer.add_child(panel_tooltip)
	add_child(ui_layer)
	
	# Instrucciones de cámara
	var lbl_cam := Label.new()
	lbl_cam.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_cam.offset_top = -30
	lbl_cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cam.text = "[Click Derecho + Arrastrar] para rotar cámara | [Rueda Ratón] para Zoom"
	lbl_cam.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	ui_layer.add_child(lbl_cam)

# ==============================================================================
# CONSTRUCCIÓN 3D Y CÁMARA LIBRE
# ==============================================================================
func _construir_tablero_3d() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.015)
	env.glow_enabled = true
	env.glow_intensity = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	pivot_camara = Node3D.new()
	add_child(pivot_camara)
	
	camara = Camera3D.new()
	camara.current = true
	pivot_camara.add_child(camara)
	_actualizar_posicion_camara()
	
	luz_cenital = SpotLight3D.new()
	luz_cenital.position = Vector3(0, 12, 0)
	luz_cenital.rotation_degrees.x = -90
	luz_cenital.light_energy = 5.0
	luz_cenital.spot_angle = 60.0
	add_child(luz_cenital)
	
	var tapete := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(16, 0.5, 12)
	tapete.mesh = t_mesh
	var mat_t := StandardMaterial3D.new()
	mat_t.albedo_color = Color(0.04, 0.05, 0.06)
	tapete.material_override = mat_t
	tapete.position.y = -0.25
	add_child(tapete)

func _actualizar_posicion_camara() -> void:
	pivot_camara.rotation_degrees = Vector3(rotacion_camara_x, rotacion_camara_y, 0)
	camara.position = Vector3(0, 0, distancia_camara)

func _preparar_mazos_autorreferenciales() -> void:
	var nucleo_base: Array = ["Lípido", "ARN_m", "Péptido", "Ribozima"]
	var gestor = get_node_or_null("/root/GestorQuimico")
	
	if is_instance_valid(gestor):
		var mazo = gestor.get("mazo_genetico")
		if typeof(mazo) == TYPE_ARRAY and not mazo.is_empty():
			var seq = mazo[-1].get("secuencia")
			if typeof(seq) == TYPE_ARRAY:
				nucleo_base = seq.duplicate()
		
	var inicio_x: float = -((nucleo_base.size() - 1) * 1.3) / 2.0
	for i in range(min(nucleo_base.size(), 7)):
		var c := CartaNucleotido.new()
		var pos := Vector3(inicio_x + (i * 1.4), 0.05, 3.5)
		c.inicializar(nucleo_base[i], pos, true)
		add_child(c)
		mazo_jugador.append(c)
		
	var inicio_rival_x: float = -((secuencia_objetivo_rival.size() - 1) * 1.3) / 2.0
	for j in range(secuencia_objetivo_rival.size()):
		var c_r := CartaNucleotido.new()
		var pos_r := Vector3(inicio_rival_x + (j * 1.4), 0.05, -2.5)
		c_r.inicializar(secuencia_objetivo_rival[j], pos_r, false)
		c_r.en_tablero = true
		add_child(c_r)
		cartas_tablero_rival.append(c_r)

# ==============================================================================
# LÓGICA DE JUEGO Y TOOLTIPS
# ==============================================================================
func _ejecutar_introduccion_ente() -> void:
	await _hablar("[color=#ffcc00]INTERCONEXIÓN BACTERIANA ESTABLECIDA.[/color]")
	await _hablar("Tus cartas definen la estructura química de tu membrana. El plásmido invasor (cartas de arriba) busca integrarse a ti.")
	await _hablar("Para absorber su código, debes formar pares bioquímicos lógicos. Pasa el cursor sobre tus cartas para entender tu genoma, y luego selecciona una para emparejarla.")
	_actualizar_matriz_sistema()

func _hablar(texto: String) -> void:
	escribiendo = true
	label_dialogo.text = ""
	
	# Evitar etiquetas BBCode en el tipeo letra por letra
	var texto_limpio = texto.replace("[color=#ffcc00]", "").replace("[/color]", "")
	var en_etiqueta = false
	
	label_dialogo.text = texto
	
	# Efecto de máquina de escribir simulado rápido
	label_dialogo.visible_characters = 0
	for i in range(label_dialogo.get_total_character_count()):
		label_dialogo.visible_characters += 1
		await get_tree().create_timer(0.015).timeout
		
	escribiendo = false
	await get_tree().create_timer(2.0).timeout

func _physics_process(_delta: float) -> void:
	if not juego_activo or moviendo_camara: return
	
	var raton := get_viewport().get_mouse_position()
	var origen := camara.project_ray_origin(raton)
	var dir := camara.project_ray_normal(raton)
	
	var space_state := get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origen, origen + dir * 100.0))
	
	if hit:
		var obj = hit.collider
		if obj is CartaNucleotido:
			if ray_hovered != obj: 
				_limpiar_hover()
				ray_hovered = obj
				if obj.es_jugador and not obj.en_tablero:
					ray_hovered.set_glow(true)
				_mostrar_tooltip_biologico(obj.tipo_macro, obj.es_jugador)
	else: 
		_limpiar_hover()

func _mostrar_tooltip_biologico(tipo: String, es_tuya: bool) -> void:
	panel_tooltip.visible = true
	if BIO_DATA.has(tipo):
		var data = BIO_DATA[tipo]
		var prop: String = "(Tu Genoma)" if es_tuya else "(Plásmido Invasor)"
		label_tooltip_titulo.text = tipo + " " + prop
		label_tooltip_titulo.add_theme_color_override("font_color", data["color"])
		
		# Modificamos el estilo del borde dinámicamente
		var sb = panel_tooltip.get_theme_stylebox("panel").duplicate()
		sb.border_color = data["color"]
		panel_tooltip.add_theme_stylebox_override("panel", sb)
		
		label_tooltip_desc.text = data["desc"]

func _limpiar_hover() -> void:
	if is_instance_valid(ray_hovered) and ray_hovered != seleccionada: 
		ray_hovered.set_glow(false)
	ray_hovered = null
	panel_tooltip.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not juego_activo: return
	
	# Lógica de Cámara Orbital (Click derecho y arrastrar)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			moviendo_camara = event.pressed
			if moviendo_camara:
				_limpiar_hover()
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia_camara = clamp(distancia_camara - 1.0, 5.0, 20.0)
			_actualizar_posicion_camara()
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia_camara = clamp(distancia_camara + 1.0, 5.0, 20.0)
			_actualizar_posicion_camara()
			
	elif event is InputEventMouseMotion and moviendo_camara:
		rotacion_camara_y -= event.relative.x * 0.3
		rotacion_camara_x = clamp(rotacion_camara_x - event.relative.y * 0.3, -80.0, -10.0)
		_actualizar_posicion_camara()

	# Lógica de Interacción (Click izquierdo en cartas)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not moviendo_camara:
		if is_instance_valid(ray_hovered) and ray_hovered is CartaNucleotido: 
			if ray_hovered.es_jugador and not ray_hovered.en_tablero:
				_seleccionar_o_alinear(ray_hovered)

func _seleccionar_o_alinear(carta: CartaNucleotido) -> void:
	if seleccionada == null:
		seleccionada = carta
		var c = seleccionada.material_inst.get_meta("glow_color")
		if typeof(c) == TYPE_COLOR:
			seleccionada.material_inst.emission = c * 0.8
	else:
		if seleccionada == carta: 
			seleccionada.set_glow(false)
			seleccionada = null
		else: 
			seleccionada.set_glow(false)
			seleccionada = carta
			var c = seleccionada.material_inst.get_meta("glow_color")
			if typeof(c) == TYPE_COLOR:
				seleccionada.material_inst.emission = c * 0.8

	if is_instance_valid(seleccionada) and cartas_tablero_jugador.size() < cartas_tablero_rival.size():
		var idx: int = cartas_tablero_jugador.size()
		var target_x: float = cartas_tablero_rival[idx].position.x
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# Posicionamos tu carta frente a la carta del rival (emparejamiento)
		var pos_destino := Vector3(target_x, 0.05, -1.0)
		var c_a_mover: CartaNucleotido = seleccionada
		seleccionada = null
		
		c_a_mover.en_tablero = true
		mazo_jugador.erase(c_a_mover)
		cartas_tablero_jugador.append(c_a_mover)
		t.tween_property(c_a_mover, "position", pos_destino, 0.3)
		t.tween_callback(func(): _evaluar_enlace_cibernetico(c_a_mover, idx))

func _evaluar_enlace_cibernetico(carta_jugador: CartaNucleotido, indice: int) -> void:
	var carta_rival: CartaNucleotido = cartas_tablero_rival[indice]
	var afinidad_exitosa: bool = false
	var mensaje_exito: String = ""
	
	# REGLAS BIOLÓGICAS DE CONJUGACIÓN (Con mensaje diegético)
	if carta_jugador.tipo_macro == "ARN_m" and carta_rival.tipo_macro == "Ribozima": 
		afinidad_exitosa = true
		mensaje_exito = "[color=#aaffaa]¡Sinergia! El ARN fue leído por la enzima.[/color]"
	elif carta_jugador.tipo_macro == "Ribozima" and carta_rival.tipo_macro == "ARN_m": 
		afinidad_exitosa = true
		mensaje_exito = "[color=#aaffaa]¡Traducción iniciada! La enzima catalizó el ARN.[/color]"
	elif carta_jugador.tipo_macro == "Lípido" and carta_rival.tipo_macro == "Lípido": 
		afinidad_exitosa = true
		mensaje_exito = "[color=#aaffaa]¡Bicapa sellada! Membrana expandida.[/color]"
	elif carta_jugador.tipo_macro == "Péptido" and carta_rival.tipo_macro == "ARN_m": 
		afinidad_exitosa = true
		mensaje_exito = "[color=#aaffaa]¡Plegamiento estructural protector![/color]"
	elif carta_jugador.tipo_macro == "Ribozima" and carta_rival.tipo_macro == "Péptido": 
		afinidad_exitosa = true
		mensaje_exito = "[color=#aaffaa]¡Síntesis proteica acelerada![/color]"
	
	if afinidad_exitosa:
		indice_alineacion_actual += 20.0
		carta_jugador.material_inst.emission = Color(0.2, 1.0, 0.4) * 0.8 
		_hablar(mensaje_exito)
	else:
		indice_alineacion_actual += 5.0
		carta_jugador.material_inst.emission = Color(1.0, 0.2, 0.2) * 0.5 
		_hablar("[color=#ff5555]Enlace fallido: Mutación estéril termodinámica.[/color]")
		
	_actualizar_matriz_sistema()
	
	if cartas_tablero_jugador.size() == cartas_tablero_rival.size(): 
		_concluir_compilacion_genoma()

func _actualizar_matriz_sistema() -> void:
	var t: String = "TASA DE ASIMILACIÓN\n"
	t += "Metabolismo Ganado: " + str(int(indice_alineacion_actual)) + " pts\n"
	t += "Bono Generacional (Siguiente Vida): x" + str(1.0 + (indice_alineacion_actual / 100.0)) + "\n"
	label_sistema.text = t

func _concluir_compilacion_genoma() -> void:
	juego_activo = false
	var multiplicador_final: float = 1.0 + (indice_alineacion_actual / 100.0)
	
	var gestor = get_node_or_null("/root/GestorQuimico")
	if is_instance_valid(gestor):
		var bonos = gestor.get("bonos_ancestrales")
		if typeof(bonos) == TYPE_DICTIONARY:
			bonos["capacidad_energetica"] = bonos.get("capacidad_energetica", 1.0) * multiplicador_final
			bonos["eficiencia_catalitica"] = bonos.get("eficiencia_catalitica", 1.0) * multiplicador_final
	
	await _hablar("NUESTRO CÓDIGO AHORA ES UNO SOLO. HEMOS TRASCENDIDO LA UNICELULARIDAD.")
	await _hablar("Tus órganos heredarán un multiplicador metabólico permanente de: [b]x" + str(multiplicador_final) + "[/b]")
	await _hablar("DESPERTANDO EN LA ERA PROTEROZOICA...")
	
	if is_instance_valid(gestor):
		gestor.set("fase_evolutiva_actual", 4)
		if gestor.has_method("transicionar_escena"):
			gestor.transicionar_escena(0)
