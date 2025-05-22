let safe_Mode_ref: Ref[Bool] = Ref::new(false)

pub fn is_safe_mode() -> Bool {
  return safe_Mode_ref.val
}

pub fn set_safe_mode(val: Bool) -> Unit {
  safe_Mode_ref.val = val
}


