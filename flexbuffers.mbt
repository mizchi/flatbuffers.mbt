///|
/// FlexBuffers - Schema-less self-describing binary format
///
/// FlexBuffers is a self-describing binary format that stores type information
/// inline with the data. Unlike FlatBuffers, it doesn't require a schema.

// =============================================================================
// FlexBuffers Types
// =============================================================================

///|
/// FlexBuffer value types
pub enum FlexType {
  Null // 0
  Int // 1
  UInt // 2
  Float // 3
  Key // 4 - String key (for maps)
  String // 5
  IndirectInt // 6
  IndirectUInt // 7
  IndirectFloat // 8
  Map // 9
  Vector // 10
  VectorInt // 11 - Typed vector of ints
  VectorUInt // 12
  VectorFloat // 13
  VectorKey // 14
  VectorString // 15 (deprecated)
  VectorInt2 // 16 - Fixed size typed vector
  VectorUInt2 // 17
  VectorFloat2 // 18
  VectorInt3 // 19
  VectorUInt3 // 20
  VectorFloat3 // 21
  VectorInt4 // 22
  VectorUInt4 // 23
  VectorFloat4 // 24
  Blob // 25
  Bool // 26
  VectorBool // 36
} derive(Show)

///|
pub fn FlexType::to_int(self : FlexType) -> Int {
  match self {
    Null => 0
    Int => 1
    UInt => 2
    Float => 3
    Key => 4
    String => 5
    IndirectInt => 6
    IndirectUInt => 7
    IndirectFloat => 8
    Map => 9
    Vector => 10
    VectorInt => 11
    VectorUInt => 12
    VectorFloat => 13
    VectorKey => 14
    VectorString => 15
    VectorInt2 => 16
    VectorUInt2 => 17
    VectorFloat2 => 18
    VectorInt3 => 19
    VectorUInt3 => 20
    VectorFloat3 => 21
    VectorInt4 => 22
    VectorUInt4 => 23
    VectorFloat4 => 24
    Blob => 25
    Bool => 26
    VectorBool => 36
  }
}

///|
pub fn FlexType::from_int(value : Int) -> FlexType {
  match value {
    0 => Null
    1 => Int
    2 => UInt
    3 => Float
    4 => Key
    5 => String
    6 => IndirectInt
    7 => IndirectUInt
    8 => IndirectFloat
    9 => Map
    10 => Vector
    11 => VectorInt
    12 => VectorUInt
    13 => VectorFloat
    14 => VectorKey
    15 => VectorString
    16 => VectorInt2
    17 => VectorUInt2
    18 => VectorFloat2
    19 => VectorInt3
    20 => VectorUInt3
    21 => VectorFloat3
    22 => VectorInt4
    23 => VectorUInt4
    24 => VectorFloat4
    25 => Blob
    26 => Bool
    36 => VectorBool
    _ => Null
  }
}

///|
/// Check if type is inline (stored directly in the data)
pub fn FlexType::is_inline(self : FlexType) -> Bool {
  match self {
    Null | Int | UInt | Float | Bool => true
    _ => false
  }
}

///|
/// Check if type is a typed vector
pub fn FlexType::is_typed_vector(self : FlexType) -> Bool {
  match self {
    VectorInt
    | VectorUInt
    | VectorFloat
    | VectorKey
    | VectorString
    | VectorBool => true
    VectorInt2
    | VectorUInt2
    | VectorFloat2
    | VectorInt3
    | VectorUInt3
    | VectorFloat3
    | VectorInt4
    | VectorUInt4
    | VectorFloat4 => true
    _ => false
  }
}

///|
/// Check if type is a fixed typed vector
pub fn FlexType::is_fixed_typed_vector(self : FlexType) -> Bool {
  match self {
    VectorInt2
    | VectorUInt2
    | VectorFloat2
    | VectorInt3
    | VectorUInt3
    | VectorFloat3
    | VectorInt4
    | VectorUInt4
    | VectorFloat4 => true
    _ => false
  }
}

// =============================================================================
// FlexBuffer Reference (Reader)
// =============================================================================

///|
/// A reference to a value in a FlexBuffer
pub struct FlexRef {
  data : FixedArray[Byte]
  offset : Int // Offset where value starts
  parent_width : Int // Byte width of parent element
  byte_width : Int // Byte width of this element
  flex_type : FlexType // Type of this value
}

///|
fn flex_read_int(data : FixedArray[Byte], offset : Int, width : Int) -> Int64 {
  match width {
    1 => {
      let v = data[offset].to_int()
      // Sign extend
      if v >= 128 {
        (v - 256).to_int64()
      } else {
        v.to_int64()
      }
    }
    2 => {
      let b0 = data[offset].to_int()
      let b1 = data[offset + 1].to_int()
      let v = b0 | (b1 << 8)
      // Sign extend
      if v >= 32768 {
        (v - 65536).to_int64()
      } else {
        v.to_int64()
      }
    }
    4 => {
      let b0 = data[offset].to_int()
      let b1 = data[offset + 1].to_int()
      let b2 = data[offset + 2].to_int()
      let b3 = data[offset + 3].to_int()
      (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)).to_int64()
    }
    8 => {
      let mut result : Int64 = 0L
      for i = 0; i < 8; i = i + 1 {
        result = result | (data[offset + i].to_int().to_int64() << (i * 8))
      }
      result
    }
    _ => 0L
  }
}

///|
fn flex_read_uint(data : FixedArray[Byte], offset : Int, width : Int) -> UInt64 {
  match width {
    1 => data[offset].to_int().to_uint64()
    2 => {
      let b0 = data[offset].to_int()
      let b1 = data[offset + 1].to_int()
      (b0 | (b1 << 8)).to_uint64()
    }
    4 => {
      let b0 = data[offset].to_int()
      let b1 = data[offset + 1].to_int()
      let b2 = data[offset + 2].to_int()
      let b3 = data[offset + 3].to_int()
      (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
      .reinterpret_as_uint()
      .to_uint64()
    }
    8 => {
      let mut result : UInt64 = 0UL
      for i = 0; i < 8; i = i + 1 {
        result = result | (data[offset + i].to_int().to_uint64() << (i * 8))
      }
      result
    }
    _ => 0UL
  }
}

///|
fn flex_read_float(
  data : FixedArray[Byte],
  offset : Int,
  width : Int,
) -> Double {
  match width {
    4 => {
      let bits = flex_read_uint(data, offset, 4).to_uint()
      Float::reinterpret_from_uint(bits).to_double()
    }
    8 => {
      let bits = flex_read_uint(data, offset, 8)
      bits.reinterpret_as_double()
    }
    _ => 0.0
  }
}

///|
fn bytes_to_string(bytes : Array[Byte]) -> String {
  let chars : Array[Char] = []
  for b in bytes {
    chars.push(b.to_int().unsafe_to_char())
  }
  String::from_array(chars)
}

///|
/// Create a FlexRef from raw bytes
pub fn FlexRef::from_bytes(data : FixedArray[Byte]) -> FlexRef {
  if data.length() < 3 {
    return { data, offset: 0, parent_width: 1, byte_width: 1, flex_type: Null }
  }
  // Last byte is the byte width
  let byte_width = data[data.length() - 1].to_int()
  // Second to last is packed type
  let packed_type = data[data.length() - 2].to_int()
  let flex_type = FlexType::from_int(packed_type >> 2)
  let parent_width = 1 << (packed_type & 3)
  // Root offset is calculated from the end
  let offset = data.length() - byte_width - 2
  { data, offset, parent_width, byte_width, flex_type }
}

///|
/// Get indirect offset (for non-inline types)
fn FlexRef::indirect_offset(self : FlexRef) -> Int {
  match self.flex_type {
    Int | UInt | Float | Bool | Null => self.offset
    _ =>
      self.offset -
      flex_read_uint(self.data, self.offset, self.parent_width).to_int()
  }
}

///|
/// Check if value is null
pub fn FlexRef::is_null(self : FlexRef) -> Bool {
  match self.flex_type {
    Null => true
    _ => false
  }
}

///|
/// Get value as Int64
pub fn FlexRef::as_int64(self : FlexRef) -> Int64 {
  match self.flex_type {
    Int => flex_read_int(self.data, self.offset, self.byte_width)
    IndirectInt =>
      flex_read_int(self.data, self.indirect_offset(), self.byte_width)
    UInt =>
      flex_read_uint(self.data, self.offset, self.byte_width).reinterpret_as_int64()
    IndirectUInt =>
      flex_read_uint(self.data, self.indirect_offset(), self.byte_width).reinterpret_as_int64()
    Bool => if self.as_bool() { 1L } else { 0L }
    _ => 0L
  }
}

///|
/// Get value as Int
pub fn FlexRef::as_int(self : FlexRef) -> Int {
  self.as_int64().to_int()
}

///|
/// Get value as UInt64
pub fn FlexRef::as_uint64(self : FlexRef) -> UInt64 {
  match self.flex_type {
    UInt => flex_read_uint(self.data, self.offset, self.byte_width)
    IndirectUInt =>
      flex_read_uint(self.data, self.indirect_offset(), self.byte_width)
    Int =>
      flex_read_int(self.data, self.offset, self.byte_width).reinterpret_as_uint64()
    IndirectInt =>
      flex_read_int(self.data, self.indirect_offset(), self.byte_width).reinterpret_as_uint64()
    Bool => if self.as_bool() { 1UL } else { 0UL }
    _ => 0UL
  }
}

///|
/// Get value as Double
pub fn FlexRef::as_double(self : FlexRef) -> Double {
  match self.flex_type {
    Float => flex_read_float(self.data, self.offset, self.byte_width)
    IndirectFloat =>
      flex_read_float(self.data, self.indirect_offset(), self.byte_width)
    Int | IndirectInt => self.as_int64().to_double()
    UInt | IndirectUInt => self.as_uint64().to_double()
    _ => 0.0
  }
}

///|
/// Get value as Bool
pub fn FlexRef::as_bool(self : FlexRef) -> Bool {
  match self.flex_type {
    Bool => flex_read_uint(self.data, self.offset, self.byte_width) != 0UL
    Int | UInt => self.as_int64() != 0L
    _ => false
  }
}

///|
/// Get value as String
pub fn FlexRef::as_string(self : FlexRef) -> String {
  match self.flex_type {
    String | Key => {
      let str_offset = self.indirect_offset()
      // String is prefixed with length
      let len = flex_read_uint(
        self.data,
        str_offset - self.byte_width,
        self.byte_width,
      ).to_int()
      let bytes : Array[Byte] = []
      for i = 0; i < len; i = i + 1 {
        bytes.push(self.data[str_offset + i])
      }
      bytes_to_string(bytes)
    }
    _ => ""
  }
}

///|
/// Get vector length (for Vector, Map, typed vectors)
pub fn FlexRef::length(self : FlexRef) -> Int {
  match self.flex_type {
    Vector
    | VectorInt
    | VectorUInt
    | VectorFloat
    | VectorKey
    | VectorString
    | VectorBool
    | Map
    | Blob => {
      let vec_offset = self.indirect_offset()
      flex_read_uint(self.data, vec_offset - self.byte_width, self.byte_width).to_int()
    }
    VectorInt2 | VectorUInt2 | VectorFloat2 => 2
    VectorInt3 | VectorUInt3 | VectorFloat3 => 3
    VectorInt4 | VectorUInt4 | VectorFloat4 => 4
    _ => 0
  }
}

///|
/// Get element from vector by index
pub fn FlexRef::get(self : FlexRef, index : Int) -> FlexRef {
  let len = self.length()
  if index < 0 || index >= len {
    return {
      data: self.data,
      offset: 0,
      parent_width: 1,
      byte_width: 1,
      flex_type: Null,
    }
  }
  match self.flex_type {
    Vector => {
      let vec_offset = self.indirect_offset()
      // Type vector follows the data
      let types_offset = vec_offset + len * self.byte_width
      let elem_type = FlexType::from_int(
        self.data[types_offset + index].to_int() >> 2,
      )
      let elem_width = 1 << (self.data[types_offset + index].to_int() & 3)
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: elem_width,
        flex_type: elem_type,
      }
    }
    VectorInt | VectorInt2 | VectorInt3 | VectorInt4 => {
      let vec_offset = self.indirect_offset()
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: self.byte_width,
        flex_type: Int,
      }
    }
    VectorUInt | VectorUInt2 | VectorUInt3 | VectorUInt4 => {
      let vec_offset = self.indirect_offset()
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: self.byte_width,
        flex_type: UInt,
      }
    }
    VectorFloat | VectorFloat2 | VectorFloat3 | VectorFloat4 => {
      let vec_offset = self.indirect_offset()
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: self.byte_width,
        flex_type: Float,
      }
    }
    VectorBool => {
      let vec_offset = self.indirect_offset()
      {
        data: self.data,
        offset: vec_offset + index,
        parent_width: 1,
        byte_width: 1,
        flex_type: Bool,
      }
    }
    VectorKey | VectorString => {
      let vec_offset = self.indirect_offset()
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: self.byte_width,
        flex_type: String,
      }
    }
    Map => {
      let vec_offset = self.indirect_offset()
      let types_offset = vec_offset + len * self.byte_width
      let elem_type = FlexType::from_int(
        self.data[types_offset + index].to_int() >> 2,
      )
      let elem_width = 1 << (self.data[types_offset + index].to_int() & 3)
      {
        data: self.data,
        offset: vec_offset + index * self.byte_width,
        parent_width: self.byte_width,
        byte_width: elem_width,
        flex_type: elem_type,
      }
    }
    _ =>
      {
        data: self.data,
        offset: 0,
        parent_width: 1,
        byte_width: 1,
        flex_type: Null,
      }
  }
}

///|
/// Get blob data
pub fn FlexRef::as_blob(self : FlexRef) -> FixedArray[Byte] {
  match self.flex_type {
    Blob => {
      let blob_offset = self.indirect_offset()
      let len = flex_read_uint(
        self.data,
        blob_offset - self.byte_width,
        self.byte_width,
      ).to_int()
      let result : FixedArray[Byte] = FixedArray::make(len, b'\x00')
      for i = 0; i < len; i = i + 1 {
        result[i] = self.data[blob_offset + i]
      }
      result
    }
    _ => FixedArray::make(0, b'\x00')
  }
}

// =============================================================================
// FlexBuffer Builder
// =============================================================================

///|
/// A value to be written to a FlexBuffer
pub struct FlexValue {
  flex_type : FlexType
  min_bit_width : Int // 0=8bit, 1=16bit, 2=32bit, 3=64bit
  value_int : Int64
  value_uint : UInt64
  value_float : Double
  offset : Int // For non-inline values
}

///|
pub fn FlexValue::null() -> FlexValue {
  {
    flex_type: Null,
    min_bit_width: 0,
    value_int: 0L,
    value_uint: 0UL,
    value_float: 0.0,
    offset: 0,
  }
}

///|
pub fn FlexValue::int(val : Int64) -> FlexValue {
  let min_bit_width = if val >= -128L && val <= 127L {
    0
  } else if val >= -32768L && val <= 32767L {
    1
  } else if val >= -2147483648L && val <= 2147483647L {
    2
  } else {
    3
  }
  {
    flex_type: Int,
    min_bit_width,
    value_int: val,
    value_uint: 0UL,
    value_float: 0.0,
    offset: 0,
  }
}

///|
pub fn FlexValue::uint(val : UInt64) -> FlexValue {
  let min_bit_width = if val <= 255UL {
    0
  } else if val <= 65535UL {
    1
  } else if val <= 4294967295UL {
    2
  } else {
    3
  }
  {
    flex_type: UInt,
    min_bit_width,
    value_int: 0L,
    value_uint: val,
    value_float: 0.0,
    offset: 0,
  }
}

///|
pub fn FlexValue::float(val : Double) -> FlexValue {
  // Always use 64-bit for simplicity
  {
    flex_type: Float,
    min_bit_width: 3,
    value_int: 0L,
    value_uint: 0UL,
    value_float: val,
    offset: 0,
  }
}

///|
pub fn FlexValue::bool_val(val : Bool) -> FlexValue {
  {
    flex_type: Bool,
    min_bit_width: 0,
    value_int: if val {
      1L
    } else {
      0L
    },
    value_uint: 0UL,
    value_float: 0.0,
    offset: 0,
  }
}

///|
pub fn FlexValue::string_ref(offset : Int, min_bit_width : Int) -> FlexValue {
  {
    flex_type: String,
    min_bit_width,
    value_int: 0L,
    value_uint: 0UL,
    value_float: 0.0,
    offset,
  }
}

///|
pub fn FlexValue::vector_ref(
  offset : Int,
  flex_type : FlexType,
  min_bit_width : Int,
) -> FlexValue {
  {
    flex_type,
    min_bit_width,
    value_int: 0L,
    value_uint: 0UL,
    value_float: 0.0,
    offset,
  }
}

///|
pub fn FlexValue::key_ref(offset : Int, min_bit_width : Int) -> FlexValue {
  {
    flex_type: Key,
    min_bit_width,
    value_int: 0L,
    value_uint: 0UL,
    value_float: 0.0,
    offset,
  }
}

///|
pub fn FlexValue::blob_ref(offset : Int) -> FlexValue {
  {
    flex_type: Blob,
    min_bit_width: 0,
    value_int: 0L,
    value_uint: 0UL,
    value_float: 0.0,
    offset,
  }
}

///|
/// FlexBuffer builder
pub struct FlexBuilder {
  buf : Array[Byte]
  stack : Array[FlexValue]
  string_pool : Map[String, Int]
  key_pool : Map[String, Int]
  finished : Bool
}

///|
/// Create a new FlexBuilder
pub fn FlexBuilder::new() -> FlexBuilder {
  { buf: [], stack: [], string_pool: {}, key_pool: {}, finished: false }
}

///|
/// Add null value
pub fn FlexBuilder::add_null(self : FlexBuilder) -> FlexBuilder {
  self.stack.push(FlexValue::null())
  self
}

///|
/// Add int value
pub fn FlexBuilder::add_int(self : FlexBuilder, val : Int64) -> FlexBuilder {
  self.stack.push(FlexValue::int(val))
  self
}

///|
/// Add uint value
pub fn FlexBuilder::add_uint(self : FlexBuilder, val : UInt64) -> FlexBuilder {
  self.stack.push(FlexValue::uint(val))
  self
}

///|
/// Add float value
pub fn FlexBuilder::add_float(self : FlexBuilder, val : Double) -> FlexBuilder {
  self.stack.push(FlexValue::float(val))
  self
}

///|
/// Add bool value
pub fn FlexBuilder::add_bool(self : FlexBuilder, val : Bool) -> FlexBuilder {
  self.stack.push(FlexValue::bool_val(val))
  self
}

///|
fn flex_write_uint(buf : Array[Byte], val : UInt64, width : Int) -> Unit {
  for i = 0; i < width; i = i + 1 {
    buf.push(((val >> (i * 8)) & 0xFFUL).to_byte())
  }
}

///|
fn flex_write_int(buf : Array[Byte], val : Int64, width : Int) -> Unit {
  flex_write_uint(buf, val.reinterpret_as_uint64(), width)
}

///|
/// Add string value
pub fn FlexBuilder::add_string(self : FlexBuilder, s : String) -> FlexBuilder {
  // Check string pool first
  match self.string_pool.get(s) {
    Some(str_data_offset) => {
      // Calculate bit width needed to address this offset from current position
      let dist = self.buf.length() - str_data_offset
      let min_bit_width = if dist <= 255 {
        0
      } else if dist <= 65535 {
        1
      } else {
        2
      }
      self.stack.push(FlexValue::string_ref(str_data_offset, min_bit_width))
    }
    None => {
      // Write string to buffer
      let bytes = @utf8.encode(s[:])
      let len = bytes.length()
      // Write length prefix (1 byte for now)
      flex_write_uint(self.buf, len.to_uint64(), 1)
      // str_data_offset points to where string bytes start (AFTER length prefix)
      let str_data_offset = self.buf.length()
      // Write string bytes
      for b in bytes {
        self.buf.push(b)
      }
      // Write null terminator
      self.buf.push(b'\x00')
      // Cache in pool (store offset to string data, not length)
      self.string_pool.set(s, str_data_offset)
      let min_bit_width = 0
      self.stack.push(FlexValue::string_ref(str_data_offset, min_bit_width))
    }
  }
  self
}

///|
/// Add a key (for maps) - keys are null-terminated strings without length prefix
pub fn FlexBuilder::add_key(self : FlexBuilder, key : String) -> FlexBuilder {
  // Check key pool first
  match self.key_pool.get(key) {
    Some(key_offset) => {
      let dist = self.buf.length() - key_offset
      let min_bit_width = if dist <= 255 {
        0
      } else if dist <= 65535 {
        1
      } else {
        2
      }
      self.stack.push(FlexValue::key_ref(key_offset, min_bit_width))
    }
    None => {
      let key_offset = self.buf.length()
      let bytes = @utf8.encode(key[:])
      for b in bytes {
        self.buf.push(b)
      }
      self.buf.push(b'\x00')
      self.key_pool.set(key, key_offset)
      self.stack.push(FlexValue::key_ref(key_offset, 0))
    }
  }
  self
}

///|
/// Add a blob (binary data)
pub fn FlexBuilder::add_blob(
  self : FlexBuilder,
  data : FixedArray[Byte],
) -> FlexBuilder {
  let len = data.length()
  // Write length prefix
  flex_write_uint(self.buf, len.to_uint64(), 1)
  let blob_offset = self.buf.length()
  // Write blob data
  for i = 0; i < len; i = i + 1 {
    self.buf.push(data[i])
  }
  self.stack.push(FlexValue::blob_ref(blob_offset))
  self
}

///|
/// End a map and push it onto the stack
/// Map format: keys vector followed by values vector with type info
/// Stack should contain: key1, val1, key2, val2, ... (pairs)
pub fn FlexBuilder::end_map(self : FlexBuilder, count : Int) -> FlexBuilder {
  if count == 0 {
    flex_write_uint(self.buf, 0UL, 1)
    self.stack.push(FlexValue::vector_ref(self.buf.length(), Map, 0))
    return self
  }

  // Pop key-value pairs from stack
  let pairs : Array[(FlexValue, FlexValue)] = []
  for i = 0; i < count; i = i + 1 {
    let value = match self.stack.pop() {
      Some(v) => v
      None => FlexValue::null()
    }
    let key = match self.stack.pop() {
      Some(k) => k
      None => FlexValue::null()
    }
    pairs.push((key, value))
  }
  pairs.rev_in_place()

  // Calculate byte width for values
  let mut max_width = 0
  for pair in pairs {
    if pair.1.min_bit_width > max_width {
      max_width = pair.1.min_bit_width
    }
  }
  let byte_width = 1 << max_width

  // Align buffer
  let padding = (byte_width - self.buf.length() % byte_width) % byte_width
  for i = 0; i < padding; i = i + 1 {
    self.buf.push(b'\x00')
    ignore(i)
  }

  // Write keys vector (offsets to key strings)
  flex_write_uint(self.buf, count.to_uint64(), byte_width)
  let keys_offset = self.buf.length()
  for pair in pairs {
    let offset_to_key = self.buf.length() - pair.0.offset
    flex_write_uint(self.buf, offset_to_key.to_uint64(), byte_width)
  }

  // Write values length
  flex_write_uint(self.buf, count.to_uint64(), byte_width)
  let values_offset = self.buf.length()

  // Write values
  for pair in pairs {
    let v = pair.1
    match v.flex_type {
      Int => flex_write_int(self.buf, v.value_int, byte_width)
      UInt => flex_write_uint(self.buf, v.value_uint, byte_width)
      Float =>
        flex_write_uint(
          self.buf,
          v.value_float.reinterpret_as_uint64(),
          byte_width,
        )
      Bool =>
        flex_write_uint(
          self.buf,
          if v.value_int != 0L {
            1UL
          } else {
            0UL
          },
          byte_width,
        )
      Null => flex_write_uint(self.buf, 0UL, byte_width)
      String => {
        let offset_to_string = self.buf.length() - v.offset
        flex_write_uint(self.buf, offset_to_string.to_uint64(), byte_width)
      }
      Vector | VectorInt | VectorUInt | VectorFloat | Map => {
        let offset_to_vec = self.buf.length() - v.offset
        flex_write_uint(self.buf, offset_to_vec.to_uint64(), byte_width)
      }
      _ => flex_write_uint(self.buf, 0UL, byte_width)
    }
  }

  // Write type vector for values
  for pair in pairs {
    let packed_type = (pair.1.flex_type.to_int() << 2) | pair.1.min_bit_width
    self.buf.push(packed_type.to_byte())
  }

  // Store offset to keys vector, with reference to values
  ignore(keys_offset)
  self.stack.push(FlexValue::vector_ref(values_offset, Map, max_width))
  self
}

///|
/// End a typed vector of ints
pub fn FlexBuilder::end_int_vector(
  self : FlexBuilder,
  count : Int,
) -> FlexBuilder {
  if count == 0 {
    flex_write_uint(self.buf, 0UL, 1)
    self.stack.push(FlexValue::vector_ref(self.buf.length(), VectorInt, 0))
    return self
  }
  let values : Array[Int64] = []
  for i = 0; i < count; i = i + 1 {
    match self.stack.pop() {
      Some(v) => values.push(v.value_int)
      None => values.push(0L)
    }
  }
  values.rev_in_place()

  // Calculate byte width
  let mut max_width = 0
  for v in values {
    let width = if v >= -128L && v <= 127L {
      0
    } else if v >= -32768L && v <= 32767L {
      1
    } else if v >= -2147483648L && v <= 2147483647L {
      2
    } else {
      3
    }
    if width > max_width {
      max_width = width
    }
  }
  let byte_width = 1 << max_width

  // Align
  let padding = (byte_width - self.buf.length() % byte_width) % byte_width
  for i = 0; i < padding; i = i + 1 {
    self.buf.push(b'\x00')
    ignore(i)
  }

  // Write length
  flex_write_uint(self.buf, count.to_uint64(), byte_width)
  let vec_offset = self.buf.length()

  // Write values
  for v in values {
    flex_write_int(self.buf, v, byte_width)
  }
  self.stack.push(FlexValue::vector_ref(vec_offset, VectorInt, max_width))
  self
}

///|
/// End a typed vector of floats
pub fn FlexBuilder::end_float_vector(
  self : FlexBuilder,
  count : Int,
) -> FlexBuilder {
  if count == 0 {
    flex_write_uint(self.buf, 0UL, 1)
    self.stack.push(FlexValue::vector_ref(self.buf.length(), VectorFloat, 0))
    return self
  }
  let values : Array[Double] = []
  for i = 0; i < count; i = i + 1 {
    match self.stack.pop() {
      Some(v) => values.push(v.value_float)
      None => values.push(0.0)
    }
  }
  values.rev_in_place()

  // Always use 64-bit for floats
  let byte_width = 8

  // Align
  let padding = (byte_width - self.buf.length() % byte_width) % byte_width
  for i = 0; i < padding; i = i + 1 {
    self.buf.push(b'\x00')
    ignore(i)
  }

  // Write length
  flex_write_uint(self.buf, count.to_uint64(), byte_width)
  let vec_offset = self.buf.length()

  // Write values
  for v in values {
    flex_write_uint(self.buf, v.reinterpret_as_uint64(), byte_width)
  }
  self.stack.push(FlexValue::vector_ref(vec_offset, VectorFloat, 3)) // 3 = 64-bit
  self
}

///|
/// End a vector and push it onto the stack
pub fn FlexBuilder::end_vector(self : FlexBuilder, count : Int) -> FlexBuilder {
  if count == 0 {
    // For empty vector, write length (0) and point to where data would start
    flex_write_uint(self.buf, 0UL, 1)
    self.stack.push(FlexValue::vector_ref(self.buf.length(), Vector, 0))
    return self
  }

  // Pop values from stack
  let values : Array[FlexValue] = []
  for i = 0; i < count; i = i + 1 {
    match self.stack.pop() {
      Some(v) => values.push(v)
      None => ()
    }
  }
  values.rev_in_place()

  // Calculate required byte width
  let mut max_width = 0
  for v in values {
    if v.min_bit_width > max_width {
      max_width = v.min_bit_width
    }
  }
  let byte_width = 1 << max_width

  // Align buffer
  let padding = (byte_width - self.buf.length() % byte_width) % byte_width
  for i = 0; i < padding; i = i + 1 {
    self.buf.push(b'\x00')
    ignore(i)
  }

  // Write length
  flex_write_uint(self.buf, count.to_uint64(), byte_width)

  // vec_offset points to where data starts (AFTER length prefix)
  let vec_offset = self.buf.length()

  // Write values
  for v in values {
    match v.flex_type {
      Int => flex_write_int(self.buf, v.value_int, byte_width)
      UInt => flex_write_uint(self.buf, v.value_uint, byte_width)
      Float =>
        flex_write_uint(
          self.buf,
          v.value_float.reinterpret_as_uint64(),
          byte_width,
        )
      Bool =>
        flex_write_uint(
          self.buf,
          if v.value_int != 0L {
            1UL
          } else {
            0UL
          },
          byte_width,
        )
      Null => flex_write_uint(self.buf, 0UL, byte_width)
      String => {
        let offset_to_string = self.buf.length() - v.offset
        flex_write_uint(self.buf, offset_to_string.to_uint64(), byte_width)
      }
      Vector | VectorInt | VectorUInt | VectorFloat | Map => {
        let offset_to_vec = self.buf.length() - v.offset
        flex_write_uint(self.buf, offset_to_vec.to_uint64(), byte_width)
      }
      _ => flex_write_uint(self.buf, 0UL, byte_width)
    }
  }

  // Write type vector
  for v in values {
    let packed_type = (v.flex_type.to_int() << 2) | v.min_bit_width
    self.buf.push(packed_type.to_byte())
  }
  self.stack.push(FlexValue::vector_ref(vec_offset, Vector, max_width))
  self
}

///|
/// Finish building and get the buffer
pub fn FlexBuilder::finish(self : FlexBuilder) -> FixedArray[Byte] {
  if self.stack.is_empty() {
    ignore(self.add_null())
  }
  let root = match self.stack.pop() {
    Some(v) => v
    None => FlexValue::null()
  }
  let byte_width = 1 << root.min_bit_width

  // Align buffer
  let padding = (byte_width - self.buf.length() % byte_width) % byte_width
  for i = 0; i < padding; i = i + 1 {
    self.buf.push(b'\x00')
    ignore(i)
  }

  // Write root value
  match root.flex_type {
    Int => flex_write_int(self.buf, root.value_int, byte_width)
    UInt => flex_write_uint(self.buf, root.value_uint, byte_width)
    Float =>
      flex_write_uint(
        self.buf,
        root.value_float.reinterpret_as_uint64(),
        byte_width,
      )
    Bool =>
      flex_write_uint(
        self.buf,
        if root.value_int != 0L {
          1UL
        } else {
          0UL
        },
        byte_width,
      )
    Null => flex_write_uint(self.buf, 0UL, byte_width)
    String | Key => {
      let offset_to_string = self.buf.length() - root.offset
      flex_write_uint(self.buf, offset_to_string.to_uint64(), byte_width)
    }
    Blob => {
      let offset_to_blob = self.buf.length() - root.offset
      flex_write_uint(self.buf, offset_to_blob.to_uint64(), byte_width)
    }
    Vector | VectorInt | VectorUInt | VectorFloat | VectorBool | Map => {
      let offset_to_vec = self.buf.length() - root.offset
      flex_write_uint(self.buf, offset_to_vec.to_uint64(), byte_width)
    }
    _ => flex_write_uint(self.buf, 0UL, byte_width)
  }

  // Write packed type (type << 2 | bit_width)
  let packed_type = (root.flex_type.to_int() << 2) | root.min_bit_width
  self.buf.push(packed_type.to_byte())

  // Write byte width
  self.buf.push(byte_width.to_byte())

  // Convert to FixedArray
  let result : FixedArray[Byte] = FixedArray::make(self.buf.length(), b'\x00')
  for i, b in self.buf {
    result[i] = b
  }
  result
}

// =============================================================================
// Convenience API
// =============================================================================

///|
/// Parse FlexBuffer from bytes
pub fn flex_parse(data : FixedArray[Byte]) -> FlexRef {
  FlexRef::from_bytes(data)
}

///|
/// Get the type of a FlexRef
pub fn FlexRef::get_type(self : FlexRef) -> FlexType {
  self.flex_type
}

///|
/// Check if this is a Map
pub fn FlexRef::is_map(self : FlexRef) -> Bool {
  match self.flex_type {
    Map => true
    _ => false
  }
}

///|
/// Check if this is a Vector
pub fn FlexRef::is_vector(self : FlexRef) -> Bool {
  match self.flex_type {
    Vector
    | VectorInt
    | VectorUInt
    | VectorFloat
    | VectorKey
    | VectorString
    | VectorBool
    | VectorInt2
    | VectorUInt2
    | VectorFloat2
    | VectorInt3
    | VectorUInt3
    | VectorFloat3
    | VectorInt4
    | VectorUInt4
    | VectorFloat4 => true
    _ => false
  }
}

///|
/// Read a null-terminated key string at offset
fn read_key_at(data : FixedArray[Byte], offset : Int) -> String {
  let bytes : Array[Byte] = []
  let mut i = offset
  while i < data.length() && data[i] != b'\x00' {
    bytes.push(data[i])
    i = i + 1
  }
  bytes_to_string(bytes)
}

///|
/// Get value from map by key
pub fn FlexRef::get_by_key(self : FlexRef, key : String) -> FlexRef {
  match self.flex_type {
    Map => {
      let len = self.length()
      if len == 0 {
        return {
          data: self.data,
          offset: 0,
          parent_width: 1,
          byte_width: 1,
          flex_type: Null,
        }
      }
      // Values are at indirect_offset, keys vector is before that
      let values_offset = self.indirect_offset()
      let keys_offset = values_offset - self.byte_width - len * self.byte_width

      // Search for key
      for i = 0; i < len; i = i + 1 {
        let key_ptr_offset = keys_offset + i * self.byte_width
        let key_rel_offset = flex_read_uint(
          self.data,
          key_ptr_offset,
          self.byte_width,
        ).to_int()
        let key_offset = key_ptr_offset - key_rel_offset
        let found_key = read_key_at(self.data, key_offset)
        if found_key == key {
          // Found! Return the value at this index
          let types_offset = values_offset + len * self.byte_width
          let elem_type = FlexType::from_int(
            self.data[types_offset + i].to_int() >> 2,
          )
          let elem_width = 1 << (self.data[types_offset + i].to_int() & 3)
          return {
            data: self.data,
            offset: values_offset + i * self.byte_width,
            parent_width: self.byte_width,
            byte_width: elem_width,
            flex_type: elem_type,
          }
        }
      }
      // Key not found
      {
        data: self.data,
        offset: 0,
        parent_width: 1,
        byte_width: 1,
        flex_type: Null,
      }
    }
    _ =>
      {
        data: self.data,
        offset: 0,
        parent_width: 1,
        byte_width: 1,
        flex_type: Null,
      }
  }
}

///|
/// Get all keys from a map
pub fn FlexRef::keys(self : FlexRef) -> Array[String] {
  let result : Array[String] = []
  match self.flex_type {
    Map => {
      let len = self.length()
      if len == 0 {
        return result
      }
      let values_offset = self.indirect_offset()
      let keys_offset = values_offset - self.byte_width - len * self.byte_width
      for i = 0; i < len; i = i + 1 {
        let key_ptr_offset = keys_offset + i * self.byte_width
        let key_rel_offset = flex_read_uint(
          self.data,
          key_ptr_offset,
          self.byte_width,
        ).to_int()
        let key_offset = key_ptr_offset - key_rel_offset
        result.push(read_key_at(self.data, key_offset))
      }
    }
    _ => ()
  }
  result
}
