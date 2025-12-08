// ignore_for_file: constant_identifier_names

enum TriggerType {
  onCreate,
  onUpdate,
  onDelete,
  onClear,

  onIterate,

  metadataRead,
  metadataWrite,
  valueRead,
  valueWrite,

  custom,

  boxOpen,
  boxClose,

  onValueSerialize,
  onValueDeserialize,

  onValueTSerialize,
  onValueTDeserialize,

  onMetaSerialize,
  onMetaDeserialize,

  onMetaTSerialize,
  onMetaTDeserialize,
}

enum NextPhase { f_continue, f_skip, f_break, f_panic, f_delete, f_pop }

enum Action { x_get, x_put, x_delete, x_clear, x_iterate }
