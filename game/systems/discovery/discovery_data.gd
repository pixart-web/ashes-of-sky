class_name DiscoveryData
extends Resource

enum Category {
  REGION,
  LANDMARK,
  LOST_PLACE,
  ECHO,
  ANOMALY,
}

@export var discovery_id: StringName
@export var display_name: String
@export var category: Category = Category.REGION
@export_multiline var short_description: String
@export_multiline var recovered_text: String


func is_valid() -> bool:
  return not discovery_id.is_empty() and not display_name.is_empty()


func category_title() -> String:
  match category:
    Category.REGION:
      return "REGIONS"
    Category.LANDMARK:
      return "LANDMARKS"
    Category.LOST_PLACE:
      return "LOST PLACES"
    Category.ECHO:
      return "ECHOES"
    Category.ANOMALY:
      return "ANOMALIES"
  return "DISCOVERIES"


func presentation_label() -> String:
  match category:
    Category.REGION:
      return "REGION DISCOVERED"
    Category.LANDMARK:
      return "LANDMARK DISCOVERED"
    Category.LOST_PLACE:
      return "LOST PLACE DISCOVERED"
    Category.ECHO:
      return "ECHO RECOVERED"
    Category.ANOMALY:
      return "ANOMALY DETECTED"
  return "DISCOVERED"
