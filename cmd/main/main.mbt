///|
fn main {
  // Example: Create a simple FlatBuffer with a table containing name and age
  let builder = @lib.Builder::new()

  // Create a string first (must be created before the table)
  let name_offset = builder.create_string("Alice")

  // Start building a table with 2 fields
  builder.start_object(2)
  builder.add_offset(0, name_offset) // Field 0: name (string)
  builder.add_int32(1, 30, 0) // Field 1: age (int32, default 0)
  let person = builder.end_object()

  // Finish the buffer with root table
  builder.finish(person)

  // Get the serialized bytes
  let bytes = builder.to_bytes()
  println("FlatBuffer size: \{bytes.length()} bytes")

  // Read it back
  let buf = @lib.ByteBuffer::from_bytes(bytes)
  let root = @lib.Table::get_root(buf)
  let name = root.get_string(0, "")
  let age = root.get_int32(1, 0)
  println("Name: \{name}")
  println("Age: \{age}")
}
