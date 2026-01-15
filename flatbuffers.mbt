///|
/// FlatBuffers for MoonBit
/// A pure MoonBit implementation of Google FlatBuffers binary serialization format.

///|
/// Size constants for FlatBuffers offset types
let size_uoffset : Int = 4 // UOffsetT: unsigned 32-bit offset

///|
let size_soffset : Int = 4 // SOffsetT: signed 32-bit offset

///|
let size_voffset : Int = 2 // VOffsetT: unsigned 16-bit vtable offset

///|
/// ByteBuffer provides read access to a FlatBuffer binary.
/// All multi-byte values are stored in little-endian format.
pub struct ByteBuffer {
  data : FixedArray[Byte]
  pos : Int
}

///|
/// Create a new ByteBuffer from bytes
pub fn ByteBuffer::new(data : FixedArray[Byte]) -> ByteBuffer {
  { data, pos: 0 }
}

///|
/// Create a ByteBuffer from a Bytes object
pub fn ByteBuffer::from_bytes(bytes : Bytes) -> ByteBuffer {
  ByteBuffer::new(bytes.to_fixedarray())
}

///|
/// Get the underlying data length
pub fn ByteBuffer::length(self : ByteBuffer) -> Int {
  self.data.length()
}

///|
/// Get a byte at the given offset
pub fn ByteBuffer::get_byte(self : ByteBuffer, offset : Int) -> Byte {
  self.data[offset]
}

///|
/// Read a UInt8 (unsigned byte) at offset
pub fn ByteBuffer::read_uint8(self : ByteBuffer, offset : Int) -> Int {
  self.data[offset].to_int()
}

///|
/// Read an Int8 (signed byte) at offset
pub fn ByteBuffer::read_int8(self : ByteBuffer, offset : Int) -> Int {
  let b = self.data[offset].to_int()
  if b >= 128 {
    b - 256
  } else {
    b
  }
}

///|
/// Read a UInt16 (little-endian) at offset
pub fn ByteBuffer::read_uint16(self : ByteBuffer, offset : Int) -> Int {
  let b0 = self.data[offset].to_int()
  let b1 = self.data[offset + 1].to_int()
  b0 | (b1 << 8)
}

///|
/// Read an Int16 (little-endian) at offset
pub fn ByteBuffer::read_int16(self : ByteBuffer, offset : Int) -> Int {
  let u = self.read_uint16(offset)
  if u >= 32768 {
    u - 65536
  } else {
    u
  }
}

///|
/// Read a UInt32 (little-endian) at offset
pub fn ByteBuffer::read_uint32(self : ByteBuffer, offset : Int) -> UInt {
  let b0 = self.data[offset].to_uint()
  let b1 = self.data[offset + 1].to_uint()
  let b2 = self.data[offset + 2].to_uint()
  let b3 = self.data[offset + 3].to_uint()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
/// Read an Int32 (little-endian) at offset
pub fn ByteBuffer::read_int32(self : ByteBuffer, offset : Int) -> Int {
  self.read_uint32(offset).reinterpret_as_int()
}

///|
/// Read a UInt64 (little-endian) at offset
pub fn ByteBuffer::read_uint64(self : ByteBuffer, offset : Int) -> UInt64 {
  let b0 = self.data[offset].to_uint64()
  let b1 = self.data[offset + 1].to_uint64()
  let b2 = self.data[offset + 2].to_uint64()
  let b3 = self.data[offset + 3].to_uint64()
  let b4 = self.data[offset + 4].to_uint64()
  let b5 = self.data[offset + 5].to_uint64()
  let b6 = self.data[offset + 6].to_uint64()
  let b7 = self.data[offset + 7].to_uint64()
  b0 |
  (b1 << 8) |
  (b2 << 16) |
  (b3 << 24) |
  (b4 << 32) |
  (b5 << 40) |
  (b6 << 48) |
  (b7 << 56)
}

///|
/// Read an Int64 (little-endian) at offset
pub fn ByteBuffer::read_int64(self : ByteBuffer, offset : Int) -> Int64 {
  self.read_uint64(offset).reinterpret_as_int64()
}

///|
/// Read a Float32 (little-endian) at offset
pub fn ByteBuffer::read_float32(self : ByteBuffer, offset : Int) -> Float {
  let bits = self.read_uint32(offset)
  Float::reinterpret_from_uint(bits)
}

///|
/// Read a Float64/Double (little-endian) at offset
pub fn ByteBuffer::read_float64(self : ByteBuffer, offset : Int) -> Double {
  let bits = self.read_uint64(offset)
  bits.reinterpret_as_double()
}

///|
/// Read a string at offset (FlatBuffer string format: length + UTF-8 data)
pub fn ByteBuffer::read_string(self : ByteBuffer, offset : Int) -> String {
  let len = self.read_uint32(offset).reinterpret_as_int()
  let start = offset + size_uoffset
  let bytes = FixedArray::makei(len, fn(i) { self.data[start + i] })
  @utf8.decode_lossy(Bytes::from_array(bytes[:])[:])
}

///|
/// Get the root table offset from the buffer start
pub fn ByteBuffer::get_root_offset(self : ByteBuffer) -> Int {
  self.read_uint32(0).reinterpret_as_int()
}

///|
/// Builder is used to construct FlatBuffers.
/// Data is written backwards from the end of the buffer.
pub struct Builder {
  mut buf : FixedArray[Byte]
  mut head : Int // Current write position (from end)
  mut minalign : Int // Minimum alignment encountered
  mut vtable : Array[Int] // Current vtable being built
  mut object_start : Int // Start of current object
  vtables : Array[Int] // All finished vtables for deduplication
  mut nested : Bool // Whether we're in a nested object
  mut finished : Bool // Whether buffer is finished
  mut force_defaults : Bool // Whether to serialize default values
  string_cache : Map[String, Int] // Cache for shared strings
}

///|
/// Create a new Builder with initial capacity
pub fn Builder::new(initial_size? : Int = 256) -> Builder {
  {
    buf: FixedArray::make(initial_size, b'\x00'),
    head: initial_size,
    minalign: 1,
    vtable: [],
    object_start: 0,
    vtables: [],
    nested: false,
    finished: false,
    force_defaults: false,
    string_cache: {},
  }
}

///|
/// Set whether to force serialization of default values.
/// When true, fields are written even if they equal the default value.
/// This is useful for debugging or when you need to see all fields.
pub fn Builder::set_force_defaults(self : Builder, force : Bool) -> Unit {
  self.force_defaults = force
}

///|
/// Get the current force_defaults setting
pub fn Builder::get_force_defaults(self : Builder) -> Bool {
  self.force_defaults
}

///|
/// Get current offset from the end of the buffer
pub fn Builder::offset(self : Builder) -> Int {
  self.buf.length() - self.head
}

///|
/// Grow the buffer if necessary to accommodate additional bytes
fn Builder::grow(self : Builder, additional : Int) -> Unit {
  let needed = self.offset() + additional
  if self.buf.length() < needed {
    let new_size = @cmp.maximum(self.buf.length() * 2, needed)
    let new_buf : FixedArray[Byte] = FixedArray::make(new_size, b'\x00')
    let old_len = self.buf.length()
    let new_len = new_buf.length()
    // Copy old data to end of new buffer
    for i = 0; i < old_len - self.head; i = i + 1 {
      new_buf[new_len - 1 - i] = self.buf[old_len - 1 - i]
    }
    self.head = new_len - (old_len - self.head)
    self.buf = new_buf
  }
}

///|
/// Pad the buffer with zeros for alignment
fn Builder::pad(self : Builder, n : Int) -> Unit {
  for i = 0; i < n; i = i + 1 {
    self.head = self.head - 1
    self.buf[self.head] = b'\x00'
  }
}

///|
/// Prepare to write data with alignment
pub fn Builder::prep(self : Builder, size : Int, additional : Int) -> Unit {
  if size > self.minalign {
    self.minalign = size
  }
  let align_size = (
      (self.buf.length() - self.head + additional).lnot() & (size - 1)
    ) +
    1
  let align_size = if align_size == size { 0 } else { align_size }
  self.grow(align_size + size + additional)
  self.pad(align_size)
}

///|
/// Write a byte at current position
pub fn Builder::write_byte(self : Builder, val : Byte) -> Unit {
  self.head = self.head - 1
  self.buf[self.head] = val
}

///|
/// Write a UInt8
pub fn Builder::write_uint8(self : Builder, val : Int) -> Unit {
  self.prep(1, 0)
  self.write_byte(val.to_byte())
}

///|
/// Write an Int8
pub fn Builder::write_int8(self : Builder, val : Int) -> Unit {
  self.prep(1, 0)
  self.write_byte(val.to_byte())
}

///|
/// Write a UInt16 (little-endian)
pub fn Builder::write_uint16(self : Builder, val : Int) -> Unit {
  self.prep(2, 0)
  self.head = self.head - 2
  self.buf.unsafe_write_uint16_le(self.head, val.to_uint16())
}

///|
/// Write an Int16 (little-endian)
pub fn Builder::write_int16(self : Builder, val : Int) -> Unit {
  self.write_uint16(val)
}

///|
/// Write a UInt32 (little-endian)
pub fn Builder::write_uint32(self : Builder, val : UInt) -> Unit {
  self.prep(4, 0)
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val)
}

///|
/// Write an Int32 (little-endian)
pub fn Builder::write_int32(self : Builder, val : Int) -> Unit {
  self.write_uint32(val.reinterpret_as_uint())
}

///|
/// Write a UInt64 (little-endian)
pub fn Builder::write_uint64(self : Builder, val : UInt64) -> Unit {
  self.prep(8, 0)
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val)
}

///|
/// Write an Int64 (little-endian)
pub fn Builder::write_int64(self : Builder, val : Int64) -> Unit {
  self.write_uint64(val.reinterpret_as_uint64())
}

///|
/// Write a Float32 (little-endian)
pub fn Builder::write_float32(self : Builder, val : Float) -> Unit {
  self.write_uint32(val.reinterpret_as_uint())
}

///|
/// Write a Float64/Double (little-endian)
pub fn Builder::write_float64(self : Builder, val : Double) -> Unit {
  self.write_uint64(val.reinterpret_as_uint64())
}

// =============================================================================
// Place methods for struct building (write without prep)
// =============================================================================

///|
/// Place a bool at current position (for struct building)
pub fn Builder::place_bool(self : Builder, val : Bool) -> Unit {
  self.head = self.head - 1
  self.buf[self.head] = if val { b'\x01' } else { b'\x00' }
}

///|
/// Place an Int8 at current position (for struct building)
pub fn Builder::place_int8(self : Builder, val : Int) -> Unit {
  self.head = self.head - 1
  self.buf[self.head] = val.to_byte()
}

///|
/// Place a UInt8 at current position (for struct building)
pub fn Builder::place_uint8(self : Builder, val : Int) -> Unit {
  self.head = self.head - 1
  self.buf[self.head] = val.to_byte()
}

///|
/// Place an Int16 at current position (for struct building)
pub fn Builder::place_int16(self : Builder, val : Int) -> Unit {
  self.head = self.head - 2
  self.buf.unsafe_write_uint16_le(self.head, val.to_uint16())
}

///|
/// Place a UInt16 at current position (for struct building)
pub fn Builder::place_uint16(self : Builder, val : Int) -> Unit {
  self.head = self.head - 2
  self.buf.unsafe_write_uint16_le(self.head, val.to_uint16())
}

///|
/// Place an Int32 at current position (for struct building)
pub fn Builder::place_int32(self : Builder, val : Int) -> Unit {
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val.reinterpret_as_uint())
}

///|
/// Place a UInt32 at current position (for struct building)
pub fn Builder::place_uint32(self : Builder, val : UInt) -> Unit {
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val)
}

///|
/// Place an Int64 at current position (for struct building)
pub fn Builder::place_int64(self : Builder, val : Int64) -> Unit {
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val.reinterpret_as_uint64())
}

///|
/// Place a UInt64 at current position (for struct building)
pub fn Builder::place_uint64(self : Builder, val : UInt64) -> Unit {
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val)
}

///|
/// Place a Float32 at current position (for struct building)
pub fn Builder::place_float32(self : Builder, val : Float) -> Unit {
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val.reinterpret_as_uint())
}

///|
/// Place a Float64 at current position (for struct building)
pub fn Builder::place_float64(self : Builder, val : Double) -> Unit {
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val.reinterpret_as_uint64())
}

///|
/// Create a string in the buffer
pub fn Builder::create_string(self : Builder, s : String) -> Int {
  let bytes = @utf8.encode(s[:])
  let len = bytes.length()
  // Prepare space for: length (4 bytes) + string data + null terminator
  self.prep(size_uoffset, len + 1)
  // Write null terminator
  self.write_byte(b'\x00')
  // Write string bytes backwards
  for i = len - 1; i >= 0; i = i - 1 {
    self.write_byte(bytes[i])
  }
  // Write length directly without additional prep
  self.head = self.head - size_uoffset
  self.buf.unsafe_write_uint32_le(self.head, len.reinterpret_as_uint())
  self.offset()
}

///|
/// Create a shared string in the buffer.
/// If the same string was already created, returns the existing offset.
/// This reduces buffer size when the same string appears multiple times.
pub fn Builder::create_shared_string(self : Builder, s : String) -> Int {
  // Check cache first
  match self.string_cache.get(s) {
    Some(offset) => offset
    None => {
      let offset = self.create_string(s)
      self.string_cache.set(s, offset)
      offset
    }
  }
}

///|
/// Clear the shared string cache.
/// Call this if you want to create duplicate strings intentionally.
pub fn Builder::clear_string_cache(self : Builder) -> Unit {
  self.string_cache.clear()
}

///|
/// Create a byte vector in the buffer
pub fn Builder::create_byte_vector(
  self : Builder,
  data : FixedArray[Byte],
) -> Int {
  let len = data.length()
  self.prep(size_uoffset, len)
  // Write bytes backwards
  for i = len - 1; i >= 0; i = i - 1 {
    self.write_byte(data[i])
  }
  // Write length
  self.write_uint32(len.reinterpret_as_uint())
  self.offset()
}

///|
/// Start building a new vector
pub fn Builder::start_vector(
  self : Builder,
  elem_size : Int,
  num_elems : Int,
  alignment : Int,
) -> Unit {
  self.prep(size_uoffset, elem_size * num_elems)
  self.prep(alignment, elem_size * num_elems)
}

///|
/// End building a vector
pub fn Builder::end_vector(self : Builder, num_elems : Int) -> Int {
  self.write_uint32(num_elems.reinterpret_as_uint())
  self.offset()
}

///|
/// Start building a new table/object
pub fn Builder::start_object(self : Builder, num_fields : Int) -> Unit {
  guard not(self.nested)
  self.nested = true
  self.vtable = Array::make(num_fields, 0)
  self.object_start = self.offset()
}

///|
/// Record a field slot
pub fn Builder::slot(self : Builder, slot_num : Int) -> Unit {
  self.vtable[slot_num] = self.offset()
}

///|
/// Add a boolean field
pub fn Builder::add_bool(
  self : Builder,
  slot_num : Int,
  val : Bool,
  default : Bool,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_uint8(if val { 1 } else { 0 })
    self.slot(slot_num)
  }
}

///|
/// Add a UInt8 field
pub fn Builder::add_uint8(
  self : Builder,
  slot_num : Int,
  val : Int,
  default : Int,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_uint8(val)
    self.slot(slot_num)
  }
}

///|
/// Add an Int8 field
pub fn Builder::add_int8(
  self : Builder,
  slot_num : Int,
  val : Int,
  default : Int,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_int8(val)
    self.slot(slot_num)
  }
}

///|
/// Add a UInt16 field
pub fn Builder::add_uint16(
  self : Builder,
  slot_num : Int,
  val : Int,
  default : Int,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_uint16(val)
    self.slot(slot_num)
  }
}

///|
/// Add an Int16 field
pub fn Builder::add_int16(
  self : Builder,
  slot_num : Int,
  val : Int,
  default : Int,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_int16(val)
    self.slot(slot_num)
  }
}

///|
/// Add a UInt32 field
pub fn Builder::add_uint32(
  self : Builder,
  slot_num : Int,
  val : UInt,
  default : UInt,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_uint32(val)
    self.slot(slot_num)
  }
}

///|
/// Add an Int32 field
pub fn Builder::add_int32(
  self : Builder,
  slot_num : Int,
  val : Int,
  default : Int,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_int32(val)
    self.slot(slot_num)
  }
}

///|
/// Add a UInt64 field
pub fn Builder::add_uint64(
  self : Builder,
  slot_num : Int,
  val : UInt64,
  default : UInt64,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_uint64(val)
    self.slot(slot_num)
  }
}

///|
/// Add an Int64 field
pub fn Builder::add_int64(
  self : Builder,
  slot_num : Int,
  val : Int64,
  default : Int64,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_int64(val)
    self.slot(slot_num)
  }
}

///|
/// Add a Float32 field
pub fn Builder::add_float32(
  self : Builder,
  slot_num : Int,
  val : Float,
  default : Float,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_float32(val)
    self.slot(slot_num)
  }
}

///|
/// Add a Float64 field
pub fn Builder::add_float64(
  self : Builder,
  slot_num : Int,
  val : Double,
  default : Double,
) -> Unit {
  if self.force_defaults || val != default {
    self.write_float64(val)
    self.slot(slot_num)
  }
}

///|
/// Add an offset field (for strings, vectors, tables)
pub fn Builder::add_offset(self : Builder, slot_num : Int, val : Int) -> Unit {
  if val != 0 {
    self.prep(size_uoffset, 0)
    let relative_offset = self.offset() - val + size_uoffset
    self.head = self.head - size_uoffset
    self.buf.unsafe_write_uint32_le(
      self.head,
      relative_offset.reinterpret_as_uint(),
    )
    self.slot(slot_num)
  }
}

///|
/// Add a struct inline (structs are stored inline, not as offsets)
pub fn Builder::add_struct(self : Builder, slot_num : Int, val : Int) -> Unit {
  if val != 0 {
    self.slot(slot_num)
  }
}

///|
/// End building a table and return its offset
pub fn Builder::end_object(self : Builder) -> Int {
  guard self.nested
  // Write placeholder for vtable offset (soffset, 4 bytes)
  self.write_int32(0)
  let table_end = self.offset()
  // Calculate vtable
  let object_size = table_end - self.object_start
  // Build vtable in memory
  // VTable format: [vtable_size, object_size, field_offsets...]
  let vtable_size = (2 + self.vtable.length()) * size_voffset
  let mut existing_vtable = -1
  // Check for existing vtable (deduplication)
  for vt in self.vtables {
    let vt_offset = self.buf.length() - vt
    let existing_size = self.buf[vt_offset].to_int() |
      (self.buf[vt_offset + 1].to_int() << 8)
    if existing_size == vtable_size {
      let mut match_ = true
      for i = 2; i < vtable_size / size_voffset; i = i + 1 {
        let field_idx = i - 2
        let existing_field = self.buf[vt_offset + i * 2].to_int() |
          (self.buf[vt_offset + i * 2 + 1].to_int() << 8)
        let new_field = if field_idx < self.vtable.length() &&
          self.vtable[field_idx] != 0 {
          table_end - self.vtable[field_idx]
        } else {
          0
        }
        if existing_field != new_field {
          match_ = false
          break
        }
      }
      if match_ {
        existing_vtable = vt
        break
      }
    }
  }
  let table_pos = self.buf.length() - table_end
  if existing_vtable >= 0 {
    // Reuse existing vtable
    // soffset = vtable_offset - table_end (in offset coordinates)
    // This gives a positive value since vtable is written after table
    let soffset = existing_vtable - table_end
    self.buf.unsafe_write_uint32_le(table_pos, soffset.reinterpret_as_uint())
  } else {
    // Write new vtable
    // Write field offsets backwards
    for i = self.vtable.length() - 1; i >= 0; i = i - 1 {
      let off = if self.vtable[i] != 0 { table_end - self.vtable[i] } else { 0 }
      self.head = self.head - size_voffset
      self.buf.unsafe_write_uint16_le(self.head, off.to_uint16())
    }
    // Write object size
    self.head = self.head - size_voffset
    self.buf.unsafe_write_uint16_le(self.head, object_size.to_uint16())
    // Write vtable size
    self.head = self.head - size_voffset
    self.buf.unsafe_write_uint16_le(self.head, vtable_size.to_uint16())
    let vtable_offset = self.offset()
    self.vtables.push(vtable_offset)
    // Write soffset to vtable in table
    // In final buffer: table_pos - vtable_pos = (final.len - table_end) - (final.len - vtable_offset)
    //                = vtable_offset - table_end
    let soffset = vtable_offset - table_end
    self.buf.unsafe_write_uint32_le(table_pos, soffset.reinterpret_as_uint())
  }
  self.nested = false
  self.vtable = []
  table_end
}

///|
/// Finish building the buffer with root table
pub fn Builder::finish(self : Builder, root_table : Int) -> Unit {
  self.prep(self.minalign, size_uoffset)
  let relative_offset = self.offset() - root_table + size_uoffset
  self.head = self.head - size_uoffset
  self.buf.unsafe_write_uint32_le(
    self.head,
    relative_offset.reinterpret_as_uint(),
  )
  self.finished = true
}

///|
/// Get the finished buffer as bytes
pub fn Builder::to_bytes(self : Builder) -> Bytes {
  guard self.finished
  let len = self.buf.length() - self.head
  let result = FixedArray::makei(len, fn(i) { self.buf[self.head + i] })
  Bytes::from_array(result[:])
}

///|
/// Get the finished buffer as FixedArray
pub fn Builder::to_fixed_array(self : Builder) -> FixedArray[Byte] {
  guard self.finished
  let len = self.buf.length() - self.head
  FixedArray::makei(len, fn(i) { self.buf[self.head + i] })
}

///|
/// Table provides read access to a FlatBuffer table.
/// It handles vtable lookups and field access.
pub struct Table {
  buf : ByteBuffer
  pos : Int // Position of this table in the buffer
}

///|
/// Create a Table from a ByteBuffer at the given position
pub fn Table::new(buf : ByteBuffer, pos : Int) -> Table {
  { buf, pos }
}

///|
/// Get the root table from a buffer
pub fn Table::get_root(buf : ByteBuffer) -> Table {
  let root_offset = buf.read_uint32(0).reinterpret_as_int()
  Table::new(buf, root_offset)
}

///|
/// Get the vtable offset for a field
pub fn Table::vtable_offset(self : Table, field : Int) -> Int {
  let vtable_offset = self.pos - self.buf.read_int32(self.pos) // vtable is at pos - soffset
  let vtable_size = self.buf.read_uint16(vtable_offset)
  if field < vtable_size {
    self.buf.read_uint16(vtable_offset + field)
  } else {
    0
  }
}

///|
/// Check if a field is present
pub fn Table::has_field(self : Table, field_slot : Int) -> Bool {
  self.vtable_offset(size_voffset * (2 + field_slot)) != 0
}

///|
/// Get a boolean field
pub fn Table::get_bool(self : Table, field_slot : Int, default : Bool) -> Bool {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_uint8(self.pos + offset) != 0
  } else {
    default
  }
}

///|
/// Get a UInt8 field
pub fn Table::get_uint8(self : Table, field_slot : Int, default : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_uint8(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get an Int8 field
pub fn Table::get_int8(self : Table, field_slot : Int, default : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_int8(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a UInt16 field
pub fn Table::get_uint16(self : Table, field_slot : Int, default : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_uint16(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get an Int16 field
pub fn Table::get_int16(self : Table, field_slot : Int, default : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_int16(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a UInt32 field
pub fn Table::get_uint32(
  self : Table,
  field_slot : Int,
  default : UInt,
) -> UInt {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_uint32(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get an Int32 field
pub fn Table::get_int32(self : Table, field_slot : Int, default : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_int32(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a UInt64 field
pub fn Table::get_uint64(
  self : Table,
  field_slot : Int,
  default : UInt64,
) -> UInt64 {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_uint64(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get an Int64 field
pub fn Table::get_int64(
  self : Table,
  field_slot : Int,
  default : Int64,
) -> Int64 {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_int64(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a Float32 field
pub fn Table::get_float32(
  self : Table,
  field_slot : Int,
  default : Float,
) -> Float {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_float32(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a Float64 field
pub fn Table::get_float64(
  self : Table,
  field_slot : Int,
  default : Double,
) -> Double {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    self.buf.read_float64(self.pos + offset)
  } else {
    default
  }
}

///|
/// Get a string field
pub fn Table::get_string(
  self : Table,
  field_slot : Int,
  default : String,
) -> String {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    let string_offset = self.pos + offset
    let indirect = self.buf.read_uint32(string_offset).reinterpret_as_int()
    self.buf.read_string(string_offset + indirect)
  } else {
    default
  }
}

///|
/// Get the offset to a nested table field
pub fn Table::get_table_offset(self : Table, field_slot : Int) -> Int? {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    let table_offset = self.pos + offset
    let indirect = self.buf.read_uint32(table_offset).reinterpret_as_int()
    Some(table_offset + indirect)
  } else {
    None
  }
}

///|
/// Get a nested table field
pub fn Table::get_table(self : Table, field_slot : Int) -> Table? {
  match self.get_table_offset(field_slot) {
    Some(offset) => Some(Table::new(self.buf, offset))
    None => None
  }
}

///|
/// Get a struct field (returns the position in buffer where struct data starts)
pub fn Table::get_struct(self : Table, field_slot : Int) -> Int? {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    Some(self.pos + offset)
  } else {
    None
  }
}

///|
/// Get the vector length for a vector field
pub fn Table::get_vector_length(self : Table, field_slot : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    let vec_offset = self.pos + offset
    let indirect = self.buf.read_uint32(vec_offset).reinterpret_as_int()
    self.buf.read_uint32(vec_offset + indirect).reinterpret_as_int()
  } else {
    0
  }
}

///|
/// Get the start of vector data
pub fn Table::get_vector_start(self : Table, field_slot : Int) -> Int {
  let offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if offset != 0 {
    let vec_offset = self.pos + offset
    let indirect = self.buf.read_uint32(vec_offset).reinterpret_as_int()
    vec_offset + indirect + size_uoffset
  } else {
    0
  }
}

///|
/// Get an Int32 element from a vector
pub fn Table::get_vector_int32(
  self : Table,
  field_slot : Int,
  index : Int,
) -> Int {
  let start = self.get_vector_start(field_slot)
  if start != 0 {
    self.buf.read_int32(start + index * 4)
  } else {
    0
  }
}

///|
/// Get a string element from a vector of strings
pub fn Table::get_vector_string(
  self : Table,
  field_slot : Int,
  index : Int,
) -> String {
  let start = self.get_vector_start(field_slot)
  if start != 0 {
    let elem_offset = start + index * size_uoffset
    let indirect = self.buf.read_uint32(elem_offset).reinterpret_as_int()
    self.buf.read_string(elem_offset + indirect)
  } else {
    ""
  }
}

///|
/// Get a table element from a vector of tables
pub fn Table::get_vector_table(
  self : Table,
  field_slot : Int,
  index : Int,
) -> Table? {
  let start = self.get_vector_start(field_slot)
  if start != 0 {
    let elem_offset = start + index * size_uoffset
    let indirect = self.buf.read_uint32(elem_offset).reinterpret_as_int()
    Some(Table::new(self.buf, elem_offset + indirect))
  } else {
    None
  }
}

///|
/// Get a byte element from a vector
pub fn Table::get_vector_byte(
  self : Table,
  field_slot : Int,
  index : Int,
) -> Byte {
  let start = self.get_vector_start(field_slot)
  if start != 0 {
    self.buf.get_byte(start + index)
  } else {
    b'\x00'
  }
}

///|
/// Get a float64 element from a vector
pub fn Table::get_vector_float64(
  self : Table,
  field_slot : Int,
  index : Int,
) -> Double {
  let start = self.get_vector_start(field_slot)
  if start != 0 {
    self.buf.read_float64(start + index * 8)
  } else {
    0.0
  }
}

// =============================================================================
// Builder: Vector Creation Helpers
// =============================================================================

///|
/// Create a vector of Int32 values
pub fn Builder::create_int32_vector(self : Builder, data : Array[Int]) -> Int {
  let len = data.length()
  self.start_vector(4, len, 4)
  // Write elements backwards
  for i = len - 1; i >= 0; i = i - 1 {
    self.head = self.head - 4
    self.buf.unsafe_write_uint32_le(self.head, data[i].reinterpret_as_uint())
  }
  self.end_vector(len)
}

///|
/// Create a vector of Int64 values
pub fn Builder::create_int64_vector(self : Builder, data : Array[Int64]) -> Int {
  let len = data.length()
  self.start_vector(8, len, 8)
  for i = len - 1; i >= 0; i = i - 1 {
    self.head = self.head - 8
    self.buf.unsafe_write_uint64_le(self.head, data[i].reinterpret_as_uint64())
  }
  self.end_vector(len)
}

///|
/// Create a vector of Float64 (Double) values
pub fn Builder::create_float64_vector(
  self : Builder,
  data : Array[Double],
) -> Int {
  let len = data.length()
  self.start_vector(8, len, 8)
  for i = len - 1; i >= 0; i = i - 1 {
    self.head = self.head - 8
    self.buf.unsafe_write_uint64_le(self.head, data[i].reinterpret_as_uint64())
  }
  self.end_vector(len)
}

///|
/// Create a vector of Bool values
pub fn Builder::create_bool_vector(self : Builder, data : Array[Bool]) -> Int {
  let len = data.length()
  self.start_vector(1, len, 1)
  for i = len - 1; i >= 0; i = i - 1 {
    self.write_byte(if data[i] { b'\x01' } else { b'\x00' })
  }
  self.end_vector(len)
}

///|
/// Create a vector of offsets (for tables/strings that were already created)
pub fn Builder::create_offset_vector(
  self : Builder,
  offsets : Array[Int],
) -> Int {
  let len = offsets.length()
  self.start_vector(size_uoffset, len, size_uoffset)
  // Write offsets backwards, converting to relative offsets
  for i = len - 1; i >= 0; i = i - 1 {
    self.prep(size_uoffset, 0)
    let relative_offset = self.offset() - offsets[i] + size_uoffset
    self.head = self.head - size_uoffset
    self.buf.unsafe_write_uint32_le(
      self.head,
      relative_offset.reinterpret_as_uint(),
    )
  }
  self.end_vector(len)
}

///|
/// Create a vector of strings (convenience method)
pub fn Builder::create_string_vector(
  self : Builder,
  strings : Array[String],
) -> Int {
  // First create all strings
  let offsets : Array[Int] = Array::make(strings.length(), 0)
  for i = strings.length() - 1; i >= 0; i = i - 1 {
    offsets[i] = self.create_string(strings[i])
  }
  // Then create the offset vector
  self.create_offset_vector(offsets)
}

// =============================================================================
// Struct Support
// =============================================================================

///|
/// Prepare to write a struct with the given size and alignment
pub fn Builder::prep_struct(self : Builder, size : Int, alignment : Int) -> Int {
  self.prep(alignment, size)
  self.offset()
}

///|
/// Write a struct's float field (for inline struct building)
pub fn Builder::struct_add_float(self : Builder, val : Float) -> Unit {
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val.reinterpret_as_uint())
}

///|
/// Write a struct's double field
pub fn Builder::struct_add_double(self : Builder, val : Double) -> Unit {
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val.reinterpret_as_uint64())
}

///|
/// Write a struct's int8 field
pub fn Builder::struct_add_int8(self : Builder, val : Int) -> Unit {
  self.head = self.head - 1
  self.buf[self.head] = val.to_byte()
}

///|
/// Write a struct's int16 field
pub fn Builder::struct_add_int16(self : Builder, val : Int) -> Unit {
  self.head = self.head - 2
  self.buf.unsafe_write_uint16_le(self.head, val.to_uint16())
}

///|
/// Write a struct's int32 field
pub fn Builder::struct_add_int32(self : Builder, val : Int) -> Unit {
  self.head = self.head - 4
  self.buf.unsafe_write_uint32_le(self.head, val.reinterpret_as_uint())
}

///|
/// Write a struct's int64 field
pub fn Builder::struct_add_int64(self : Builder, val : Int64) -> Unit {
  self.head = self.head - 8
  self.buf.unsafe_write_uint64_le(self.head, val.reinterpret_as_uint64())
}

///|
/// Pad struct to alignment
pub fn Builder::struct_pad(self : Builder, bytes : Int) -> Unit {
  self.pad(bytes)
}

// =============================================================================
// File Identifier Support
// =============================================================================

///|
/// File identifier size (always 4 bytes)
let file_identifier_size : Int = 4

///|
/// Finish building the buffer with a file identifier
pub fn Builder::finish_with_identifier(
  self : Builder,
  root_table : Int,
  identifier : String,
) -> Unit {
  self.prep(self.minalign, size_uoffset + file_identifier_size)
  // Write file identifier (4 bytes)
  let id_bytes = @utf8.encode(identifier[:])
  for i = file_identifier_size - 1; i >= 0; i = i - 1 {
    if i < id_bytes.length() {
      self.write_byte(id_bytes[i])
    } else {
      self.write_byte(b'\x00')
    }
  }
  // Write root table offset
  let relative_offset = self.offset() - root_table + size_uoffset
  self.head = self.head - size_uoffset
  self.buf.unsafe_write_uint32_le(
    self.head,
    relative_offset.reinterpret_as_uint(),
  )
  self.finished = true
}

///|
/// Check if buffer has a file identifier
pub fn ByteBuffer::has_identifier(
  self : ByteBuffer,
  identifier : String,
) -> Bool {
  if self.length() < size_uoffset + file_identifier_size {
    return false
  }
  let id_bytes = @utf8.encode(identifier[:])
  for i = 0; i < file_identifier_size; i = i + 1 {
    let buf_byte = self.get_byte(size_uoffset + i)
    let id_byte = if i < id_bytes.length() { id_bytes[i] } else { b'\x00' }
    if buf_byte != id_byte {
      return false
    }
  }
  true
}

///|
/// Get the file identifier from a buffer
pub fn ByteBuffer::get_identifier(self : ByteBuffer) -> String {
  if self.length() < size_uoffset + file_identifier_size {
    return ""
  }
  let bytes = FixedArray::makei(file_identifier_size, fn(i) {
    self.get_byte(size_uoffset + i)
  })
  @utf8.decode_lossy(Bytes::from_array(bytes[:])[:])
}

// =============================================================================
// Size-Prefixed Buffer Support
// =============================================================================

///|
/// Finish building the buffer with a size prefix
pub fn Builder::finish_size_prefixed(self : Builder, root_table : Int) -> Unit {
  // First finish normally
  self.prep(self.minalign, size_uoffset)
  let relative_offset = self.offset() - root_table + size_uoffset
  self.head = self.head - size_uoffset
  self.buf.unsafe_write_uint32_le(
    self.head,
    relative_offset.reinterpret_as_uint(),
  )
  // Then prepend size prefix
  let buffer_size = self.offset()
  self.head = self.head - size_uoffset
  self.buf.unsafe_write_uint32_le(self.head, buffer_size.reinterpret_as_uint())
  self.finished = true
}

///|
/// Get root table from a size-prefixed buffer
pub fn Table::get_root_size_prefixed(buf : ByteBuffer) -> Table {
  let size = buf.read_uint32(0).reinterpret_as_int()
  ignore(size)
  let root_offset = buf.read_uint32(size_uoffset).reinterpret_as_int()
  Table::new(buf, size_uoffset + root_offset)
}

// =============================================================================
// Builder Reset
// =============================================================================

///|
/// Reset the builder to reuse it
pub fn Builder::reset(self : Builder) -> Unit {
  self.head = self.buf.length()
  self.minalign = 1
  self.vtable = []
  self.object_start = 0
  self.vtables.clear()
  self.nested = false
  self.finished = false
  self.force_defaults = false
  self.string_cache.clear()
}

// =============================================================================
// Enum Support
// =============================================================================
//
// In FlatBuffers, enums map to integer types:
// - enum Color:ubyte { Red = 0, Green, Blue }  -> use add_uint8/get_uint8
// - enum Race:byte { None = -1, Human = 0 }    -> use add_int8/get_int8
// - enum Status:ushort { ... }                 -> use add_uint16/get_uint16
// - enum Code:int { ... }                      -> use add_int32/get_int32
//
// For bit_flags enums, combine values with bitwise OR:
// - Color.Red | Color.Blue -> 0b00000101 (5)
//
// Example usage:
//   // Writing an enum field
//   builder.add_uint8(slot, color_value, 0)
//
//   // Reading an enum field
//   let color = table.get_uint8(slot, 0)

// =============================================================================
// Union Support
// =============================================================================
//
// A union in FlatBuffers is represented by two fields:
// 1. A type field (ubyte) indicating which type is active
// 2. A value field (offset) pointing to the actual table
//
// The type field slot is typically value_slot - 1.

///|
/// Add a union to the object being built.
/// type_slot: slot for the union type (ubyte)
/// type_value: the union type value (0 = NONE, 1 = first type, etc.)
/// value_slot: slot for the union value (offset)
/// table_offset: offset to the table returned by end_object
pub fn Builder::add_union(
  self : Builder,
  type_slot : Int,
  type_value : Int,
  value_slot : Int,
  table_offset : Int
) -> Unit {
  // Only add if type is not NONE (0)
  if type_value != 0 {
    self.add_offset(value_slot, table_offset)
    self.add_uint8(type_slot, type_value, 0)
  }
}

///|
/// Get the union type from a table
pub fn Table::get_union_type(self : Table, type_slot : Int) -> Int {
  self.get_uint8(type_slot, 0)
}

///|
/// Get a union table from the value slot
/// Returns None if the union type is NONE (0) or offset is invalid
pub fn Table::get_union_table(self : Table, value_slot : Int) -> Table? {
  let offset = self.vtable_offset(size_voffset * (2 + value_slot))
  if offset == 0 {
    return None
  }
  let indirect = self.buf.read_uint32(self.pos + offset).reinterpret_as_int()
  Some(Table::new(self.buf, self.pos + offset + indirect))
}

// =============================================================================
// Verifier
// =============================================================================
//
// The Verifier checks that a FlatBuffer is valid and safe to read.
// It validates:
// - All offsets are within buffer bounds
// - String null termination
// - Vector lengths don't overflow
// - Nesting depth limits (prevents stack overflow)
// - Table count limits (prevents excessive processing)

///|
/// Verifier options
pub struct VerifierOptions {
  /// Maximum nesting depth of tables and vectors
  max_depth : Int
  /// Maximum number of tables to verify
  max_tables : Int
  /// Check alignment of data
  check_alignment : Bool
}

///|
/// Create default verifier options
pub fn VerifierOptions::default() -> VerifierOptions {
  { max_depth: 64, max_tables: 1000000, check_alignment: true }
}

///|
/// Create custom verifier options
pub fn VerifierOptions::new(
  max_depth : Int,
  max_tables : Int,
  check_alignment : Bool
) -> VerifierOptions {
  { max_depth, max_tables, check_alignment }
}

///|
/// Verifier for FlatBuffer validation
pub struct Verifier {
  buf : ByteBuffer
  opts : VerifierOptions
  mut depth : Int
  mut num_tables : Int
}

///|
/// Create a new verifier
pub fn Verifier::new(buf : ByteBuffer, opts : VerifierOptions) -> Verifier {
  { buf, opts, depth: 0, num_tables: 0 }
}

///|
/// Create a verifier with default options
pub fn Verifier::from_buffer(buf : ByteBuffer) -> Verifier {
  Verifier::new(buf, VerifierOptions::default())
}

///|
/// Check if a range is within buffer bounds
pub fn Verifier::verify_range(self : Verifier, start : Int, len : Int) -> Bool {
  start >= 0 && len >= 0 && start + len <= self.buf.length()
}

///|
/// Check alignment
pub fn Verifier::verify_alignment(
  self : Verifier,
  pos : Int,
  align : Int
) -> Bool {
  if self.opts.check_alignment {
    pos.land(align - 1) == 0
  } else {
    true
  }
}

///|
/// Verify a scalar at position
pub fn Verifier::verify_scalar(
  self : Verifier,
  pos : Int,
  size : Int
) -> Bool {
  self.verify_alignment(pos, size) && self.verify_range(pos, size)
}

///|
/// Verify a string at offset position
pub fn Verifier::verify_string(self : Verifier, pos : Int) -> Bool {
  // Check we can read the length
  if not(self.verify_range(pos, size_uoffset)) {
    return false
  }
  let len = self.buf.read_uint32(pos).reinterpret_as_int()
  // Check string content + null terminator
  if not(self.verify_range(pos + size_uoffset, len + 1)) {
    return false
  }
  // Check null terminator
  self.buf.get_byte(pos + size_uoffset + len) == b'\x00'
}

///|
/// Verify a vector at offset position
pub fn Verifier::verify_vector(
  self : Verifier,
  pos : Int,
  elem_size : Int
) -> Bool {
  // Check we can read the length
  if not(self.verify_range(pos, size_uoffset)) {
    return false
  }
  let len = self.buf.read_uint32(pos).reinterpret_as_int()
  // Check vector content
  self.verify_range(pos + size_uoffset, len * elem_size)
}

///|
/// Verify a table at position (basic verification)
pub fn Verifier::verify_table_start(self : Verifier, pos : Int) -> Bool {
  // Check depth limit
  if self.depth >= self.opts.max_depth {
    return false
  }
  // Check table count limit
  if self.num_tables >= self.opts.max_tables {
    return false
  }
  // Check we can read the soffset to vtable
  if not(self.verify_range(pos, size_soffset)) {
    return false
  }
  let vtable_offset = self.buf.read_int32(pos)
  let vtable_pos = pos - vtable_offset
  // Check vtable is within bounds
  if vtable_pos < 0 || vtable_pos >= self.buf.length() {
    return false
  }
  // Check we can read vtable size
  if not(self.verify_range(vtable_pos, size_voffset)) {
    return false
  }
  let vtable_size = self.buf.read_uint16(vtable_pos)
  // Check vtable is within bounds
  if not(self.verify_range(vtable_pos, vtable_size)) {
    return false
  }
  self.num_tables = self.num_tables + 1
  true
}

///|
/// Push depth for nested verification
pub fn Verifier::push_depth(self : Verifier) -> Bool {
  if self.depth >= self.opts.max_depth {
    return false
  }
  self.depth = self.depth + 1
  true
}

///|
/// Pop depth after nested verification
pub fn Verifier::pop_depth(self : Verifier) -> Unit {
  self.depth = self.depth - 1
}

///|
/// Verify a buffer has a valid root table
pub fn Verifier::verify_buffer(self : Verifier) -> Bool {
  // Check minimum size (root offset)
  if not(self.verify_range(0, size_uoffset)) {
    return false
  }
  let root_offset = self.buf.read_uint32(0).reinterpret_as_int()
  let root_pos = root_offset
  // Verify root table
  self.verify_table_start(root_pos)
}

///|
/// Verify a buffer with file identifier
pub fn Verifier::verify_buffer_with_identifier(
  self : Verifier,
  identifier : String
) -> Bool {
  // Check minimum size (root offset + identifier)
  if not(self.verify_range(0, size_uoffset + file_identifier_size)) {
    return false
  }
  // Check identifier
  if not(self.buf.has_identifier(identifier)) {
    return false
  }
  // Verify root table
  self.verify_buffer()
}

///|
/// Verify a size-prefixed buffer
pub fn Verifier::verify_size_prefixed_buffer(self : Verifier) -> Bool {
  // Check we can read size prefix
  if not(self.verify_range(0, size_uoffset)) {
    return false
  }
  let size = self.buf.read_uint32(0).reinterpret_as_int()
  // Check buffer size matches
  if self.buf.length() < size_uoffset + size {
    return false
  }
  // Check root offset
  if not(self.verify_range(size_uoffset, size_uoffset)) {
    return false
  }
  let root_offset = self.buf.read_uint32(size_uoffset).reinterpret_as_int()
  let root_pos = size_uoffset + root_offset
  // Verify root table
  self.verify_table_start(root_pos)
}

// =============================================================================
// Convenience Functions
// =============================================================================

///|
/// Verify a buffer (convenience function)
pub fn ByteBuffer::verify(self : ByteBuffer) -> Bool {
  let verifier = Verifier::from_buffer(self)
  verifier.verify_buffer()
}

///|
/// Verify a buffer with identifier (convenience function)
pub fn ByteBuffer::verify_with_identifier(
  self : ByteBuffer,
  identifier : String
) -> Bool {
  let verifier = Verifier::from_buffer(self)
  verifier.verify_buffer_with_identifier(identifier)
}

///|
/// Verify a size-prefixed buffer (convenience function)
pub fn ByteBuffer::verify_size_prefixed(self : ByteBuffer) -> Bool {
  let verifier = Verifier::from_buffer(self)
  verifier.verify_size_prefixed_buffer()
}

// =============================================================================
// Nested FlatBuffer Support
// =============================================================================
//
// Nested FlatBuffers allow embedding a complete FlatBuffer inside another
// FlatBuffer as a byte vector. This is useful for:
// - Lazy parsing of nested data
// - Versioning nested structures independently
// - Storing pre-serialized data

///|
/// Create a nested FlatBuffer field from serialized bytes.
/// The bytes should be a complete FlatBuffer (from Builder::to_bytes or similar).
/// Returns an offset to use with add_offset.
pub fn Builder::create_nested_flatbuffer(
  self : Builder,
  nested_bytes : FixedArray[Byte]
) -> Int {
  self.create_byte_vector(nested_bytes)
}

///|
/// Create a nested FlatBuffer field from another builder's output.
/// This is a convenience method that gets the bytes from the builder.
pub fn Builder::create_nested_flatbuffer_from_builder(
  self : Builder,
  nested_builder : Builder
) -> Int {
  self.create_nested_flatbuffer(nested_builder.to_fixed_array())
}

///|
/// Get a nested FlatBuffer from a table field.
/// Returns a ByteBuffer that can be used to read the nested data.
/// Returns None if the field is not present.
pub fn Table::get_nested_flatbuffer(self : Table, field_slot : Int) -> ByteBuffer? {
  let vec_offset = self.vtable_offset(size_voffset * (2 + field_slot))
  if vec_offset == 0 {
    return None
  }
  // Get vector position
  let vec_pos = self.pos +
    vec_offset +
    self.buf.read_uint32(self.pos + vec_offset).reinterpret_as_int()
  // Read vector length
  let len = self.buf.read_uint32(vec_pos).reinterpret_as_int()
  // Create a new ByteBuffer from the vector data
  let data_start = vec_pos + size_uoffset
  let nested_data = FixedArray::makei(len, fn(i) {
    self.buf.get_byte(data_start + i)
  })
  Some(ByteBuffer::new(nested_data))
}

///|
/// Get a nested FlatBuffer's root table directly.
/// Returns None if the field is not present.
pub fn Table::get_nested_root(self : Table, field_slot : Int) -> Table? {
  match self.get_nested_flatbuffer(field_slot) {
    Some(nested_buf) => Some(Table::get_root(nested_buf))
    None => None
  }
}

///|
/// Verify a nested FlatBuffer field.
/// Returns true if the field is absent or contains a valid FlatBuffer.
pub fn Table::verify_nested_flatbuffer(
  self : Table,
  field_slot : Int,
  verifier : Verifier
) -> Bool {
  match self.get_nested_flatbuffer(field_slot) {
    Some(nested_buf) => {
      if not(verifier.push_depth()) {
        return false
      }
      let nested_verifier = Verifier::from_buffer(nested_buf)
      let result = nested_verifier.verify_buffer()
      verifier.pop_depth()
      result
    }
    None => true // Absent field is valid
  }
}

// =============================================================================
// JSON Support
// =============================================================================
//
// Provides JSON serialization for FlatBuffers data.
// Since FlatBuffers binary format doesn't include schema information,
// the user must specify field names and types when converting to JSON.

///|
/// JSON value types
pub enum JsonValue {
  Null
  Bool(Bool)
  Int(Int)
  Int64(Int64)
  UInt(UInt)
  UInt64(UInt64)
  Float(Double)
  String(String)
  Array(Array[JsonValue])
  Object(Array[(String, JsonValue)])
}

///|
/// Create a null JSON value
pub fn JsonValue::null() -> JsonValue {
  Null
}

///|
/// Create a boolean JSON value
pub fn JsonValue::bool(b : Bool) -> JsonValue {
  Bool(b)
}

///|
/// Create an integer JSON value
pub fn JsonValue::int(n : Int) -> JsonValue {
  Int(n)
}

///|
/// Create an Int64 JSON value
pub fn JsonValue::int64(n : Int64) -> JsonValue {
  Int64(n)
}

///|
/// Create a UInt JSON value
pub fn JsonValue::uint(n : UInt) -> JsonValue {
  UInt(n)
}

///|
/// Create a UInt64 JSON value
pub fn JsonValue::uint64(n : UInt64) -> JsonValue {
  UInt64(n)
}

///|
/// Create a float JSON value
pub fn JsonValue::float(f : Double) -> JsonValue {
  Float(f)
}

///|
/// Create a string JSON value
pub fn JsonValue::string(s : String) -> JsonValue {
  String(s)
}

///|
/// Create an array JSON value
pub fn JsonValue::array(arr : Array[JsonValue]) -> JsonValue {
  Array(arr)
}

///|
/// Create an object JSON value
pub fn JsonValue::object(fields : Array[(String, JsonValue)]) -> JsonValue {
  Object(fields)
}

///|
/// Convert a JsonValue to a JSON string
pub fn JsonValue::to_string(self : JsonValue) -> String {
  match self {
    Null => "null"
    Bool(b) => if b { "true" } else { "false" }
    Int(n) => n.to_string()
    Int64(n) => n.to_string()
    UInt(n) => n.to_string()
    UInt64(n) => n.to_string()
    Float(f) => f.to_string()
    String(s) => json_escape_string(s)
    Array(arr) => {
      let parts : Array[String] = []
      for item in arr {
        parts.push(item.to_string())
      }
      "[" + parts.join(", ") + "]"
    }
    Object(fields) => {
      let parts : Array[String] = []
      for pair in fields {
        let (key, value) = pair
        parts.push(json_escape_string(key) + ": " + value.to_string())
      }
      "{" + parts.join(", ") + "}"
    }
  }
}

///|
/// Escape a string for JSON output
fn json_escape_string(s : String) -> String {
  let result : Array[String] = ["\u{22}"]
  for c in s {
    match c {
      '\u{22}' => result.push("\\\u{22}") // double quote
      '\\' => result.push("\\\\")
      '\n' => result.push("\\n")
      '\r' => result.push("\\r")
      '\t' => result.push("\\t")
      _ => result.push(c.to_string())
    }
  }
  result.push("\u{22}")
  result.join("")
}

///|
/// JSON object builder for convenient construction
pub struct JsonObjectBuilder {
  fields : Array[(String, JsonValue)]
}

///|
/// Create a new JSON object builder
pub fn JsonObjectBuilder::new() -> JsonObjectBuilder {
  { fields: [] }
}

///|
/// Add a null field
pub fn JsonObjectBuilder::add_null(
  self : JsonObjectBuilder,
  name : String
) -> JsonObjectBuilder {
  self.fields.push((name, Null))
  self
}

///|
/// Add a boolean field
pub fn JsonObjectBuilder::add_bool(
  self : JsonObjectBuilder,
  name : String,
  value : Bool
) -> JsonObjectBuilder {
  self.fields.push((name, Bool(value)))
  self
}

///|
/// Add an integer field
pub fn JsonObjectBuilder::add_int(
  self : JsonObjectBuilder,
  name : String,
  value : Int
) -> JsonObjectBuilder {
  self.fields.push((name, Int(value)))
  self
}

///|
/// Add an Int64 field
pub fn JsonObjectBuilder::add_int64(
  self : JsonObjectBuilder,
  name : String,
  value : Int64
) -> JsonObjectBuilder {
  self.fields.push((name, Int64(value)))
  self
}

///|
/// Add a UInt field
pub fn JsonObjectBuilder::add_uint(
  self : JsonObjectBuilder,
  name : String,
  value : UInt
) -> JsonObjectBuilder {
  self.fields.push((name, UInt(value)))
  self
}

///|
/// Add a UInt64 field
pub fn JsonObjectBuilder::add_uint64(
  self : JsonObjectBuilder,
  name : String,
  value : UInt64
) -> JsonObjectBuilder {
  self.fields.push((name, UInt64(value)))
  self
}

///|
/// Add a float field
pub fn JsonObjectBuilder::add_float(
  self : JsonObjectBuilder,
  name : String,
  value : Double
) -> JsonObjectBuilder {
  self.fields.push((name, Float(value)))
  self
}

///|
/// Add a string field
pub fn JsonObjectBuilder::add_string(
  self : JsonObjectBuilder,
  name : String,
  value : String
) -> JsonObjectBuilder {
  self.fields.push((name, String(value)))
  self
}

///|
/// Add an array field
pub fn JsonObjectBuilder::add_array(
  self : JsonObjectBuilder,
  name : String,
  value : Array[JsonValue]
) -> JsonObjectBuilder {
  self.fields.push((name, Array(value)))
  self
}

///|
/// Add a nested object field
pub fn JsonObjectBuilder::add_object(
  self : JsonObjectBuilder,
  name : String,
  value : JsonObjectBuilder
) -> JsonObjectBuilder {
  self.fields.push((name, Object(value.fields)))
  self
}

///|
/// Add a JsonValue field
pub fn JsonObjectBuilder::add_value(
  self : JsonObjectBuilder,
  name : String,
  value : JsonValue
) -> JsonObjectBuilder {
  self.fields.push((name, value))
  self
}

///|
/// Build the JSON value
pub fn JsonObjectBuilder::build(self : JsonObjectBuilder) -> JsonValue {
  Object(self.fields)
}

///|
/// Convert to JSON string
pub fn JsonObjectBuilder::to_json_string(self : JsonObjectBuilder) -> String {
  self.build().to_string()
}

// =============================================================================
// Table to JSON Helpers
// =============================================================================

///|
/// Convert an int vector to JSON array
pub fn Table::vector_int32_to_json(
  self : Table,
  slot : Int
) -> JsonValue {
  let len = self.get_vector_length(slot)
  if len == 0 {
    return Array([])
  }
  let arr : Array[JsonValue] = []
  for i = 0; i < len; i = i + 1 {
    arr.push(Int(self.get_vector_int32(slot, i)))
  }
  Array(arr)
}

///|
/// Convert a byte vector to JSON array
pub fn Table::vector_byte_to_json(
  self : Table,
  slot : Int
) -> JsonValue {
  let len = self.get_vector_length(slot)
  if len == 0 {
    return Array([])
  }
  let arr : Array[JsonValue] = []
  for i = 0; i < len; i = i + 1 {
    arr.push(Int(self.get_vector_byte(slot, i).to_int()))
  }
  Array(arr)
}

// =============================================================================
// Object API
// =============================================================================
//
// The Object API provides a higher-level interface for working with FlatBuffers.
// Instead of manually managing field slots, users define schemas and work with
// named fields.

///|
/// Field types supported by the Object API
pub enum FieldType {
  Bool
  Int8
  UInt8
  Int16
  UInt16
  Int32
  UInt32
  Int64
  UInt64
  Float32
  Float64
  String
  Vector(FieldType)
  Table
}

///|
pub fn FieldType::bool() -> FieldType {
  Bool
}

///|
pub fn FieldType::int8() -> FieldType {
  Int8
}

///|
pub fn FieldType::uint8() -> FieldType {
  UInt8
}

///|
pub fn FieldType::int16() -> FieldType {
  Int16
}

///|
pub fn FieldType::uint16() -> FieldType {
  UInt16
}

///|
pub fn FieldType::int32() -> FieldType {
  Int32
}

///|
pub fn FieldType::uint32() -> FieldType {
  UInt32
}

///|
pub fn FieldType::int64() -> FieldType {
  Int64
}

///|
pub fn FieldType::uint64() -> FieldType {
  UInt64
}

///|
pub fn FieldType::float32() -> FieldType {
  Float32
}

///|
pub fn FieldType::float64() -> FieldType {
  Float64
}

///|
pub fn FieldType::string() -> FieldType {
  String
}

///|
pub fn FieldType::vector(elem_type : FieldType) -> FieldType {
  Vector(elem_type)
}

///|
pub fn FieldType::table() -> FieldType {
  Table
}

///|
/// Field definition for schema
pub struct FieldDef {
  name : String
  slot : Int
  field_type : FieldType
  default_int : Int
  default_bool : Bool
}

///|
/// Create a new field definition
pub fn FieldDef::new(
  name : String,
  slot : Int,
  field_type : FieldType
) -> FieldDef {
  { name, slot, field_type, default_int: 0, default_bool: false }
}

///|
/// Create a field definition with int default
pub fn FieldDef::with_default_int(
  name : String,
  slot : Int,
  field_type : FieldType,
  default : Int
) -> FieldDef {
  { name, slot, field_type, default_int: default, default_bool: false }
}

///|
/// Create a field definition with bool default
pub fn FieldDef::with_default_bool(
  name : String,
  slot : Int,
  default : Bool
) -> FieldDef {
  { name, slot, field_type: Bool, default_int: 0, default_bool: default }
}

///|
/// Table schema definition
pub struct TableSchema {
  name : String
  fields : Array[FieldDef]
  field_map : Map[String, Int] // name -> index in fields array
}

///|
/// Create a new table schema
pub fn TableSchema::new(name : String, fields : Array[FieldDef]) -> TableSchema {
  let field_map : Map[String, Int] = {}
  for i = 0; i < fields.length(); i = i + 1 {
    field_map.set(fields[i].name, i)
  }
  { name, fields, field_map }
}

///|
/// Get field definition by name
pub fn TableSchema::get_field(self : TableSchema, name : String) -> FieldDef? {
  match self.field_map.get(name) {
    Some(idx) => Some(self.fields[idx])
    None => None
  }
}

///|
/// Get number of fields
pub fn TableSchema::field_count(self : TableSchema) -> Int {
  self.fields.length()
}

// =============================================================================
// Object Reader - Read tables using schema
// =============================================================================

///|
/// Object reader wraps a Table with schema information
pub struct ObjectReader {
  table : Table
  schema : TableSchema
}

///|
/// Create an object reader
pub fn ObjectReader::new(table : Table, schema : TableSchema) -> ObjectReader {
  { table, schema }
}

///|
/// Get the underlying table
pub fn ObjectReader::get_table(self : ObjectReader) -> Table {
  self.table
}

///|
/// Get a boolean field by name
pub fn ObjectReader::get_bool(self : ObjectReader, name : String) -> Bool {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_bool(field.slot, field.default_bool)
    None => false
  }
}

///|
/// Get an int32 field by name
pub fn ObjectReader::get_int32(self : ObjectReader, name : String) -> Int {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_int32(field.slot, field.default_int)
    None => 0
  }
}

///|
/// Get a uint8 field by name
pub fn ObjectReader::get_uint8(self : ObjectReader, name : String) -> Int {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_uint8(field.slot, field.default_int)
    None => 0
  }
}

///|
/// Get an int16 field by name
pub fn ObjectReader::get_int16(self : ObjectReader, name : String) -> Int {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_int16(field.slot, field.default_int)
    None => 0
  }
}

///|
/// Get a string field by name
pub fn ObjectReader::get_string(self : ObjectReader, name : String) -> String {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_string(field.slot, "")
    None => ""
  }
}

///|
/// Get vector length by field name
pub fn ObjectReader::get_vector_length(
  self : ObjectReader,
  name : String
) -> Int {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_vector_length(field.slot)
    None => 0
  }
}

///|
/// Get a nested table by name
pub fn ObjectReader::get_table_field(
  self : ObjectReader,
  name : String
) -> Table? {
  match self.schema.get_field(name) {
    Some(field) => self.table.get_table(field.slot)
    None => None
  }
}

///|
/// Convert to JSON using schema
pub fn ObjectReader::to_json(self : ObjectReader) -> JsonValue {
  let fields : Array[(String, JsonValue)] = []
  for field in self.schema.fields {
    let value : JsonValue = match field.field_type {
      Bool => Bool(self.table.get_bool(field.slot, field.default_bool))
      Int8 => Int(self.table.get_int8(field.slot, field.default_int))
      UInt8 => Int(self.table.get_uint8(field.slot, field.default_int))
      Int16 => Int(self.table.get_int16(field.slot, field.default_int))
      UInt16 => Int(self.table.get_uint16(field.slot, field.default_int))
      Int32 => Int(self.table.get_int32(field.slot, field.default_int))
      UInt32 =>
        UInt(self.table.get_uint32(field.slot, field.default_int.reinterpret_as_uint()))
      Int64 =>
        Int64(self.table.get_int64(field.slot, field.default_int.to_int64()))
      UInt64 =>
        UInt64(self.table.get_uint64(field.slot, field.default_int.to_uint64()))
      Float32 => Float(self.table.get_float32(field.slot, 0.0).to_double())
      Float64 => Float(self.table.get_float64(field.slot, 0.0))
      String => String(self.table.get_string(field.slot, ""))
      Vector(_) => self.table.vector_int32_to_json(field.slot)
      Table => Null // Nested tables need special handling
    }
    fields.push((field.name, value))
  }
  Object(fields)
}

// =============================================================================
// Object Builder - Build tables using schema
// =============================================================================

///|
/// Object builder wraps a Builder with schema information
pub struct ObjectBuilder {
  builder : Builder
  schema : TableSchema
  string_offsets : Map[String, Int] // field name -> string offset
  vector_offsets : Map[String, Int] // field name -> vector offset
  table_offsets : Map[String, Int] // field name -> table offset
}

///|
/// Create an object builder
pub fn ObjectBuilder::new(
  builder : Builder,
  schema : TableSchema
) -> ObjectBuilder {
  {
    builder,
    schema,
    string_offsets: {},
    vector_offsets: {},
    table_offsets: {},
  }
}

///|
/// Get the underlying builder
pub fn ObjectBuilder::get_builder(self : ObjectBuilder) -> Builder {
  self.builder
}

///|
/// Set a string field (must be called before start_object)
pub fn ObjectBuilder::set_string(
  self : ObjectBuilder,
  name : String,
  value : String
) -> ObjectBuilder {
  let offset = self.builder.create_string(value)
  self.string_offsets.set(name, offset)
  self
}

///|
/// Set a shared string field (must be called before start_object)
pub fn ObjectBuilder::set_shared_string(
  self : ObjectBuilder,
  name : String,
  value : String
) -> ObjectBuilder {
  let offset = self.builder.create_shared_string(value)
  self.string_offsets.set(name, offset)
  self
}

///|
/// Set an int32 vector field (must be called before start_object)
pub fn ObjectBuilder::set_int32_vector(
  self : ObjectBuilder,
  name : String,
  values : Array[Int]
) -> ObjectBuilder {
  let offset = self.builder.create_int32_vector(values)
  self.vector_offsets.set(name, offset)
  self
}

///|
/// Set a nested table offset (from another ObjectBuilder)
pub fn ObjectBuilder::set_table_offset(
  self : ObjectBuilder,
  name : String,
  offset : Int
) -> ObjectBuilder {
  self.table_offsets.set(name, offset)
  self
}

///|
/// Start building the object
pub fn ObjectBuilder::start(self : ObjectBuilder) -> Unit {
  self.builder.start_object(self.schema.field_count())
}

///|
/// Add a boolean field
pub fn ObjectBuilder::add_bool(
  self : ObjectBuilder,
  name : String,
  value : Bool
) -> ObjectBuilder {
  match self.schema.get_field(name) {
    Some(field) => self.builder.add_bool(field.slot, value, field.default_bool)
    None => ()
  }
  self
}

///|
/// Add an int32 field
pub fn ObjectBuilder::add_int32(
  self : ObjectBuilder,
  name : String,
  value : Int
) -> ObjectBuilder {
  match self.schema.get_field(name) {
    Some(field) => self.builder.add_int32(field.slot, value, field.default_int)
    None => ()
  }
  self
}

///|
/// Add a uint8 field
pub fn ObjectBuilder::add_uint8(
  self : ObjectBuilder,
  name : String,
  value : Int
) -> ObjectBuilder {
  match self.schema.get_field(name) {
    Some(field) => self.builder.add_uint8(field.slot, value, field.default_int)
    None => ()
  }
  self
}

///|
/// Add an int16 field
pub fn ObjectBuilder::add_int16(
  self : ObjectBuilder,
  name : String,
  value : Int
) -> ObjectBuilder {
  match self.schema.get_field(name) {
    Some(field) => self.builder.add_int16(field.slot, value, field.default_int)
    None => ()
  }
  self
}

///|
/// Finish adding scalar fields and add pre-created offsets
pub fn ObjectBuilder::finish_fields(self : ObjectBuilder) -> Unit {
  // Add string offsets
  for entry in self.string_offsets {
    let (name, offset) = entry
    match self.schema.get_field(name) {
      Some(field) => self.builder.add_offset(field.slot, offset)
      None => ()
    }
  }
  // Add vector offsets
  for entry in self.vector_offsets {
    let (name, offset) = entry
    match self.schema.get_field(name) {
      Some(field) => self.builder.add_offset(field.slot, offset)
      None => ()
    }
  }
  // Add table offsets
  for entry in self.table_offsets {
    let (name, offset) = entry
    match self.schema.get_field(name) {
      Some(field) => self.builder.add_offset(field.slot, offset)
      None => ()
    }
  }
}

///|
/// End the object and return its offset
pub fn ObjectBuilder::end(self : ObjectBuilder) -> Int {
  self.finish_fields()
  self.builder.end_object()
}

///|
/// Convenience method to finish the buffer with this object as root
pub fn ObjectBuilder::finish_buffer(self : ObjectBuilder) -> Unit {
  let offset = self.end()
  self.builder.finish(offset)
}
