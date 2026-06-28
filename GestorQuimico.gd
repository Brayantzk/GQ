extends Node

# ==============================================================================
# GESTOR QUÍMICO Y EVOLUTIVO (V10.0 - PARADIGMA DE MORFOGÉNESIS INVERSA)
# El comportamiento físico y ecológico compila el mazo de cartas genéticas.
# ==============================================================================

var mazo_genetico: Array = []
var fase_evolutiva_actual: int = 4
var registro_fosil: Array = [] 

var bonos_ancestrales = {
	"capacidad_energetica": 1.0,
	"resistencia_estructural": 1.0,
	"eficiencia_catalitica": 1.0
}

var rutas_fases: Dictionary = {
	0: "res://archivo_cosmico.tscn",
	1: "res://fase_1_caldo.tscn",
	2: "res://fase_2_metabolismo.tscn",
	3: "res://fase_3_conjugacion.tscn",
	4: "res://fase_4_morfogenesis.tscn"
}

var TABLA_PERIODICA = {
	"H":  {"masa": 1.008, "valencia": 1, "electronegatividad": 2.20, "energia": 15.0, "mutageno": 0.01, "abundancia": 739000.0, "rol": "base"},
	"He": {"masa": 4.002, "valencia": 0, "electronegatividad": 0.00, "energia": 5.0,  "mutageno": 0.00, "abundancia": 240000.0, "rol": "inerte"},
	"Li": {"masa": 6.94,  "valencia": 1, "electronegatividad": 0.98, "energia": 18.0, "mutageno": 0.02, "abundancia": 0.006,  "rol": "catalizador"},
	"Be": {"masa": 9.012, "valencia": 2, "electronegatividad": 1.57, "energia": 20.0, "mutageno": 0.05, "abundancia": 0.0001, "rol": "estructural_pesado"},
	"B":  {"masa": 10.81, "valencia": 3, "electronegatividad": 2.04, "energia": 35.0, "mutageno": 0.03, "abundancia": 0.001,  "rol": "estructural"},
	"C":  {"masa": 12.01, "valencia": 4, "electronegatividad": 2.55, "energia": 50.0, "mutageno": 0.02, "abundancia": 4600.0, "rol": "estructural"},
	"N":  {"masa": 14.01, "valencia": 3, "electronegatividad": 3.04, "energia": 40.0, "mutageno": 0.03, "abundancia": 960.0,  "rol": "reactivo"},
	"O":  {"masa": 16.00, "valencia": 2, "electronegatividad": 3.44, "energia": 30.0, "mutageno": 0.05, "abundancia": 10400.0,"rol": "oxidante"},
	"P":  {"masa": 30.97, "valencia": 5, "electronegatividad": 2.19, "energia": 120.0,"mutageno": 0.08, "abundancia": 7.0,    "rol": "energia"},
	"S":  {"masa": 32.06, "valencia": 2, "electronegatividad": 2.58, "energia": 45.0, "mutageno": 0.06, "abundancia": 440.0,  "rol": "puente"},
	"Db": {"masa": 268.00,"valencia": 5, "electronegatividad": 0.00, "energia": 11000.0,"mutageno": 13.0,"abundancia": 0.0,   "rol": "radiactivo"},
	"Og": {"masa": 294.00,"valencia": 4, "electronegatividad": 0.00, "energia": 50000.0,"mutageno": 0.0, "abundancia": 0.0,   "rol": "comodin"}
}

var TIPOS_CELULARES = {
	"Epitelio": {"costo_atp": 50.0, "defensa": 100.0, "energia": 0.0, "control": 0.0, "rol": "cobertura"},
	"Miocito":  {"costo_atp": 150.0, "defensa": 20.0, "energia": 0.0, "control": 50.0, "rol": "motor"},
	"Neurona":  {"costo_atp": 200.0, "defensa": 5.0,  "energia": 0.0, "control": 150.0, "rol": "nervioso"},
	"Adipocito":{"costo_atp": 80.0,  "defensa": 10.0, "energia": 300.0, "control": 0.0, "rol": "reserva"}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func transicionar_escena(indice_escena: int) -> void:
	if rutas_fases.has(indice_escena):
		get_tree().paused = false
		get_tree().change_scene_to_file(rutas_fases[indice_escena])

# ==============================================================================
# MOTOR DE TRANSDUCCIÓN MORFOGENÉTICA INVERSA
# Traduce el comportamiento de la Fase 4 en el mazo de cartas de la siguiente generación
# ==============================================================================
func transducir_morfogenesis_a_cartas(metricas_desarrollo: Dictionary) -> void:
	var nuevo_mazo: Array = []
	
	# Extraer vectores de rendimiento real de las físicas de la Fase 4
	var asimetria: float = float(metricas_desarrollo.get("asimetria_torque", 0.0))
	var depredacion: int = int(metricas_desarrollo.get("plancton_devorado", 0))
	var tiempo_vida: float = float(metricas_desarrollo.get("tiempo_supervivencia", 0.0))
	var modo_social: String = str(metricas_desarrollo.get("organizacion", "Sésil"))
	
	# 1. Presión Epitelial (Si sufrió colisiones o el tiempo de vida fue alto, genera defensas)
	var cuotas_epitelio: int = 1 + int(tiempo_vida / 30.0)
	for i in range(clampi(cuotas_epitelio, 1, 4)):
		nuevo_mazo.append("Epitelio")
		
	# 2. Presión de Miocitos (Si cazó activamente plancton, premia el aparato motor)
	var cuotas_miocitos: int = int(depredacion / 5)
	for i in range(clampi(cuotas_miocitos, 1, 5)):
		nuevo_mazo.append("Miocito")
		
	# 3. Presión Neuronal (El modo social o la alta asimetría exigen control computacional)
	var cuotas_neuronas: int = 1
	if modo_social == "Manada":
		cuotas_neuronas += 3 # Desbloqueo generacional por comportamiento colectivo
	if asimetria > 0.1:
		cuotas_neuronas += 1 # Presión correctiva para el torque asimétrico
	for i in range(clampi(cuotas_neuronas, 1, 4)):
		nuevo_mazo.append("Neurona")
		
	# 4. Presión de Reserva (Adipocitos generados si la eficiencia energética fue positiva)
	if depredacion > 10:
		nuevo_mazo.append("Adipocito")
		nuevo_mazo.append("Adipocito")

	# Mezclar el mazo sintetizado de forma biológicamente estocástica
	nuevo_mazo.shuffle()
	
	# Registrar en la memoria evolutiva del Rizoma
	var snapshot_generacional = {
		"secuencia": nuevo_mazo,
		"fenotipo": {
			"stats_3d": procesar_organismo(nuevo_mazo).get("stats_3d", {})
		}
	}
	mazo_genetico.append(snapshot_generacional)
	
	# Almacenar en el registro fósil de convergencia
	registro_fosil.append({
		"era": "Proterozoico_Gen_" + str(registro_fosil.size() + 1),
		"genotipo": nuevo_mazo.duplicate()
	})

func procesar_organismo(secuencia: Array) -> Dictionary:
	var fenotipo = {"es_viable": false, "motivo_fallo": "", "masa_total": 0.0, "stats_3d": {"salud": 0.0, "energia_reserva": 0.0, "fuerza_motriz": 0.0, "complejidad_neural": 0.0}}
	var conteo = {"cobertura": 0, "motor": 0, "nervioso": 0, "reserva": 0}

	for celula in secuencia:
		if not TIPOS_CELULARES.has(celula): continue
		var c = TIPOS_CELULARES[celula]
		fenotipo["masa_total"] += c["costo_atp"]
		fenotipo["stats_3d"]["salud"] += c["defensa"]
		fenotipo["stats_3d"]["energia_reserva"] += c["energia"]
		fenotipo["stats_3d"]["fuerza_motriz"] += c["control"] if c["rol"] == "motor" else 0
		fenotipo["stats_3d"]["complejidad_neural"] += c["control"] if c["rol"] == "nervioso" else 0
		conteo[c["rol"]] += 1

	fenotipo["es_viable"] = true
	fenotipo["stats_3d"]["energia_reserva"] = max(fenotipo["stats_3d"]["energia_reserva"], 100.0) * bonos_ancestrales["capacidad_energetica"]
	fenotipo["stats_3d"]["fuerza_motriz"] *= bonos_ancestrales["eficiencia_catalitica"]
	return fenotipo
