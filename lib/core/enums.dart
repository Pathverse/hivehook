// ignore_for_file: constant_identifier_names

/// Events that can trigger hooks during database operations.
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

/// Control flow actions for hooks via HHCtrlException.
enum NextPhase { f_continue, f_skip, f_break, f_panic, f_delete, f_pop }

/// Database operation types.
enum Action { x_get, x_put, x_delete, x_clear, x_iterate }
