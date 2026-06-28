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

var pos_mesa = Vector3(0, 7.5, 6.0)
var rot_mesa = Vector3(deg_to_rad(-52), 0, 0)
var pos_ente = Vector3(0, 3.5, 1.0)
var rot_ente = Vector3(deg_to_rad(5), 0, 0)

var cam_pos_base: Vector3 = pos_mesa
var cam_rot_base: Vector3 = rot_mesa
var tween_camara: Tween

class CartaRuna extends StaticBody3D:
	var simbolo: String
	var pos_original: Vector3
	var en_seleccion: bool = false
	var mat_base: StandardMaterial3D
	var malla_mesh: MeshInstance3D
	
	func inicializar(s: String, p: Vector3):
		simbolo = s; pos_original = p; position = p
		add_to_group("cartas")
		
		var col = CollisionShape3D.new(); var box = BoxShape3D.new(); box.size = Vector3(1.2, 0.2, 1.8); col.shape = box; add_child(col)
		malla_mesh = MeshInstance3D.new(); var box_mesh = BoxMesh.new(); box_mesh.size = Vector3(1.2, 0.2, 1.8); malla_mesh.mesh = box_mesh
		mat_base = StandardMaterial3D.new(); mat_base.albedo_color = Color(0.1, 0.1, 0.12); mat_base.roughness = 0.8; mat_base.metallic = 0.5
		mat_base.emission_enabled = true; mat_base.emission = Color.BLACK; malla_mesh.material_override = mat_base; add_child(malla_mesh)
		
		var lbl = Label3D.new(); lbl.text = simbolo; lbl.outline_size = 10; lbl.position = Vector3(0, 0.11, 0); lbl.rotation_degrees.x = -90
		var color = Color.WHITE
		
		var fase = GestorQuimico.fase_evolutiva_actual
		if fase == 1:
			lbl.font_size = 140
			var data = GestorQuimico.TABLA_PERIODICA[simbolo]
			match data["rol"]:
				"estructural": color = Color(0.6, 0.6, 0.6)
				"energia": color = Color(1.0, 0.8, 0.2)
				"oxidante": color = Color(0.9, 0.4, 0.4)
				"comodin": color = Color(0.6, 0.1, 1.0)
		elif fase in [2, 3]:
			lbl.font_size = 50 
			var data = GestorQuimico.MACROMOLECULAS[simbolo]
			match data["rol"]:
				"membrana": color = Color(0.9, 0.9, 0.2) 
				"informacion": color = Color(0.2, 0.8, 1.0) 
				"enzima": color = Color(0.8, 0.2, 0.8) 
				"estructura": color = Color(0.8, 0.3, 0.3)
		else: 
			lbl.font_size = 40 
			var data = GestorQuimico.TIPOS_CELULARES[simbolo]
			match data["rol"]:
				"cobertura": color = Color(0.4, 0.8, 0.9) 
				"motor": color = Color(0.9, 0.3, 0.3)     
				"nervioso": color = Color(1.0, 0.9, 0.1)  
				"reserva": color = Color(0.9, 0.6, 0.2)   
				
		lbl.modulate = color; mat_base.set_meta("glow", color); add_child(lbl)

	func set_hover(active: bool):
		if en_seleccion: return
		var t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if active: mat_base.emission = mat_base.get_meta("glow") * 0.5; t.tween_property(self, "position:y", pos_original.y + 0.3, 0.15)
		else: mat_base.emission = Color.BLACK; t.tween_property(self, "position:y", pos_original.y, 0.15)

func _ready():
	get_tree().paused = false; randomize(); _construir_entorno()
	texto_dialogo.text = ""; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	
	var fase = GestorQuimico.fase_evolutiva_actual
	var pool_fase_2 = ["Lípido", "Lípido", "Lípido", "ARN_m", "ARN_m", "Péptido", "Péptido", "Ribozima"]
	var pool_fase_4 = ["Epitelio", "Epitelio", "Epitelio", "Miocito", "Miocito", "Neurona", "Adipocito"]
	
	var offset_x = -((14 / 2.0) * 1.3) / 2.0
	for i in range(14):
		var fila = floor(i / 7.0); var col = i % 7
		var pos = Vector3(offset_x + (col * 1.4), 0.1, 1.5 + (fila * 1.8))
		var carta = CartaRuna.new()
		var gen = ""
		
		if fase == 1: gen = "C" if i == 0 else ("Og" if i == 1 else GestorQuimico.extraer_atomo_cuantico())
		elif fase in [2, 3]: gen = pool_fase_2[randi() % pool_fase_2.size()]
		else: gen = pool_fase_4[randi() % pool_fase_4.size()]
			
		carta.inicializar(gen, pos); carta.rotation_degrees = Vector3(10, -pos.x * 2.0, 0)
		add_child(carta); cartas_mesa.append(carta)
	
	await get_tree().create_timer(1.0).timeout; _cambiar_vista("ENTE")
	
	if fase == 1:
		await hablar("FORJA TU GENOMA. ESCRIBE CON MATERIA.")
	elif fase in [2, 3]:
		luz_cenital.light_color = Color(0.6, 0.2, 0.8)
		for o in ojos_ente.get_children(): o.material_override.emission = Color(0.6, 0.2, 0.8)
		await hablar("ERA PROTOCELULAR.\nENCLOSA TU POLÍMERO EN BICAPAS LIPÍDICAS.")
	else:
		luz_cenital.light_color = Color(1.0, 0.6, 0.2) 
		for o in ojos_ente.get_children(): o.material_override.emission = Color(1.0, 0.6, 0.2)
		await hablar("HAS ROTO LA BARRERA UNICELULAR.")
		await hablar("ESPECIALIZA TUS CÉLULAS. CREA TEJIDOS Y ÓRGANOS.")
		
	_cambiar_vista("MESA"); estado_juego = "DRAFTING"

func _construir_entorno():
	var env = Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.01, 0.01, 0.015)
	env.volumetric_fog_enabled = true; env.volumetric_fog_density = 0.05; env.glow_enabled = true; env.glow_intensity = 1.5
	var we = WorldEnvironment.new(); we.environment = env; add_child(we)
	
	camara = Camera3D.new(); camara.position = cam_pos_base; camara.rotation = cam_rot_base; add_child(camara)
	luz_cenital = SpotLight3D.new(); luz_cenital.position = Vector3(0, 10, 1.5); luz_cenital.rotation_degrees.x = -85; luz_cenital.spot_range = 20.0; luz_cenital.light_energy = 6.0; add_child(luz_cenital)
	
	var mesa = MeshInstance3D.new(); mesa.mesh = BoxMesh.new(); mesa.mesh.size = Vector3(16, 1, 10); var mat_mesa = StandardMaterial3D.new(); mat_mesa.albedo_color = Color(0.05, 0.04, 0.04); mesa.material_override = mat_mesa; mesa.position.y = -0.5; add_child(mesa)
	ojos_ente = Node3D.new(); ojos_ente.position = Vector3(0, 3.5, -4.5)
	for i in [-0.5, 0.5]:
		var ojo = MeshInstance3D.new(); ojo.mesh = SphereMesh.new(); ojo.mesh.radius = 0.1; ojo.mesh.height = 0.2
		var mat_ojo = StandardMaterial3D.new(); mat_ojo.albedo_color = Color.BLACK; mat_ojo.emission_enabled = true; mat_ojo.emission = Color(1.0, 0.9, 0.8); mat_ojo.emission_energy_multiplier = 4.0; ojo.material_override = mat_ojo; ojo.position.x = i; ojos_ente.add_child(ojo)
	add_child(ojos_ente)
	
	texto_dialogo = Label3D.new(); texto_dialogo.font_size = 46; texto_dialogo.position = Vector3(0, 2.0, -3.5); texto_dialogo.rotation_degrees.x = -15; texto_dialogo.modulate = Color(0.8, 0.9, 1.0); texto_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD; texto_dialogo.width = 1200.0; add_child(texto_dialogo)
	texto_stats = Label3D.new(); texto_stats.font_size = 32; texto_stats.position = Vector3(0, 0.01, -2.5); texto_stats.rotation_degrees.x = -90; texto_stats.modulate = Color(0.5, 0.8, 0.5); add_child(texto_stats)
	texto_controles = Label3D.new(); texto_controles.text = "[W] ENTE | [S] MESA | [TAB] VER CÓDEX"; texto_controles.font_size = 24; texto_controles.position = Vector3(0, 0.01, 3.5); texto_controles.rotation_degrees.x = -90; texto_controles.modulate = Color(0.3, 0.3, 0.3); add_child(texto_controles)
	
	boton_incubar = StaticBody3D.new(); var col_btn = CollisionShape3D.new(); col_btn.shape = CylinderShape3D.new(); col_btn.shape.radius = 0.8; col_btn.shape.height = 0.2; boton_incubar.add_child(col_btn)
	var mesh_btn = MeshInstance3D.new(); mesh_btn.mesh = CylinderMesh.new(); mesh_btn.mesh.top_radius = 0.8; mesh_btn.mesh.bottom_radius = 0.9; mesh_btn.mesh.height = 0.2; var mat_btn = StandardMaterial3D.new(); mat_btn.albedo_color = Color(0.3, 0.0, 0.0); mat_btn.emission_enabled = true; mat_btn.emission = Color(0.4, 0.0, 0.0); mesh_btn.material_override = mat_btn; boton_incubar.add_child(mesh_btn)
	var lbl_btn = Label3D.new(); lbl_btn.text = "SINTETIZAR"; lbl_btn.font_size = 45; lbl_btn.position = Vector3(0, 0.11, 0); lbl_btn.rotation_degrees.x = -90; boton_incubar.add_child(lbl_btn)
	boton_incubar.position = Vector3(7.0, 0.1, 0); boton_incubar.set_meta("es_boton", true); add_child(boton_incubar)

var tiempo = 0.0
func _process(delta):
	tiempo += delta
	var raton_pos = get_viewport().get_mouse_position(); var screen_size = get_viewport().get_visible_rect().size
	var offset_x = (raton_pos.x / screen_size.x) - 0.5; var offset_y = (raton_pos.y / screen_size.y) - 0.5
	var sway_pos = Vector3(offset_x * 4.0, -offset_y * 2.5, 0); var sway_rot = Vector3(-offset_y * 0.5, -offset_x * 0.5, 0)
	
	if not (tween_camara and tween_camara.is_running()):
		var target_pos = cam_pos_base + sway_pos; var target_rot = cam_rot_base + sway_rot
		camara.position = camara.position.lerp(target_pos, delta * 4.0); camara.rotation.x = lerp_angle(camara.rotation.x, target_rot.x, delta * 4.0); camara.rotation.y = lerp_angle(camara.rotation.y, target_rot.y, delta * 4.0)
	ojos_ente.position.y = 3.5 + sin(tiempo * 1.2) * 0.08
	if escribiendo: luz_cenital.light_energy = 6.0 + sin(tiempo * 20.0) * 0.5

func hablar(texto: String):
	escribiendo = true; texto_dialogo.text = ""
	for i in range(texto.length()):
		texto_dialogo.text += texto[i]
		if texto[i] in [".", ",", "\n"]: await get_tree().create_timer(0.1).timeout
		else: await get_tree().create_timer(0.02).timeout
	escribiendo = false; await get_tree().create_timer(1.0).timeout

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_TAB:
		_alternar_codex()
		return
			
	if estado_juego != "DRAFTING" or escribiendo: return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_W and objetivo_camara == "MESA": _cambiar_vista("ENTE")
		elif event.keycode == KEY_S and objetivo_camara == "ENTE": _cambiar_vista("MESA")
	if objetivo_camara != "MESA": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if ray_hovered is CartaRuna: _alternar_carta(ray_hovered)
			elif ray_hovered and ray_hovered.has_meta("es_boton"): _juzgar()
		elif event.button_index == MOUSE_BUTTON_RIGHT and cartas_seleccionadas.size() > 0:
			_alternar_carta(cartas_seleccionadas[-1])

func _cambiar_vista(vista: String):
	objetivo_camara = vista; _limpiar_hover()
	if tween_camara: tween_camara.kill()
	tween_camara = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if vista == "ENTE":
		tween_camara.parallel().tween_property(self, "cam_pos_base", pos_ente, 0.6); tween_camara.parallel().tween_property(self, "cam_rot_base", rot_ente, 0.6)
	else:
		tween_camara.parallel().tween_property(self, "cam_pos_base", pos_mesa, 0.6); tween_camara.parallel().tween_property(self, "cam_rot_base", rot_mesa, 0.6)

func _physics_process(_delta):
	if estado_juego != "DRAFTING" or escribiendo or objetivo_camara != "MESA": _limpiar_hover(); return
	var raton = get_viewport().get_mouse_position(); var origen = camara.project_ray_origin(raton); var dir = camara.project_ray_normal(raton)
	var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origen, origen + dir * 100.0))
	if hit:
		var obj = hit.collider
		if ray_hovered != obj:
			_limpiar_hover(); ray_hovered = obj
			if obj is CartaRuna: obj.set_hover(true)
			elif obj.has_meta("es_boton"): obj.get_child(1).material_override.emission = Color(0.8, 0.1, 0.1)
	else: _limpiar_hover()

func _limpiar_hover():
	if ray_hovered:
		if ray_hovered is CartaRuna: ray_hovered.set_hover(false)
		elif ray_hovered.has_meta("es_boton"): ray_hovered.get_child(1).material_override.emission = Color(0.4, 0.0, 0.0)
		ray_hovered = null

func _alternar_carta(carta: CartaRuna):
	var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not carta.en_seleccion:
		if cartas_seleccionadas.size() >= 8: return
		cartas_mesa.erase(carta); cartas_seleccionadas.append(carta); carta.en_seleccion = true; _reordenar(t)
	else:
		cartas_seleccionadas.erase(carta); cartas_mesa.append(carta); carta.en_seleccion = false
		t.tween_property(carta, "position", carta.pos_original, 0.4); _reordenar(t)
	_actualizar_stats()

func _reordenar(t: Tween):
	var sep = 1.2; var ancho = (cartas_seleccionadas.size() - 1) * sep; var inicio = -ancho / 2.0
	for i in range(cartas_seleccionadas.size()):
		var c = cartas_seleccionadas[i]; var dest = Vector3(inicio + (i * sep), 0.1, -1.0)
		t.parallel().tween_property(c, "position", dest, 0.4); t.parallel().tween_property(c, "rotation_degrees", Vector3(0, 0, 0), 0.4)

func _actualizar_stats():
	var arr = []
	for c in cartas_seleccionadas: arr.append(c.simbolo)
	if arr.is_empty(): texto_stats.text = ""
	else:
		var fase = GestorQuimico.fase_evolutiva_actual
		if fase == 1:
			var sim = GestorQuimico.procesar_red_quimica(arr)
			texto_stats.text = "-".join(arr) + "\nMasa: " + str(sim["peso_molecular"]) + "u | Enlaces Libres: " + str(sim["valencia_residual"])
		elif fase in [2, 3]:
			var sim = GestorQuimico.procesar_protocelula(arr)
			texto_stats.text = "-".join(arr) + "\nMembrana: " + str(sim["stats_3d"]["integridad_membrana"]) + " | Info ARN: " + str(sim["stats_3d"]["procesamiento_info"])
		else:
			var sim = GestorQuimico.procesar_organismo(arr)
			texto_stats.text = "-".join(arr) + "\nSalud: " + str(sim["stats_3d"]["salud"]) + " | Fuerza Motriz: " + str(sim["stats_3d"]["fuerza_motriz"])

func _juzgar():
	if cartas_seleccionadas.is_empty(): return
	estado_juego = "EVALUANDO"; _cambiar_vista("ENTE")
	await hablar("EVALUANDO VIABILIDAD...")
	var arr = []
	for c in cartas_seleccionadas: arr.append(c.simbolo)
	
	var fase = GestorQuimico.fase_evolutiva_actual
	var resultado = {}
	
	if fase == 1: resultado = GestorQuimico.procesar_red_quimica(arr)
	elif fase in [2, 3]: resultado = GestorQuimico.procesar_protocelula(arr)
	else: resultado = GestorQuimico.procesar_organismo(arr)
	
	if resultado["es_viable"]:
		luz_cenital.light_color = Color(0.2, 1.0, 0.6)
		await hablar("DISEÑO VIABLE.")
		GestorQuimico.mazo_genetico.append({"secuencia": arr.duplicate(), "fenotipo": resultado})
		
		# Evitar fallo si una fase antigua no calcula "masa" general
		var masa_final = 0.0
		if resultado.has("peso_molecular"): masa_final = resultado["peso_molecular"]
		elif resultado.has("masa_celular"): masa_final = resultado["masa_celular"]
		elif resultado.has("masa_total"): masa_final = resultado["masa_total"]
			
		GestorQuimico.registro_fosil.append({"era": "Era " + str(fase), "genotipo": arr.duplicate(), "masa": masa_final})
		
		if fase == 1: GestorQuimico.transicionar_escena(1)
		elif fase in [2, 3]: GestorQuimico.transicionar_escena(2)
		else: GestorQuimico.transicionar_escena(4) 
	else:
		luz_cenital.light_color = Color(1.0, 0.2, 0.2)
		await hablar("FALLO ESTRUCTURAL:\n" + resultado["motivo_fallo"])
		_cambiar_vista("MESA"); cartas_seleccionadas.clear(); _actualizar_stats(); estado_juego = "DRAFTING"

func _alternar_codex():
	var layer = get_node_or_null("CanvasCodex")
	if layer: layer.queue_free()
	else:
		var cc = CanvasLayer.new(); cc.name = "CanvasCodex"
		var bg = ColorRect.new(); bg.color = Color(0.01, 0.01, 0.02, 0.95); bg.set_anchors_preset(Control.PRESET_FULL_RECT); cc.add_child(bg)
		var lbl = RichTextLabel.new(); lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = 50; lbl.offset_top = 50; lbl.offset_right = -50; lbl.offset_bottom = -50
		lbl.text = "[center][b]CÓDEX RIZOMÁTICO[/b][/center]\n\n[b]Reglas de la Era Actual (" + str(GestorQuimico.fase_evolutiva_actual) + "):[/b]\n"
		if GestorQuimico.fase_evolutiva_actual == 1:
			lbl.text += "- Construye cadenas estables compartiendo valencias.\n- El Carbono/Silicio son columnas vertebrales indispensables.\n\n"
		elif GestorQuimico.fase_evolutiva_actual in [2, 3]:
			lbl.text += "- Exige bicapas de Lípidos o el medio acuático disolverá tu célula.\n- Requiere ARN_m para controlar las funciones de motilidad.\n\n"
		else:
			lbl.text += "- Las Células Epiteliales son obligatorias para no disolverse.\n- Los Miocitos necesitan Neuronas para accionarse correctamente.\n\n"
		lbl.text += "[b]Historial Fósil Registrado:[/b]\n"
		for f in GestorQuimico.registro_fosil:
			lbl.text += "- " + f["era"] + " | Genoma: " + str(f["genotipo"]) + " | Masa: " + str(f["masa"]) + "u\n"
		bg.add_child(lbl); add_child(cc)
