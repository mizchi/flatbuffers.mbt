///|
/// Binary Schema (.bfbs) - FlatBuffers Reflection API
///
/// This module provides runtime schema reflection capabilities,
/// allowing dynamic inspection of FlatBuffers schemas without
/// compile-time code generation.

// =============================================================================
// Base Types (from reflection.fbs)
// =============================================================================

///|
/// Base types for FlatBuffers fields
pub enum BaseType {
  None // 0
  UType // 1 - union type field
  Bool // 2
  Byte // 3
  UByte // 4
  Short // 5
  UShort // 6
  Int // 7
  UInt // 8
  Long // 9
  ULong // 10
  Float // 11
  Double // 12
  String // 13
  Vector // 14
  Obj // 15 - table or struct
  Union // 16
  Array // 17
  MaxBaseType // 18
} derive(Show)

///|
pub fn BaseType::from_int(value : Int) -> BaseType {
  match value {
    0 => None
    1 => UType
    2 => Bool
    3 => Byte
    4 => UByte
    5 => Short
    6 => UShort
    7 => Int
    8 => UInt
    9 => Long
    10 => ULong
    11 => Float
    12 => Double
    13 => String
    14 => Vector
    15 => Obj
    16 => Union
    17 => Array
    18 => MaxBaseType
    _ => None
  }
}

///|
pub fn BaseType::to_int(self : BaseType) -> Int {
  match self {
    None => 0
    UType => 1
    Bool => 2
    Byte => 3
    UByte => 4
    Short => 5
    UShort => 6
    Int => 7
    UInt => 8
    Long => 9
    ULong => 10
    Float => 11
    Double => 12
    String => 13
    Vector => 14
    Obj => 15
    Union => 16
    Array => 17
    MaxBaseType => 18
  }
}

// =============================================================================
// Type (nested type information)
// =============================================================================

///|
/// Type information for a field
pub struct ReflectionType {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn ReflectionType::new(buf : ByteBuffer, pos : Int) -> ReflectionType {
  { buf, pos }
}

///|
/// Get the base type
pub fn ReflectionType::base_type(self : ReflectionType) -> BaseType {
  let table = Table::new(self.buf, self.pos)
  BaseType::from_int(table.get_int8(0, 0))
}

///|
/// Get the element type (for vectors and arrays)
pub fn ReflectionType::element(self : ReflectionType) -> BaseType {
  let table = Table::new(self.buf, self.pos)
  BaseType::from_int(table.get_int8(1, 0))
}

///|
/// Get the index to the object (for Obj type)
pub fn ReflectionType::index(self : ReflectionType) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_int32(2, -1)
}

///|
/// Get fixed length (for Array type)
pub fn ReflectionType::fixed_length(self : ReflectionType) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_uint16(3, 0)
}

///|
/// Get base size (in bytes)
pub fn ReflectionType::base_size(self : ReflectionType) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_uint32(4, 4U).reinterpret_as_int()
}

///|
/// Get element size (for vectors)
pub fn ReflectionType::element_size(self : ReflectionType) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_uint32(5, 0U).reinterpret_as_int()
}

// =============================================================================
// KeyValue (for attributes)
// =============================================================================

///|
/// Key-value pair for attributes
pub struct KeyValue {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn KeyValue::new(buf : ByteBuffer, pos : Int) -> KeyValue {
  { buf, pos }
}

///|
pub fn KeyValue::key(self : KeyValue) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(0, "")
}

///|
pub fn KeyValue::value(self : KeyValue) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(1, "")
}

// =============================================================================
// EnumVal (enum value)
// =============================================================================

///|
/// An enumeration value
pub struct EnumVal {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn EnumVal::new(buf : ByteBuffer, pos : Int) -> EnumVal {
  { buf, pos }
}

///|
pub fn EnumVal::name(self : EnumVal) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(0, "")
}

///|
pub fn EnumVal::value(self : EnumVal) -> Int64 {
  let table = Table::new(self.buf, self.pos)
  table.get_int64(1, 0L)
}

///|
/// Get union type (for union enum values)
pub fn EnumVal::union_type(self : EnumVal) -> ReflectionType? {
  let table = Table::new(self.buf, self.pos)
  match table.get_table(3) {
    Some(t) => Some(ReflectionType::new(self.buf, t.pos))
    None => None
  }
}

// =============================================================================
// Enum (enumeration type)
// =============================================================================

///|
/// An enumeration type definition
pub struct ReflectionEnum {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn ReflectionEnum::new(buf : ByteBuffer, pos : Int) -> ReflectionEnum {
  { buf, pos }
}

///|
pub fn ReflectionEnum::name(self : ReflectionEnum) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(0, "")
}

///|
pub fn ReflectionEnum::values_length(self : ReflectionEnum) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_vector_length(1)
}

///|
pub fn ReflectionEnum::values(self : ReflectionEnum, index : Int) -> EnumVal? {
  let table = Table::new(self.buf, self.pos)
  match table.get_vector_table(1, index) {
    Some(t) => Some(EnumVal::new(self.buf, t.pos))
    None => None
  }
}

///|
pub fn ReflectionEnum::is_union(self : ReflectionEnum) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(2, false)
}

///|
pub fn ReflectionEnum::underlying_type(
  self : ReflectionEnum,
) -> ReflectionType? {
  let table = Table::new(self.buf, self.pos)
  match table.get_table(3) {
    Some(t) => Some(ReflectionType::new(self.buf, t.pos))
    None => None
  }
}

// =============================================================================
// Field (table/struct field)
// =============================================================================

///|
/// A field definition in a table or struct
pub struct ReflectionField {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn ReflectionField::new(buf : ByteBuffer, pos : Int) -> ReflectionField {
  { buf, pos }
}

///|
pub fn ReflectionField::name(self : ReflectionField) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(0, "")
}

///|
pub fn ReflectionField::field_type(self : ReflectionField) -> ReflectionType? {
  let table = Table::new(self.buf, self.pos)
  match table.get_table(1) {
    Some(t) => Some(ReflectionType::new(self.buf, t.pos))
    None => None
  }
}

///|
pub fn ReflectionField::id(self : ReflectionField) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_uint16(2, 0)
}

///|
pub fn ReflectionField::offset(self : ReflectionField) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_uint16(3, 0)
}

///|
pub fn ReflectionField::default_integer(self : ReflectionField) -> Int64 {
  let table = Table::new(self.buf, self.pos)
  table.get_int64(4, 0L)
}

///|
pub fn ReflectionField::default_real(self : ReflectionField) -> Double {
  let table = Table::new(self.buf, self.pos)
  table.get_float64(5, 0.0)
}

///|
pub fn ReflectionField::deprecated(self : ReflectionField) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(6, false)
}

///|
pub fn ReflectionField::required(self : ReflectionField) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(7, false)
}

///|
pub fn ReflectionField::key(self : ReflectionField) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(8, false)
}

///|
pub fn ReflectionField::optional(self : ReflectionField) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(12, false)
}

// =============================================================================
// Object (table or struct)
// =============================================================================

///|
/// A table or struct definition
pub struct ReflectionObject {
  buf : ByteBuffer
  pos : Int
}

///|
pub fn ReflectionObject::new(buf : ByteBuffer, pos : Int) -> ReflectionObject {
  { buf, pos }
}

///|
pub fn ReflectionObject::name(self : ReflectionObject) -> String {
  let table = Table::new(self.buf, self.pos)
  table.get_string(0, "")
}

///|
pub fn ReflectionObject::fields_length(self : ReflectionObject) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_vector_length(1)
}

///|
pub fn ReflectionObject::fields(
  self : ReflectionObject,
  index : Int,
) -> ReflectionField? {
  let table = Table::new(self.buf, self.pos)
  match table.get_vector_table(1, index) {
    Some(t) => Some(ReflectionField::new(self.buf, t.pos))
    None => None
  }
}

///|
/// Find a field by name
pub fn ReflectionObject::field_by_name(
  self : ReflectionObject,
  name : String,
) -> ReflectionField? {
  let len = self.fields_length()
  for i = 0; i < len; i = i + 1 {
    match self.fields(i) {
      Some(f) => if f.name() == name { return Some(f) }
      None => ()
    }
  }
  None
}

///|
pub fn ReflectionObject::is_struct(self : ReflectionObject) -> Bool {
  let table = Table::new(self.buf, self.pos)
  table.get_bool(2, false)
}

///|
pub fn ReflectionObject::minalign(self : ReflectionObject) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_int32(3, 0)
}

///|
pub fn ReflectionObject::bytesize(self : ReflectionObject) -> Int {
  let table = Table::new(self.buf, self.pos)
  table.get_int32(4, 0)
}

// =============================================================================
// Schema (root type)
// =============================================================================

///|
/// The root schema definition
pub struct ReflectionSchema {
  buf : ByteBuffer
}

///|
/// Parse a binary schema (.bfbs) file
pub fn ReflectionSchema::from_bytes(
  data : FixedArray[Byte],
) -> ReflectionSchema {
  { buf: ByteBuffer::new(data) }
}

///|
/// Check if this is a valid binary schema
pub fn ReflectionSchema::is_valid(self : ReflectionSchema) -> Bool {
  self.buf.has_identifier("BFBS")
}

///|
/// Get the number of objects (tables/structs)
pub fn ReflectionSchema::objects_length(self : ReflectionSchema) -> Int {
  let root = Table::get_root(self.buf)
  root.get_vector_length(0)
}

///|
/// Get an object by index
pub fn ReflectionSchema::objects(
  self : ReflectionSchema,
  index : Int,
) -> ReflectionObject? {
  let root = Table::get_root(self.buf)
  match root.get_vector_table(0, index) {
    Some(t) => Some(ReflectionObject::new(self.buf, t.pos))
    None => None
  }
}

///|
/// Find an object by name
pub fn ReflectionSchema::object_by_name(
  self : ReflectionSchema,
  name : String,
) -> ReflectionObject? {
  let len = self.objects_length()
  for i = 0; i < len; i = i + 1 {
    match self.objects(i) {
      Some(o) => if o.name() == name { return Some(o) }
      None => ()
    }
  }
  None
}

///|
/// Get the number of enums
pub fn ReflectionSchema::enums_length(self : ReflectionSchema) -> Int {
  let root = Table::get_root(self.buf)
  root.get_vector_length(1)
}

///|
/// Get an enum by index
pub fn ReflectionSchema::enums(
  self : ReflectionSchema,
  index : Int,
) -> ReflectionEnum? {
  let root = Table::get_root(self.buf)
  match root.get_vector_table(1, index) {
    Some(t) => Some(ReflectionEnum::new(self.buf, t.pos))
    None => None
  }
}

///|
/// Find an enum by name
pub fn ReflectionSchema::enum_by_name(
  self : ReflectionSchema,
  name : String,
) -> ReflectionEnum? {
  let len = self.enums_length()
  for i = 0; i < len; i = i + 1 {
    match self.enums(i) {
      Some(e) => if e.name() == name { return Some(e) }
      None => ()
    }
  }
  None
}

///|
/// Get the file identifier
pub fn ReflectionSchema::file_ident(self : ReflectionSchema) -> String {
  let root = Table::get_root(self.buf)
  root.get_string(2, "")
}

///|
/// Get the file extension
pub fn ReflectionSchema::file_ext(self : ReflectionSchema) -> String {
  let root = Table::get_root(self.buf)
  root.get_string(3, "")
}

///|
/// Get the root table type
pub fn ReflectionSchema::root_table(
  self : ReflectionSchema,
) -> ReflectionObject? {
  let root = Table::get_root(self.buf)
  match root.get_table(4) {
    Some(t) => Some(ReflectionObject::new(self.buf, t.pos))
    None => None
  }
}

// =============================================================================
// Dynamic Access API
// =============================================================================

///|
/// Read a field value dynamically using reflection
pub fn read_field_dynamic(table : Table, field : ReflectionField) -> JsonValue {
  let field_type = match field.field_type() {
    Some(t) => t
    None => return JsonValue::null()
  }
  let slot = field.id()
  match field_type.base_type() {
    Bool => JsonValue::bool(table.get_bool(slot, false))
    Byte => JsonValue::int(table.get_int8(slot, 0))
    UByte => JsonValue::int(table.get_uint8(slot, 0))
    Short => JsonValue::int(table.get_int16(slot, 0))
    UShort => JsonValue::int(table.get_uint16(slot, 0))
    Int => JsonValue::int(table.get_int32(slot, 0))
    UInt => JsonValue::uint(table.get_uint32(slot, 0U))
    Long => JsonValue::int64(table.get_int64(slot, 0L))
    ULong => JsonValue::uint64(table.get_uint64(slot, 0UL))
    Float => JsonValue::float(table.get_float32(slot, 0.0).to_double())
    Double => JsonValue::float(table.get_float64(slot, 0.0))
    String => JsonValue::string(table.get_string(slot, ""))
    _ => JsonValue::null()
  }
}

///|
/// Convert a table to JSON using schema reflection
pub fn table_to_json_dynamic(
  table : Table,
  obj : ReflectionObject,
) -> JsonValue {
  let fields : Array[(String, JsonValue)] = []
  let len = obj.fields_length()
  for i = 0; i < len; i = i + 1 {
    match obj.fields(i) {
      Some(f) => {
        let value = read_field_dynamic(table, f)
        fields.push((f.name(), value))
      }
      None => ()
    }
  }
  JsonValue::object(fields)
}
