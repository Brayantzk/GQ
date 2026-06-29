extends Node3D

var camara: Camera3D
var luz_cenital: SpotLight3D
var ojos_ente: Node3D
var texto_dialogo: Label3D
var texto_stats: Label3D
var texto_controles: Label3D

var cartas_mesa: Array = []
var cartas_seleccionadas: Array = []
var boton_incubar: StaticBody3D

var ray_hovered: Node3D = null
var estado_juego: String = "LORE" 
var escribiendo: bool = false
var objetivo_camara: String = "MESA" 

var pos_mesa: Vector3 = Vector3(0, 7.5, 6.0)
var rot_mesa: Vector3 = Vector3(deg_to_rad(-52), 0, 0)
var pos_ente: Vector3 = Vector3(0, 3.5, 1.0)
var rot_ente: Vector3 = Vector3(deg_to_rad(5), 0, 0)

var cam_pos_base: Vector3 = pos_mesa
var cam_rot_base: Vector3 = rot_mesa
var tween_camara: Tween

# UI para Explicaciones Universales y Bautismo
var ui_layer: CanvasLayer
var panel_tooltip: Panel
var lbl_tooltip_tit: Label
var lbl_tooltip_desc: RichTextLabel
var panel_bautismo: Panel
var input_bautismo: LineEdit
var carta_a_bautizar: CartaRuna = null

class CartaRuna extends StaticBody3D:
	var simbolo_interno: String
	var pos_original: Vector3
	var en_seleccion: bool = false
	var mat_base: StandardMaterial3D
	var lbl: Label3D
	
	func inicializar(s: String, p: Vector3) -> void:
		simbolo_interno = s
		pos_original = p
		position = p
		add_to_group("cartas")
		
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 0.2, 1.8)
		col.shape = box
		add_child(col)
		
		var malla_mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(1.2, 0.2, 1.8)
		malla_mesh.mesh = box_mesh
		
		mat_base = StandardMaterial3D.new()
		mat_base.albedo_color = Color(0.1, 0.1, 0.12)
		mat_base.emission_enabled = true
		mat_base.emission = Color.BLACK
		malla_mesh.material_override = mat_base
		add_child(malla_mesh)
		
		lbl = Label3D.new()
		lbl.outline_size = 10
		lbl.position = Vector3(0, 0.11, 0)
		lbl.rotation_degrees.x = -90
		_actualizar_texto_visual()
		
		var color := Color.WHITE
		var fase: int = GestorQuimico.fase_evolutiva_actual
		
		# FIX: Bloques match estructurados correctamente con saltos de línea para el parser de Godot 4
		if fase == 1:
			lbl.font_size = 80
			var data: Dictionary = GestorQuimico.TABLA_PERIODICA.get(simbolo_interno, {"rol": "inerte"})
			match str(data.get("rol")):
				"estructural", "estructural_pesado": 
					color = Color(0.6, 0.6, 0.6)
				"energia": 
					color = Color(1.0, 0.8, 0.2)
				"oxidante", "radical": 
					color = Color(0.9, 0.4, 0.4)
				"comodin", "metal_transicion", "reactivo": 
					color = Color(0.3, 0.5, 1.0)
		elif fase in [2, 3]:
			lbl.font_size = 40 
			var data: Dictionary = GestorQuimico.MACROMOLECULAS.get(simbolo_interno, {"rol": "estructura"})
			match str(data.get("rol")):
				"membrana": 
					color = Color(0.9, 0.9, 0.2)
				"informacion": 
					color = Color(0.2, 0.8, 1.0)
				"enzima": 
					color = Color(0.8, 0.2, 0.8)
				"estructura": 
					color = Color(0.8, 0.3, 0.3)
		else: 
			lbl.font_size = 35 
			var data: Dictionary = GestorQuimico.TIPOS_CELULARES.get(simbolo_interno, {"rol": "cobertura"})
			match str(data.get("rol")):
				"cobertura": 
					color = Color(0.4, 0.8, 0.9)
				"motor": 
					color = Color(0.9, 0.3, 0.3)
				"nervioso": 
					color = Color(1.0, 0.9, 0.1)
				"reserva": 
					color = Color(0.9, 0.6, 0.2)   
				
		lbl.modulate = color
		mat_base.set_meta("glow", color)
		add_child(lbl)

	func _actualizar_texto_visual() -> void:
		lbl.text = GestorQuimico.obtener_nombre_carta(simbolo_interno)

	func set_hover(active: bool) -> void:
		if en_seleccion: 
			return
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if active: 
			mat_base.emission = (mat_base.get_meta("glow") as Color) * 0.5
			t.tween_property(self, "position:y", pos_original.y + 0.3, 0.15)
		else: 
			mat_base.emission = Color.BLACK
			t.tween_property(self, "position:y", pos_original.y, 0.15)

func _ready() -> void:
	get_tree().paused = false
	randomize()
	_construir_entorno()
	_construir_ui_tooltips()
	
	var fase: int = GestorQuimico.fase_evolutiva_actual
	var pool_fase_2: Array = ["Lípido", "Lípido", "Lípido", "ARN_m", "ARN_m", "Péptido", "Péptido", "Ribozima"]
	var pool_fase_4: Array = ["Epitelio", "Epitelio", "Epitelio", "Miocito", "Miocito", "Neurona", "Adipocito"]
	
	var offset_x: float = -((14 / 2.0) * 1.3) / 2.0
	for i in range(14):
		var pos := Vector3(offset_x + ((i % 7) * 1.4), 0.1, 1.5 + (floor(i / 7.0) * 1.8))
		var carta := CartaRuna.new()
		
		# FIX: Asignación de genoma estructurada limpiamente sin encadenamiento de ternarios agresivos
		var gen: String = ""
		if fase == 1:
			if i == 0:
				gen = "C"
			elif i == 1:
				gen = "Og"
			else:
				gen = GestorQuimico.extraer_atomo_cuantico()
		elif fase in [2, 3]:
			gen = str(pool_fase_2[randi() % pool_fase_2.size()])
		else:
			gen = str(pool_fase_4[randi() % pool_fase_4.size()])
			
		carta.inicializar(gen, pos)
		carta.rotation_degrees = Vector3(10, -pos.x * 2.0, 0)
		add_child(carta)
		cartas_mesa.append(carta)
	
	await get_tree().create_timer(1.0).timeout
	_cambiar_vista("ENTE")
	
	if fase == 1:
		await hablar("FORJA TU GENOMA. BAUTIZA TUS DESCUBRIMIENTOS.")
	elif fase in [2, 3]:
		await hablar("ERA PROTOCELULAR.")
	else:
		await hablar("CREA TEJIDOS Y ÓRGANOS.")
		
	_cambiar_vista("MESA")
	estado_juego = "DRAFTING"

func _construir_ui_tooltips() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	panel_tooltip = Panel.new()
	panel_tooltip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel_tooltip.offset_left = -350
	panel_tooltip.offset_top = -150
	panel_tooltip.offset_right = -20
	panel_tooltip.offset_bottom = -20
	panel_tooltip.visible = false
	
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_color = Color(0.5, 0.5, 0.5)
	panel_tooltip.add_theme_stylebox_override("panel", estilo)
	
	lbl_tooltip_tit = Label.new()
	lbl_tooltip_tit.position = Vector2(15, 10)
	lbl_tooltip_tit.add_theme_font_size_override("font_size", 20)
	panel_tooltip.add_child(lbl_tooltip_tit)
	
	lbl_tooltip_desc = RichTextLabel.new()
	lbl_tooltip_desc.position = Vector2(15, 40)
	lbl_tooltip_desc.size = Vector2(320, 90)
	panel_tooltip.add_child(lbl_tooltip_desc)
	ui_layer.add_child(panel_tooltip)
	
	panel_bautismo = Panel.new()
	panel_bautismo.set_anchors_preset(Control.PRESET_CENTER)
	panel_bautismo.offset_left = -150
	panel_bautismo.offset_top = -50
	panel_bautismo.offset_right = 150
	panel_bautismo.offset_bottom = 50
	panel_bautismo.visible = false
	panel_bautismo.add_theme_stylebox_override("panel", estilo)
	
	var lbl_baut := Label.new()
	lbl_baut.text = "Bautizar Función:"
	lbl_baut.position = Vector2(10, 10)
	panel_bautismo.add_child(lbl_baut)
	
	input_bautismo = LineEdit.new()
	input_bautismo.position = Vector2(10, 40)
	input_bautismo.size = Vector2(280, 40)
	input_bautismo.text_submitted.connect(_on_bautizo_completado)
	panel_bautismo.add_child(input_bautismo)
	ui_layer.add_child(panel_bautismo)

func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.volumetric_fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	camara = Camera3D.new()
	camara.position = cam_pos_base
	camara.rotation = cam_rot_base
	add_child(camara)
	
	luz_cenital = SpotLight3D.new()
	luz_cenital.position = Vector3(0, 10, 1.5)
	luz_cenital.rotation_degrees.x = -85
	luz_cenital.spot_range = 20.0
	luz_cenital.light_energy = 6.0
	add_child(luz_cenital)
	
	var mesa := MeshInstance3D.new()
	mesa.mesh = BoxMesh.new()
	mesa.mesh.size = Vector3(16, 1, 10)
	var mat_mesa := StandardMaterial3D.new()
	mat_mesa.albedo_color = Color(0.05, 0.04, 0.04)
	mesa.material_override = mat_mesa
	mesa.position.y = -0.5
	add_child(mesa)
	
	ojos_ente = Node3D.new()
	ojos_ente.position = Vector3(0, 3.5, -4.5)
	for i in [-0.5, 0.5]:
		var ojo := MeshInstance3D.new()
		ojo.mesh = SphereMesh.new()
		ojo.mesh.radius = 0.1
		ojo.mesh.height = 0.2
		var mat_ojo := StandardMaterial3D.new()
		mat_ojo.albedo_color = Color.BLACK
		mat_ojo.emission_enabled = true
		mat_ojo.emission = Color(1.0, 0.9, 0.8)
		mat_ojo.emission_energy_multiplier = 4.0
		ojo.material_override = mat_ojo
		ojo.position.x = i
		ojos_ente.add_child(ojo)
	add_child(ojos_ente)
	
	texto_dialogo = Label3D.new()
	texto_dialogo.font_size = 46
	texto_dialogo.position = Vector3(0, 2.0, -3.5)
	texto_dialogo.rotation_degrees.x = -15
	texto_dialogo.modulate = Color(0.8, 0.9, 1.0)
	texto_dialogo.width = 1200.0
	add_child(texto_dialogo)
	
	texto_stats = Label3D.new()
	texto_stats.font_size = 32
	texto_stats.position = Vector3(0, 0.01, -2.5)
	texto_stats.rotation_degrees.x = -90
	texto_stats.modulate = Color(0.5, 0.8, 0.5)
	add_child(texto_stats)
	
	texto_controles = Label3D.new()
	texto_controles.text = "[Click Izq] Seleccionar | [Click Der] Bautizar Carta"
	texto_controles.font_size = 24
	texto_controles.position = Vector3(0, 0.01, 3.5)
	texto_controles.rotation_degrees.x = -90
	texto_controles.modulate = Color(0.4, 0.4, 0.4)
	add_child(texto_controles)
	
	boton_incubar = StaticBody3D.new()
	var col_btn := CollisionShape3D.new()
	col_btn.shape = CylinderShape3D.new()
	col_btn.shape.radius = 0.8
	col_btn.shape.height = 0.2
	boton_incubar.add_child(col_btn)
	
	var mesh_btn := MeshInstance3D.new()
	mesh_btn.mesh = CylinderMesh.new()
	mesh_btn.mesh.top_radius = 0.8
	mesh_btn.mesh.bottom_radius = 0.9
	mesh_btn.mesh.height = 0.2
	var mat_btn := StandardMaterial3D.new()
	mat_btn.albedo_color = Color(0.3, 0.0, 0.0)
	mat_btn.emission_enabled = true
	mat_btn.emission = Color(0.4, 0.0, 0.0)
	mesh_btn.material_override = mat_btn
	boton_incubar.add_child(mesh_btn)
	
	var lbl_btn := Label3D.new()
	lbl_btn.text = "SINTETIZAR"
	lbl_btn.font_size = 45
	lbl_btn.position = Vector3(0, 0.11, 0)
	lbl_btn.rotation_degrees.x = -90
	boton_incubar.add_child(lbl_btn)
	
	boton_incubar.position = Vector3(7.0, 0.1, 0)
	boton_incubar.set_meta("es_boton", true)
	add_child(boton_incubar)

var tiempo: float = 0.0
func _process(delta: float) -> void:
	tiempo += delta
	var raton_pos := get_viewport().get_mouse_position()
	var screen_size := get_viewport().get_visible_rect().size
	var offset_x: float = (raton_pos.x / screen_size.x) - 0.5
	var offset_y: float = (raton_pos.y / screen_size.y) - 0.5
	
	if not (tween_camara and tween_camara.is_running()):
		camara.position = camara.position.lerp(cam_pos_base + Vector3(offset_x * 4.0, -offset_y * 2.5, 0), delta * 4.0)
		camara.rotation.x = lerp_angle(camara.rotation.x, cam_rot_base.x - offset_y * 0.5, delta * 4.0)
		camara.rotation.y = lerp_angle(camara.rotation.y, cam_rot_base.y - offset_x * 0.5, delta * 4.0)
		
	ojos_ente.position.y = 3.5 + sin(tiempo * 1.2) * 0.08
	if escribiendo: 
		luz_cenital.light_energy = 6.0 + sin(tiempo * 20.0) * 0.5

func hablar(texto: String) -> void:
	escribiendo = true
	texto_dialogo.text = ""
	for i in range(texto.length()):
		texto_dialogo.text += texto[i]
		if texto[i] in [".", ",", "\n"]: 
			await get_tree().create_timer(0.1).timeout
		else: 
			await get_tree().create_timer(0.02).timeout
	escribiendo = false
	await get_tree().create_timer(1.0).timeout

func _unhandled_input(event: InputEvent) -> void:
	if estado_juego != "DRAFTING" or escribiendo or panel_bautismo.visible: 
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if ray_hovered is CartaRuna: 
				_alternar_carta(ray_hovered)
			elif is_instance_valid(ray_hovered) and ray_hovered.has_meta("es_boton"): 
				_juzgar()
		elif event.button_index == MOUSE_BUTTON_RIGHT and ray_hovered is CartaRuna:
			_abrir_bautismo(ray_hovered)

func _abrir_bautismo(carta: CartaRuna) -> void:
	carta_a_bautizar = carta
	panel_bautismo.visible = true
	input_bautismo.text = GestorQuimico.obtener_nombre_carta(carta.simbolo_interno)
	input_bautismo.grab_focus()

func _on_bautizo_completado(nuevo_nombre: String) -> void:
	panel_bautismo.visible = false
	if nuevo_nombre.strip_edges() != "" and is_instance_valid(carta_a_bautizar):
		GestorQuimico.nomenclatura_jugador[carta_a_bautizar.simbolo_interno] = nuevo_nombre
		for c in get_tree().get_nodes_in_group("cartas"):
			if c.simbolo_interno == carta_a_bautizar.simbolo_interno: 
				c._actualizar_texto_visual()
	carta_a_bautizar = null
	_limpiar_hover()

func _physics_process(_delta: float) -> void:
	if estado_juego != "DRAFTING" or escribiendo or panel_bautismo.visible: 
		_limpiar_hover()
		return
		
	var raton := get_viewport().get_mouse_position()
	var origen := camara.project_ray_origin(raton)
	var dir := camara.project_ray_normal(raton)
	
	var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origen, origen + dir * 100.0))
	if hit:
		var obj = hit.collider
		if ray_hovered != obj:
			_limpiar_hover()
			ray_hovered = obj
			if obj is CartaRuna: 
				obj.set_hover(true)
				_mostrar_tooltip(obj.simbolo_interno)
			elif obj.has_meta("es_boton"): 
				(obj.get_child(1) as MeshInstance3D).material_override.emission = Color(0.8, 0.1, 0.1)
	else: 
		_limpiar_hover()

func _mostrar_tooltip(simbolo: String) -> void:
	panel_tooltip.visible = true
	var fase: int = GestorQuimico.fase_evolutiva_actual
	lbl_tooltip_tit.text = GestorQuimico.obtener_nombre_carta(simbolo) + " (" + simbolo + ")"
	
	if fase == 1: 
		lbl_tooltip_desc.text = GestorQuimico.TABLA_PERIODICA.get(simbolo, {}).get("desc", "Desconocido.")
	elif fase in [2,3]: 
		lbl_tooltip_desc.text = GestorQuimico.MACROMOLECULAS.get(simbolo, {}).get("desc", "Componente orgánico.")
	else: 
		lbl_tooltip_desc.text = GestorQuimico.TIPOS_CELULARES.get(simbolo, {}).get("desc", "Tejido especializado.")

func _limpiar_hover() -> void:
	if is_instance_valid(ray_hovered):
		if ray_hovered is CartaRuna: 
			ray_hovered.set_hover(false)
		elif ray_hovered.has_meta("es_boton"): 
			(ray_hovered.get_child(1) as MeshInstance3D).material_override.emission = Color(0.4, 0.0, 0.0)
	ray_hovered = null
	panel_tooltip.visible = false

func _alternar_carta(carta: CartaRuna) -> void:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not carta.en_seleccion:
		if cartas_seleccionadas.size() >= 8: return
		cartas_mesa.erase(carta)
		cartas_seleccionadas.append(carta)
		carta.en_seleccion = true
	else:
		cartas_seleccionadas.erase(carta)
		cartas_mesa.append(carta)
		carta.en_seleccion = false
		t.tween_property(carta, "position", carta.pos_original, 0.4)
	
	var sep: float = 1.2
	var ancho: float = (cartas_seleccionadas.size() - 1) * sep
	var inicio: float = -ancho / 2.0
	for i in range(cartas_seleccionadas.size()):
		var c: CartaRuna = cartas_seleccionadas[i]
		t.parallel().tween_property(c, "position", Vector3(inicio + (i * sep), 0.1, -1.0), 0.4)
		t.parallel().tween_property(c, "rotation_degrees", Vector3.ZERO, 0.4)
	_actualizar_stats()

func _actualizar_stats() -> void:
	var arr: Array = []
	for c in cartas_seleccionadas: 
		arr.append(c.simbolo_interno)
		
	if arr.is_empty(): 
		texto_stats.text = ""
	else:
		var fase: int = GestorQuimico.fase_evolutiva_actual
		if fase == 1: 
			texto_stats.text = "Peso: " + str(GestorQuimico.procesar_red_quimica(arr)["peso_molecular"]) + "u"
		elif fase in [2,3]: 
			texto_stats.text = "Membrana: " + str(GestorQuimico.procesar_protocelula(arr)["stats_3d"]["integridad_membrana"])
		else: 
			texto_stats.text = "Salud: " + str(GestorQuimico.procesar_organismo(arr)["stats_3d"]["salud"])

func _cambiar_vista(vista: String) -> void:
	objetivo_camara = vista
	_limpiar_hover()
	if tween_camara: 
		tween_camara.kill()
		
	tween_camara = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_camara.parallel().tween_property(self, "cam_pos_base", pos_ente if vista == "ENTE" else pos_mesa, 0.6)
	tween_camara.parallel().tween_property(self, "cam_rot_base", rot_ente if vista == "ENTE" else rot_mesa, 0.6)

func _juzgar() -> void:
	if cartas_seleccionadas.is_empty(): 
		return
		
	estado_juego = "EVALUANDO"
	_cambiar_vista("ENTE")
	await hablar("EVALUANDO SÍNTESIS...")
	
	var arr: Array = []
	for c in cartas_seleccionadas: 
		arr.append(c.simbolo_interno)
		
	var fase: int = GestorQuimico.fase_evolutiva_actual
	var resultado: Dictionary = GestorQuimico.procesar_red_quimica(arr) if fase == 1 else (GestorQuimico.procesar_protocelula(arr) if fase in [2,3] else GestorQuimico.procesar_organismo(arr))
	
	if resultado.get("es_viable", false):
		luz_cenital.light_color = Color(0.2, 1.0, 0.6)
		await hablar("DISEÑO VIABLE.")
		GestorQuimico.mazo_genetico.append({"secuencia": arr.duplicate(), "fenotipo": resultado})
		GestorQuimico.transicionar_escena(fase if fase == 1 else (2 if fase in [2,3] else 4))
	else:
		luz_cenital.light_color = Color(1.0, 0.2, 0.2)
		await hablar("FALLO ESTRUCTURAL:\n" + str(resultado.get("motivo_fallo", "Inestable.")))
		_cambiar_vista("MESA")
		cartas_seleccionadas.clear()
		_actualizar_stats()
		estado_juego = "DRAFTING"
