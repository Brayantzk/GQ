extends Node

var mazo_genetico: Array = []
var fase_evolutiva_actual: int = 1 
var registro_fosil: Array = [] 

# El jugador bautiza las cartas al descubrir su función
var nomenclatura_jugador: Dictionary = {}

# La herencia física de la Fase 1 que altera los stats base de todas las demás fases
var impronta_quimica: Dictionary = {
	"eficiencia_atp": 1.0,
	"densidad_masa": 1.0,
	"potencial_accion": 1.0
}

var rutas_fases: Dictionary = {
	0: "res://archivo_cosmico.tscn",
	1: "res://fase_1_caldo.tscn",
	2: "res://fase_2_metabolismo.tscn",
	3: "res://fase_3_conjugacion.tscn",
	4: "res://fase_4_morfogenesis.tscn",
	5: "res://fase_5_sociologia.tscn" # <- AÑADIR ESTA LÍNEA
}

var TABLA_PERIODICA: Dictionary = {}

const DB_ELEMENTOS_CSV = """
H,1.008,1,2.20,739000,base|He,4.002,0,0.00,240000,inerte|Li,6.94,1,0.98,0.006,catalizador|Be,9.012,2,1.57,0.0001,estructural_pesado|B,10.81,3,2.04,0.001,estructural
C,12.011,4,2.55,4600,estructural|N,14.007,3,3.04,960,reactivo|O,15.999,2,3.44,10400,oxidante|F,18.998,1,3.98,0.4,radical|Ne,20.180,0,0.00,1260,inerte
Na,22.990,1,0.93,0.02,catalizador|Mg,24.305,2,1.31,30,puente|Al,26.982,3,1.61,0.05,estructural|Si,28.085,4,1.90,320,estructural|P,30.974,5,2.19,7,energia
S,32.06,2,2.58,440,puente|Cl,35.45,1,3.16,1,radical|Ar,39.95,0,0.00,30,inerte|K,39.098,1,0.82,0.003,catalizador|Ca,40.078,2,1.00,70,estructural_pesado
Sc,44.956,3,1.36,0.0003,metal_transicion|Ti,47.867,4,1.54,0.003,metal_transicion|V,50.942,5,1.63,0.0001,metal_transicion|Cr,51.996,6,1.66,0.015,metal_transicion
Mn,54.938,7,1.55,0.008,metal_transicion|Fe,55.845,6,1.83,1090,puente|Co,58.933,5,1.88,0.003,metal_transicion|Ni,58.693,4,1.91,84,metal_transicion
Cu,63.546,2,1.90,0.0006,metal_transicion|Zn,65.38,2,1.65,0.0003,metal_transicion|Ga,69.723,3,1.81,0.0001,metal_transicion|Ge,72.630,4,2.01,0.0002,metal_transicion
As,74.922,5,2.18,0.00008,reactivo|Se,78.971,2,2.55,0.00003,reactivo|Br,79.904,1,2.96,0.000007,radical|Kr,83.798,0,0.00,0.04,inerte
""" 

var MACROMOLECULAS: Dictionary = {
	"Lípido":   {"rol": "membrana", "integridad": 30.0, "info": 0.0, "desc": "Aísla del medio acuoso."},
	"ARN_m":    {"rol": "informacion", "integridad": 5.0, "info": 40.0, "desc": "Código procesable puro."},
	"Ribozima": {"rol": "enzima", "integridad": 10.0, "info": 20.0, "desc": "Catalizador de reacciones."},
	"Péptido":  {"rol": "estructura", "integridad": 25.0, "info": 0.0, "desc": "Ladrillo motriz."}
}

var TIPOS_CELULARES: Dictionary = {
	"Epitelio": {"costo_atp": 50.0, "defensa": 100.0, "energia": 0.0, "control": 0.0, "rol": "cobertura", "desc": "Escudo osmótico."},
	"Miocito":  {"costo_atp": 150.0, "defensa": 20.0, "energia": 0.0, "control": 50.0, "rol": "motor", "desc": "Fibra contráctil."},
	"Neurona":  {"costo_atp": 200.0, "defensa": 5.0,  "energia": 0.0, "control": 150.0, "rol": "nervioso", "desc": "Cálculo cibernético."},
	"Adipocito":{"costo_atp": 80.0,  "defensa": 10.0, "energia": 300.0, "control": 0.0, "rol": "reserva", "desc": "Batería química."}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_compilar_tabla_periodica_118()

func _compilar_tabla_periodica_118() -> void:
	var texto_limpio: String = DB_ELEMENTOS_CSV.replace("\n", "|")
	var bloques: PackedStringArray = texto_limpio.split("|")
	for bloque in bloques:
		if bloque.strip_edges() == "": continue
		var datos: PackedStringArray = bloque.split(",")
		if datos.size() < 6: continue
		TABLA_PERIODICA[datos[0]] = {
			"masa": float(datos[1]), "valencia": int(datos[2]), "electronegatividad": float(datos[3]),
			"energia": float(datos[1]) * 10.0, "abundancia": float(datos[4]), "rol": str(datos[5]),
			"desc": "Valencia: " + datos[2] + " | Rol: " + datos[5]
		}
	
	var simbolos_pesados: Array = ["Rb","Sr","Y","Zr","Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In","Sn","Sb","Te","I","Xe","Cs","Ba","La","Ce","Pr","Nd","Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb","Lu","Hf","Ta","W","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po","At","Rn","Fr","Ra","Ac","Th","Pa","U","Np","Pu","Am","Cm","Bk","Cf","Es","Fm","Md","No","Lr","Rf","Db","Sg","Bh","Hs","Mt","Ds","Rg","Cn","Nh","Fl","Mc","Lv","Ts","Og"]
	var masa_base: float = 85.0
	for i in range(simbolos_pesados.size()):
		var simb: String = str(simbolos_pesados[i])
		masa_base += 2.5
		var rol_asignado: String = "metal_transicion"
		if i > 50: rol_asignado = "radiactivo"
		if simb == "Og": rol_asignado = "comodin"
		TABLA_PERIODICA[simb] = {
			"masa": masa_base, "valencia": (i % 8) + 1, "electronegatividad": 1.5,
			"energia": masa_base * 20.0, "abundancia": 0.000001, "rol": rol_asignado,
			"desc": "Valencia: " + str((i % 8) + 1) + " | Rol: " + rol_asignado
		}

func transicionar_escena(indice_escena: int) -> void:
	if rutas_fases.has(indice_escena):
		get_tree().paused = false
		get_tree().change_scene_to_file(rutas_fases[indice_escena])

func extraer_atomo_cuantico() -> String:
	var keys: Array = TABLA_PERIODICA.keys()
	if keys.is_empty(): return "C" 
	var tirada: float = randf()
	if tirada > 0.95: return str(keys[randi_range(36, 117)]) 
	elif tirada > 0.70: return str(keys[randi_range(10, 35)]) 
	else: return str(keys[randi_range(0, 9)]) 

func obtener_nombre_carta(id_tecnico: String) -> String:
	return nomenclatura_jugador.get(id_tecnico, id_tecnico)

func procesar_red_quimica(secuencia: Array) -> Dictionary:
	var peso_total: float = 0.0; var valencia_total: int = 0; var energia_total: float = 0.0
	var reactividad: float = 0.0; var poderes: Array = []; var es_radiactivo: bool = false
	
	for sim in secuencia:
		var sim_str: String = str(sim)
		if TABLA_PERIODICA.has(sim_str):
			var data: Dictionary = TABLA_PERIODICA[sim_str]
			peso_total += float(data["masa"])
			valencia_total += int(data["valencia"])
			energia_total += float(data["energia"])
			reactividad += float(data["electronegatividad"])
			if str(data["rol"]) == "radiactivo": es_radiactivo = true
			if sim_str == "Og" and not poderes.has("ADAPTABILIDAD_CUÁNTICA"): poderes.append("ADAPTABILIDAD_CUÁNTICA")
				
	# EL POLÍMERO MODIFICA LAS LEYES FÍSICAS DEL RESTO DEL JUEGO
	impronta_quimica["eficiencia_atp"] = max(1.0, energia_total / 150.0)
	impronta_quimica["densidad_masa"] = max(1.0, peso_total / 80.0)
	impronta_quimica["potencial_accion"] = max(1.0, reactividad / 10.0)
	
	var viable: bool = valencia_total > 2 
	return {
		"es_viable": viable, "peso_molecular": peso_total, "valencia_residual": valencia_total, "energia_metabolica": energia_total,
		"motivo_fallo": "Inestable." if not viable else "",
		"stats_3d": {"consumo_atp": max(0.5, peso_total * 0.05), "radio_colision": 0.5 + (peso_total * 0.01), "velocidad": max(15.0, 50.0 - (peso_total * 0.1)), "poderes": poderes},
		"fenotipo_visual": {"color_emision": Color(0.2, 1.0, 0.4) if es_radiactivo else Color(0.4, 0.8, 1.0), "ruido_orbital": peso_total * 0.02}
	}

func procesar_protocelula(secuencia: Array) -> Dictionary:
	var integridad: float = 0.0; var info: float = 0.0; var conteo_lipidos: int = 0; var conteo_peptidos: int = 0; var conteo_ribozimas: int = 0
	for sim in secuencia:
		var sim_str: String = str(sim)
		if MACROMOLECULAS.has(sim_str):
			# LA IMPRONTA QUÍMICA DE FASE 1 AFECTA A LA FASE 2
			integridad += float(MACROMOLECULAS[sim_str]["integridad"]) * float(impronta_quimica["densidad_masa"])
			info += float(MACROMOLECULAS[sim_str]["info"]) * float(impronta_quimica["potencial_accion"])
			match sim_str:
				"Lípido": conteo_lipidos += 1
				"Péptido": conteo_peptidos += 1
				"Ribozima": conteo_ribozimas += 1
			
	var viable: bool = integridad >= 50.0 and info >= 40.0
	return {
		"es_viable": viable, "masa_celular": integridad + info,
		"stats_3d": {"integridad_membrana": integridad, "velocidad_ciliar": (20.0 + (conteo_peptidos * 15.0)) * float(impronta_quimica["eficiencia_atp"]), "radio_celular": 1.0 + (conteo_lipidos * 0.2), "procesamiento_info": info},
		"motivo_fallo": "Lisis. Falta Lípido o ARN." if not viable else "",
		"fenotipo_visual": {"cantidad_flagelos": conteo_peptidos, "brillo_enzimatico": conteo_ribozimas * 0.5, "color_membrana": Color(0.2 + (conteo_lipidos * 0.05), 0.7, 0.5 - (conteo_peptidos * 0.05))}
	}

func procesar_organismo(secuencia: Array) -> Dictionary:
	var fenotipo: Dictionary = {"es_viable": false, "motivo_fallo": "", "masa_total": 0.0, "stats_3d": {"salud": 0.0, "energia_reserva": 0.0, "fuerza_motriz": 0.0, "complejidad_neural": 0.0}}
	var layout_thiessen: Array = []; var offset_z: float = 0.0

	for celula in secuencia:
		var cel_str: String = str(celula)
		if not TIPOS_CELULARES.has(cel_str): continue
		var c: Dictionary = TIPOS_CELULARES[cel_str]
		
		# HERENCIA HASTA FASE 4
		fenotipo["masa_total"] += float(c["costo_atp"])
		fenotipo["stats_3d"]["salud"] += float(c["defensa"]) * float(impronta_quimica["densidad_masa"])
		fenotipo["stats_3d"]["energia_reserva"] += float(c["energia"]) * float(impronta_quimica["eficiencia_atp"])
		fenotipo["stats_3d"]["fuerza_motriz"] += (float(c["control"]) if str(c["rol"]) == "motor" else 0.0) * float(impronta_quimica["eficiencia_atp"])
		fenotipo["stats_3d"]["complejidad_neural"] += (float(c["control"]) if str(c["rol"]) == "nervioso" else 0.0) * float(impronta_quimica["potencial_accion"])
		
		var vector_semilla: Vector3 = Vector3.ZERO
		match str(c["rol"]):
			"cobertura": vector_semilla = Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 0.5), offset_z) 
			"motor": vector_semilla = Vector3(randf_range(0.8, 1.5) * (1.0 if randf() > 0.5 else -1.0), 0.0, offset_z) 
			"nervioso": vector_semilla = Vector3(0.0, 0.0, offset_z) 
			"reserva": vector_semilla = Vector3(0.0, -0.8, offset_z) 
			
		layout_thiessen.append({"tipo": cel_str, "posicion_semilla": vector_semilla}); offset_z += 1.0

	fenotipo["es_viable"] = true 
	fenotipo["fenotipo_visual"] = {"semillas_voronoi": layout_thiessen, "longitud_eje": offset_z}
	return fenotipo

func transducir_morfogenesis_a_cartas(metricas_desarrollo: Dictionary) -> void:
	var nuevo_mazo: Array = []
	var asimetria: float = float(metricas_desarrollo.get("asimetria_torque", 0.0))
	var depredacion: int = int(metricas_desarrollo.get("plancton_devorado", 0))
	var tiempo_vida: float = float(metricas_desarrollo.get("tiempo_supervivencia", 0.0))
	var modo_social: String = str(metricas_desarrollo.get("organizacion", "Sésil"))
	var parasitismo: float = float(metricas_desarrollo.get("dano_parasitario", 0.0))
	
	for i in range(clampi(1 + int(tiempo_vida / 30.0) + int(parasitismo / 50.0), 1, 5)): nuevo_mazo.append("Epitelio")
	for i in range(clampi(int(depredacion / 5), 1, 6)): nuevo_mazo.append("Miocito")
	var cuotas_neuronas: int = 1 + (3 if modo_social == "Manada" else 0) + (2 if asimetria > 0.15 else 0)
	for i in range(clampi(cuotas_neuronas, 1, 5)): nuevo_mazo.append("Neurona")
	if depredacion > 15: nuevo_mazo.append("Adipocito"); nuevo_mazo.append("Adipocito")
	
	nuevo_mazo.shuffle()
	var snapshot: Dictionary = {"secuencia": nuevo_mazo, "fenotipo": {"stats_3d": procesar_organismo(nuevo_mazo).get("stats_3d", {})}}
	mazo_genetico.append(snapshot)
	registro_fosil.append({"era": "Gen_" + str(registro_fosil.size() + 1), "genotipo": nuevo_mazo.duplicate()})
