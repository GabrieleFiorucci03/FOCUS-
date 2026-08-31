# FOCUS! — il tempo di concentrazione diventa una città.
# Copyright (C) 2026 Gabriele Fiorucci
#
# Questo programma è software libero: puoi ridistribuirlo e/o modificarlo
# secondo i termini della GNU General Public License come pubblicata dalla
# Free Software Foundation, nella versione 3 della Licenza o (a tua scelta)
# in una versione successiva.
#
# Questo programma è distribuito nella speranza che sia utile, ma SENZA ALCUNA
# GARANZIA; senza neppure la garanzia implicita di COMMERCIABILITÀ o IDONEITÀ
# PER UNO SCOPO PARTICOLARE. Vedi la GNU General Public License per i dettagli.
#
# Dovresti aver ricevuto una copia della GNU General Public License insieme a
# questo programma. In caso contrario, vedi <https://www.gnu.org/licenses/>.

class_name IsoCamera
extends Node3D
## Camera ortografica isometrica: ruota a scatti di 90° sui quattro lati,
## si sposta con WASD o trascinando, e zooma con la rotella.
##
## La gerarchia è un braccio snodato: questo nodo è il punto guardato e gira
## sull'asse Y, il figlio "Braccio" inclina, la Camera3D sta in fondo al braccio.
## Così ruotare la vista non tocca mai la posizione della camera, che resta
## sempre puntata al pivot.

## Inclinazione della vista. 35.264° dà l'isometrica esatta; qualche grado in
## più fa vedere meglio i tetti e regge meglio gli edifici alti.
const INCLINAZIONE := 38.0
## Distanza della camera dal pivot. In proiezione ortografica non cambia la
## dimensione di quello che si vede, serve solo a non tagliare gli edifici alti.
const BRACCIO := 120.0
const ZOOM_MIN := 8.0
const ZOOM_MAX := 90.0
const ZOOM_INIZIALE := 34.0
const ZOOM_PASSO := 1.12
const DURATA_ROTAZIONE := 0.28

## Quanto scorre la vista con la tastiera, in schermate al secondo. La velocità
## sta sullo zoom e non sui metri: da vicino si va piano e da lontano in fretta,
## così il movimento sullo schermo sembra sempre lo stesso.
const SCORRIMENTO := 1.0
## Con lo Shift si attraversa la mappa senza aspettare.
const SCORRIMENTO_CORSA := 2.5

## I tasti che spostano la vista, e da che parte la spostano nello spazio della
## camera: -Z è verso il fondo dello schermo. Le frecce fanno le stesse cose,
## per chi tiene la mano sulla destra della tastiera.
const SCORRIMENTI := {
	KEY_W: Vector2(0, -1), KEY_UP: Vector2(0, -1),
	KEY_S: Vector2(0, 1), KEY_DOWN: Vector2(0, 1),
	KEY_A: Vector2(-1, 0), KEY_LEFT: Vector2(-1, 0),
	KEY_D: Vector2(1, 0), KEY_RIGHT: Vector2(1, 0),
}
## Trascinando, il mondo segue il cursore. Metti false se preferisci il contrario.
const TRASCINA_IL_MONDO := true

signal ruotata(gradi: float)

@onready var _braccio: Node3D = $Braccio
@onready var _camera: Camera3D = $Braccio/Camera3D

var _imbardata: float = 45.0
var _tween: Tween
var _trascinamento := false


func _ready() -> void:
	rotation_degrees = Vector3(0.0, _imbardata, 0.0)
	_braccio.rotation_degrees = Vector3(-INCLINAZIONE, 0.0, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ZOOM_INIZIALE
	_camera.near = 0.1
	_camera.far = 500.0
	_camera.position = Vector3(0.0, 0.0, BRACCIO)


## Scorrere con la tastiera è un movimento continuo, non un evento: si guarda
## quali tasti sono giù a ogni frame. Quando il menu sta davanti alla città il
## suo `process_mode` spegne tutto il sottoalbero, quindi qui non serve
## chiedersi se la vista è quella buona: se questo _process gira, lo è.
func _process(delta: float) -> void:
	var direzione := Vector2.ZERO
	for tasto in SCORRIMENTI:
		if Input.is_physical_key_pressed(tasto):
			direzione += SCORRIMENTI[tasto]
	if direzione == Vector2.ZERO:
		return
	direzione = direzione.normalized()
	var velocita := SCORRIMENTO_CORSA if Input.is_key_pressed(KEY_SHIFT) else SCORRIMENTO
	var passo := _camera.size * velocita * delta
	# Stessa correzione del trascinamento: la camera guarda il piano di sbieco,
	# quindi un metro in profondità sullo schermo si vede accorciato. Senza,
	# avanti e indietro andrebbero più piano che destra e sinistra.
	var profondita := direzione.y * passo / sin(deg_to_rad(INCLINAZIONE))
	var base := Basis(Vector3.UP, rotation.y)
	global_position += base * Vector3(direzione.x * passo, 0.0, profondita)


## Ruota di 90°: verso 1 in senso orario, -1 antiorario.
##
## L'angolo si accumula invece di essere riportato in [0, 360): così la
## transizione prende sempre la strada corta e non fa il giro lungo passando
## da 315° a 45°.
func ruota(verso: int) -> void:
	_imbardata += 90.0 * signf(verso)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees:y", _imbardata, DURATA_ROTAZIONE)
	ruotata.emit(_imbardata)


func inquadra(punto: Vector3) -> void:
	global_position = punto


## Da dove parte, in coordinate di mondo, il raggio che passa per un punto
## dello schermo. In proiezione ortografica è un punto sul piano vicino, non la
## posizione della camera: due pixel diversi danno due origini diverse.
func origine_raggio(punto_schermo: Vector2) -> Vector3:
	return _camera.project_ray_origin(punto_schermo)


func direzione_raggio(punto_schermo: Vector2) -> Vector3:
	return _camera.project_ray_normal(punto_schermo)


## Dove finisce sullo schermo un punto del mondo. Serve a chi disegna cartelli
## in mezzo alla scena e poi vuole sapere se il mouse li ha presi.
func punto_schermo(mondo: Vector3) -> Vector2:
	return _camera.unproject_position(mondo)


## Se un punto sta dietro alla camera: lì unproject_position restituisce
## coordinate che sembrano buone e non lo sono.
func dietro(mondo: Vector3) -> bool:
	return _camera.is_position_behind(mondo)


func zoom() -> float:
	return _camera.size


func imposta_zoom(metri: float) -> void:
	_camera.size = clampf(metri, ZOOM_MIN, ZOOM_MAX)


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var tasto := evento as InputEventMouseButton
		match tasto.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zooma(1.0 / ZOOM_PASSO)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zooma(ZOOM_PASSO)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_trascinamento = tasto.pressed
	elif evento is InputEventMouseMotion and _trascinamento:
		_sposta((evento as InputEventMouseMotion).relative)
	elif evento is InputEventKey:
		var tasto_k := evento as InputEventKey
		if tasto_k.pressed and not tasto_k.echo:
			match tasto_k.physical_keycode:
				KEY_Q:
					ruota(-1)
				KEY_E:
					ruota(1)


func _zooma(fattore: float) -> void:
	_camera.size = clampf(_camera.size * fattore, ZOOM_MIN, ZOOM_MAX)


## Converte lo spostamento del mouse in metri sul piano del terreno.
##
## Il piano è orizzontale e la camera lo guarda di sbieco, quindi un pixel
## verticale copre più mondo di un pixel orizzontale: di 1/sin(inclinazione).
## Senza questa correzione il trascinamento sembra scivolare.
func _sposta(delta_mouse: Vector2) -> void:
	var altezza_viewport := float(get_viewport().get_visible_rect().size.y)
	var metri_per_pixel := _camera.size / maxf(1.0, altezza_viewport)
	var verso := -1.0 if TRASCINA_IL_MONDO else 1.0
	var lato := verso * delta_mouse.x * metri_per_pixel
	var profondita := verso * delta_mouse.y * metri_per_pixel / sin(deg_to_rad(INCLINAZIONE))
	# Lo spostamento è nello spazio della camera, quindi va ruotato con l'imbardata.
	var base := Basis(Vector3.UP, rotation.y)
	global_position += base * Vector3(lato, 0.0, profondita)
