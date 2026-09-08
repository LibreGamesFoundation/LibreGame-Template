extends HBoxContainer
## A single row in a keybind remapping list: shows an action's display name,
## its currently bound input, and a button to trigger rebinding.
##
## Instantiated per-action by SettingsContainer via [method setup]. Communicates
## upward only via [signal rebind_requested] — this script has no knowledge of
## SettingsManager or how rebinding actually happens.

signal rebind_requested(action : StringName)

@export var action_label : Label
@export var binding_label : Label
@export var rebind_button : Button

## Text shown on [member rebind_button] while waiting for the next input.
@export var listening_text : String = "Press any key..."

var action : StringName


func _ready() -> void:
	rebind_button.pressed.connect(_on_rebind_button_pressed)

#----------------#
# Public Methods #
#----------------#

## Initializes this row for [param action], displaying [param binding_text] as the
## current binding. Called once by whatever populates the keybind list.
func setup(new_action : StringName, binding_text : String) -> void:
	action = new_action
	action_label.text = _to_display_name(action)
	binding_label.text = binding_text


## Updates the displayed binding text (e.g. after a successful rebind) and resets
## the button label back to normal, in case this row was mid-listen.
func refresh(binding_text : String) -> void:
	binding_label.text = binding_text
	rebind_button.text = "Rebind"


## Puts this row's button into a "listening for input" visual state. Call this
## from the owner once [signal rebind_requested] has actually started listening,
## so the row reflects it's the one currently capturing input.
func set_listening(is_listening : bool) -> void:
	rebind_button.text = listening_text if is_listening else "Rebind"
	rebind_button.disabled = is_listening

#-----------------#
# Private Methods #
#-----------------#

func _on_rebind_button_pressed() -> void:
	rebind_requested.emit(action)


func _to_display_name(raw_action : StringName) -> String:
	# "move_forward" -> "Move Forward"
	var words := String(raw_action).split("_")
	for i in words.size():
		words[i] = words[i].capitalize()
	return " ".join(words)
