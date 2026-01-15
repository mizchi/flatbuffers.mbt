///|
/// FlatBuffers Schema Parser and MoonBit Code Generator
/// Parses .fbs schema files and generates MoonBit code.

// =============================================================================
// Schema AST Types
// =============================================================================

///|
/// Scalar types in FlatBuffers
pub enum ScalarType {
  Bool
  Byte
  UByte
  Short
  UShort
  Int
  UInt
  Long
  ULong
  Float
  Double
}

///|
pub fn ScalarType::from_string(s : String) -> ScalarType? {
  match s {
    "bool" => Some(Bool)
    "byte" | "int8" => Some(Byte)
    "ubyte" | "uint8" => Some(UByte)
    "short" | "int16" => Some(Short)
    "ushort" | "uint16" => Some(UShort)
    "int" | "int32" => Some(Int)
    "uint" | "uint32" => Some(UInt)
    "long" | "int64" => Some(Long)
    "ulong" | "uint64" => Some(ULong)
    "float" | "float32" => Some(Float)
    "double" | "float64" => Some(Double)
    _ => None
  }
}

///|
pub fn ScalarType::to_moonbit_type(self : ScalarType) -> String {
  match self {
    Bool => "Bool"
    Byte => "Int"
    UByte => "Int"
    Short => "Int"
    UShort => "Int"
    Int => "Int"
    UInt => "UInt"
    Long => "Int64"
    ULong => "UInt64"
    Float => "Float"
    Double => "Double"
  }
}

///|
pub fn ScalarType::to_builder_method(self : ScalarType) -> String {
  match self {
    Bool => "add_bool"
    Byte => "add_int8"
    UByte => "add_uint8"
    Short => "add_int16"
    UShort => "add_uint16"
    Int => "add_int32"
    UInt => "add_uint32"
    Long => "add_int64"
    ULong => "add_uint64"
    Float => "add_float32"
    Double => "add_float64"
  }
}

///|
pub fn ScalarType::to_getter_method(self : ScalarType) -> String {
  match self {
    Bool => "get_bool"
    Byte => "get_int8"
    UByte => "get_uint8"
    Short => "get_int16"
    UShort => "get_uint16"
    Int => "get_int32"
    UInt => "get_uint32"
    Long => "get_int64"
    ULong => "get_uint64"
    Float => "get_float32"
    Double => "get_float64"
  }
}

///|
pub fn ScalarType::default_value(self : ScalarType) -> String {
  match self {
    Bool => "false"
    Float | Double => "0.0"
    _ => "0"
  }
}

///|
/// Field type in schema
pub enum FieldTypeAst {
  Scalar(ScalarType)
  String
  Vector(FieldTypeAst)
  Reference(String) // Reference to another type (enum, struct, table)
}

///|
/// Field definition in schema
pub struct FieldAst {
  name : String
  field_type : FieldTypeAst
  default_value : String?
  deprecated : Bool
  id : Int? // explicit field id
}

///|
/// Enum value definition
pub struct EnumValueAst {
  name : String
  value : Int?
}

///|
/// Enum definition in schema
pub struct EnumAst {
  name : String
  base_type : ScalarType
  bit_flags : Bool
  values : Array[EnumValueAst]
}

///|
/// Struct definition in schema (fixed-size)
pub struct StructAst {
  name : String
  fields : Array[FieldAst]
}

///|
/// Table definition in schema (variable-size)
pub struct TableAst {
  name : String
  fields : Array[FieldAst]
}

///|
/// Union definition in schema
pub struct UnionAst {
  name : String
  types : Array[String]
}

///|
/// Schema definition
pub struct SchemaAst {
  mut ns : String // namespace (reserved word)
  enums : Array[EnumAst]
  structs : Array[StructAst]
  tables : Array[TableAst]
  unions : Array[UnionAst]
  mut root_type : String?
}

///|
pub fn SchemaAst::new() -> SchemaAst {
  { ns: "", enums: [], structs: [], tables: [], unions: [], root_type: None }
}

// =============================================================================
// Simple FBS Parser
// =============================================================================

///|
/// Get char from string at index
fn string_char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
/// Parser state
priv struct Parser {
  input : String
  mut pos : Int
  mut line : Int
  mut col : Int
}

///|
fn Parser::new(input : String) -> Parser {
  { input, pos: 0, line: 1, col: 1 }
}

///|
fn Parser::peek(self : Parser) -> Char? {
  if self.pos < self.input.length() {
    Some(string_char_at(self.input, self.pos))
  } else {
    None
  }
}

///|
fn Parser::advance(self : Parser) -> Char? {
  if self.pos < self.input.length() {
    let c = string_char_at(self.input, self.pos)
    self.pos = self.pos + 1
    if c == '\n' {
      self.line = self.line + 1
      self.col = 1
    } else {
      self.col = self.col + 1
    }
    Some(c)
  } else {
    None
  }
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  while true {
    match self.peek() {
      Some(' ') | Some('\t') | Some('\n') | Some('\r') => ignore(self.advance())
      Some('/') =>
        // Check for comments
        if self.pos + 1 < self.input.length() &&
          string_char_at(self.input, self.pos + 1) == '/' {
          // Line comment
          while true {
            match self.peek() {
              Some('\n') | None => break
              _ => ignore(self.advance())
            }
          }
        } else if self.pos + 1 < self.input.length() &&
          string_char_at(self.input, self.pos + 1) == '*' {
          // Block comment
          ignore(self.advance()) // /
          ignore(self.advance()) // *
          while true {
            match self.peek() {
              None => break
              Some('*') => {
                ignore(self.advance())
                match self.peek() {
                  Some('/') => {
                    ignore(self.advance())
                    break
                  }
                  _ => ()
                }
              }
              _ => ignore(self.advance())
            }
          }
        } else {
          break
        }
      _ => break
    }
  }
}

///|
fn Parser::parse_identifier(self : Parser) -> String {
  self.skip_whitespace()
  let result : Array[Char] = []
  while true {
    match self.peek() {
      Some(c) =>
        if is_identifier_char(c) {
          result.push(c)
          ignore(self.advance())
        } else {
          break
        }
      None => break
    }
  }
  String::from_array(result)
}

///|
fn is_identifier_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '.'
}

///|
fn Parser::expect(self : Parser, expected : Char) -> Bool {
  self.skip_whitespace()
  match self.peek() {
    Some(c) if c == expected => {
      ignore(self.advance())
      true
    }
    _ => false
  }
}

///|
fn Parser::parse_number(self : Parser) -> Int {
  self.skip_whitespace()
  let result : Array[Char] = []
  let mut negative = false
  match self.peek() {
    Some('-') => {
      negative = true
      ignore(self.advance())
    }
    _ => ()
  }
  while true {
    match self.peek() {
      Some(c) if c >= '0' && c <= '9' => {
        result.push(c)
        ignore(self.advance())
      }
      _ => break
    }
  }
  let num = if result.is_empty() { 0 } else { parse_int_from_chars(result) }
  if negative {
    -num
  } else {
    num
  }
}

///|
fn parse_int_from_chars(chars : Array[Char]) -> Int {
  let mut result = 0
  for c in chars {
    result = result * 10 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn Parser::parse_string_literal(self : Parser) -> String {
  self.skip_whitespace()
  if not(self.expect('\u{22}')) {
    return ""
  }
  let result : Array[Char] = []
  while true {
    match self.peek() {
      Some('\u{22}') => {
        ignore(self.advance())
        break
      }
      Some('\\') => {
        ignore(self.advance())
        match self.peek() {
          Some('n') => {
            result.push('\n')
            ignore(self.advance())
          }
          Some('t') => {
            result.push('\t')
            ignore(self.advance())
          }
          Some(c) => {
            result.push(c)
            ignore(self.advance())
          }
          None => break
        }
      }
      Some(c) => {
        result.push(c)
        ignore(self.advance())
      }
      None => break
    }
  }
  String::from_array(result)
}

///|
fn Parser::parse_field_type(self : Parser) -> FieldTypeAst {
  self.skip_whitespace()
  // Check for vector type [type]
  if self.expect('[') {
    let inner = self.parse_field_type()
    ignore(self.expect(']'))
    return Vector(inner)
  }
  let type_name = self.parse_identifier()
  match type_name {
    "string" => String
    _ =>
      match ScalarType::from_string(type_name) {
        Some(scalar) => Scalar(scalar)
        None => Reference(type_name)
      }
  }
}

///|
fn Parser::skip_attributes(self : Parser) -> Unit {
  self.skip_whitespace()
  if self.expect('(') {
    let mut depth = 1
    while depth > 0 {
      match self.peek() {
        Some('(') => {
          depth = depth + 1
          ignore(self.advance())
        }
        Some(')') => {
          depth = depth - 1
          ignore(self.advance())
        }
        Some(_) => ignore(self.advance())
        None => break
      }
    }
  }
}

///|
fn Parser::parse_field(self : Parser) -> FieldAst? {
  self.skip_whitespace()
  let name = self.parse_identifier()
  if name.is_empty() {
    return None
  }
  if not(self.expect(':')) {
    return None
  }
  let field_type = self.parse_field_type()
  self.skip_whitespace()
  // Check for default value
  let default_value = if self.expect('=') {
    self.skip_whitespace()
    // Could be a number, identifier, or string
    match self.peek() {
      Some(c) if (c >= '0' && c <= '9') || c == '-' =>
        Some(self.parse_number().to_string())
      Some('\u{22}') => Some(self.parse_string_literal())
      _ => {
        let id = self.parse_identifier()
        if id.is_empty() {
          None
        } else {
          Some(id)
        }
      }
    }
  } else {
    None
  }
  // Skip attributes like (deprecated, id: 1)
  self.skip_attributes()
  ignore(self.expect(';'))
  Some({ name, field_type, default_value, deprecated: false, id: None })
}

///|
fn Parser::parse_enum(self : Parser) -> EnumAst? {
  let name = self.parse_identifier()
  if name.is_empty() {
    return None
  }
  self.skip_whitespace()
  // Parse base type
  let base_type = if self.expect(':') {
    let type_name = self.parse_identifier()
    match ScalarType::from_string(type_name) {
      Some(t) => t
      None => UByte
    }
  } else {
    Int
  }
  // Skip attributes
  self.skip_attributes()
  if not(self.expect('{')) {
    return None
  }
  // Parse values
  let values : Array[EnumValueAst] = []
  while true {
    self.skip_whitespace()
    if self.expect('}') {
      break
    }
    let value_name = self.parse_identifier()
    if value_name.is_empty() {
      break
    }
    let value = if self.expect('=') { Some(self.parse_number()) } else { None }
    values.push({ name: value_name, value })
    ignore(self.expect(','))
  }
  Some({ name, base_type, bit_flags: false, values })
}

///|
fn Parser::parse_struct(self : Parser) -> StructAst? {
  let name = self.parse_identifier()
  if name.is_empty() {
    return None
  }
  self.skip_attributes()
  if not(self.expect('{')) {
    return None
  }
  let fields : Array[FieldAst] = []
  while true {
    self.skip_whitespace()
    if self.expect('}') {
      break
    }
    match self.parse_field() {
      Some(field) => fields.push(field)
      None => break
    }
  }
  Some({ name, fields })
}

///|
fn Parser::parse_table(self : Parser) -> TableAst? {
  let name = self.parse_identifier()
  if name.is_empty() {
    return None
  }
  self.skip_attributes()
  if not(self.expect('{')) {
    return None
  }
  let fields : Array[FieldAst] = []
  while true {
    self.skip_whitespace()
    if self.expect('}') {
      break
    }
    match self.parse_field() {
      Some(field) => fields.push(field)
      None => break
    }
  }
  Some({ name, fields })
}

///|
fn Parser::parse_union(self : Parser) -> UnionAst? {
  let name = self.parse_identifier()
  if name.is_empty() {
    return None
  }
  if not(self.expect('{')) {
    return None
  }
  let types : Array[String] = []
  while true {
    self.skip_whitespace()
    if self.expect('}') {
      break
    }
    let type_name = self.parse_identifier()
    if type_name.is_empty() {
      break
    }
    // Skip alias (e.g., M: Monster -> Monster)
    if self.expect(':') {
      let actual = self.parse_identifier()
      types.push(actual)
    } else {
      types.push(type_name)
    }
    ignore(self.expect(','))
  }
  Some({ name, types })
}

///|
/// Parse a FlatBuffers schema
pub fn parse_schema(input : String) -> SchemaAst {
  let parser = Parser::new(input)
  let schema = SchemaAst::new()
  while true {
    parser.skip_whitespace()
    if parser.pos >= parser.input.length() {
      break
    }
    let keyword = parser.parse_identifier()
    match keyword {
      "namespace" => {
        let ns = parser.parse_identifier()
        schema.ns = ns
        ignore(parser.expect(';'))
      }
      "enum" =>
        match parser.parse_enum() {
          Some(e) => schema.enums.push(e)
          None => ()
        }
      "struct" =>
        match parser.parse_struct() {
          Some(s) => schema.structs.push(s)
          None => ()
        }
      "table" =>
        match parser.parse_table() {
          Some(t) => schema.tables.push(t)
          None => ()
        }
      "union" =>
        match parser.parse_union() {
          Some(u) => schema.unions.push(u)
          None => ()
        }
      "root_type" => {
        let rt = parser.parse_identifier()
        schema.root_type = Some(rt)
        ignore(parser.expect(';'))
      }
      "include" | "attribute" | "file_identifier" | "file_extension" =>
        // Skip these directives
        while true {
          match parser.peek() {
            Some(';') => {
              ignore(parser.advance())
              break
            }
            Some(_) => ignore(parser.advance())
            None => break
          }
        }
      "" => break
      _ =>
        // Skip unknown tokens
        ()
    }
  }
  schema
}

// =============================================================================
// Code Generator
// =============================================================================

///|
/// Generate MoonBit code from schema
pub fn generate_moonbit(schema : SchemaAst) -> String {
  let code : Array[String] = []
  // Header
  code.push("///|")
  code.push("/// Auto-generated FlatBuffers code")
  code.push("/// DO NOT EDIT")
  code.push("")
  // Generate enums
  for enum_def in schema.enums {
    code.push(generate_enum(enum_def))
    code.push("")
  }
  // Generate structs
  for struct_def in schema.structs {
    code.push(generate_struct(struct_def))
    code.push("")
  }
  // Generate unions
  for union_def in schema.unions {
    code.push(generate_union(union_def))
    code.push("")
  }
  // Generate tables
  for table_def in schema.tables {
    code.push(generate_table(table_def, schema))
    code.push("")
  }
  code.join("\n")
}

///|
fn generate_enum(enum_def : EnumAst) -> String {
  let lines : Array[String] = []
  lines.push("///|")
  lines.push("pub enum " + enum_def.name + " {")
  let mut next_value = 0
  for v in enum_def.values {
    let value = match v.value {
      Some(n) => {
        next_value = n + 1
        n
      }
      None => {
        let n = next_value
        next_value = next_value + 1
        n
      }
    }
    lines.push("  " + v.name + " // = " + value.to_string())
  }
  lines.push("}")
  lines.push("")
  // Add to_int method
  lines.push("///|")
  lines.push(
    "pub fn " +
    enum_def.name +
    "::to_int(self : " +
    enum_def.name +
    ") -> Int {",
  )
  lines.push("  match self {")
  next_value = 0
  for v in enum_def.values {
    let value = match v.value {
      Some(n) => {
        next_value = n + 1
        n
      }
      None => {
        let n = next_value
        next_value = next_value + 1
        n
      }
    }
    lines.push("    " + v.name + " => " + value.to_string())
  }
  lines.push("  }")
  lines.push("}")
  lines.push("")
  // Add from_int method
  lines.push("///|")
  lines.push(
    "pub fn " +
    enum_def.name +
    "::from_int(value : Int) -> " +
    enum_def.name +
    "? {",
  )
  lines.push("  match value {")
  next_value = 0
  for v in enum_def.values {
    let value = match v.value {
      Some(n) => {
        next_value = n + 1
        n
      }
      None => {
        let n = next_value
        next_value = next_value + 1
        n
      }
    }
    lines.push("    " + value.to_string() + " => Some(" + v.name + ")")
  }
  lines.push("    _ => None")
  lines.push("  }")
  lines.push("}")
  lines.join("\n")
}

///|
/// Calculate struct size in bytes
fn calc_struct_size(struct_def : StructAst) -> Int {
  let mut size = 0
  for field in struct_def.fields {
    match field.field_type {
      Scalar(scalar_type) =>
        match scalar_type {
          Bool | Byte | UByte => size = size + 1
          Short | UShort => size = size + 2
          Int | UInt | Float => size = size + 4
          Long | ULong | Double => size = size + 8
        }
      _ => size = size + 4 // Assume 4 bytes for references
    }
  }
  size
}

///|
/// Generate struct code (fixed-size inline data)
fn generate_struct(struct_def : StructAst) -> String {
  let lines : Array[String] = []
  let name = struct_def.name
  let size = calc_struct_size(struct_def)

  // Generate struct reader
  lines.push("///|")
  lines.push(
    "/// " + name + " struct reader (size: " + size.to_string() + " bytes)",
  )
  lines.push("pub struct " + name + " {")
  lines.push("  buf : @flatbuffers.ByteBuffer")
  lines.push("  pos : Int")
  lines.push("}")
  lines.push("")

  // Generate constructor
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "::new(buf : @flatbuffers.ByteBuffer, pos : Int) -> " +
    name +
    " {",
  )
  lines.push("  { buf, pos }")
  lines.push("}")
  lines.push("")

  // Generate field getters
  let mut offset = 0
  for field in struct_def.fields {
    let field_size = match field.field_type {
      Scalar(scalar_type) =>
        match scalar_type {
          Bool | Byte | UByte => 1
          Short | UShort => 2
          Int | UInt | Float => 4
          Long | ULong | Double => 8
        }
      _ => 4
    }
    match field.field_type {
      Scalar(scalar_type) => {
        let moonbit_type = scalar_type.to_moonbit_type()
        let read_method = match scalar_type {
          Bool => "read_bool"
          Byte => "read_int8"
          UByte => "read_uint8"
          Short => "read_int16"
          UShort => "read_uint16"
          Int => "read_int32"
          UInt => "read_uint32"
          Long => "read_int64"
          ULong => "read_uint64"
          Float => "read_float32"
          Double => "read_float64"
        }
        lines.push("///|")
        lines.push(
          "pub fn " +
          name +
          "::" +
          field.name +
          "(self : " +
          name +
          ") -> " +
          moonbit_type +
          " {",
        )
        lines.push(
          "  self.buf." +
          read_method +
          "(self.pos + " +
          offset.to_string() +
          ")",
        )
        lines.push("}")
        lines.push("")
      }
      _ => ()
    }
    offset = offset + field_size
  }

  // Generate struct builder
  lines.push("///|")
  lines.push("/// " + name + " struct builder")
  lines.push("pub struct " + name + "Builder {")
  lines.push("  builder : @flatbuffers.Builder")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "Builder::new(builder : @flatbuffers.Builder) -> " +
    name +
    "Builder {",
  )
  lines.push("  { builder }")
  lines.push("}")
  lines.push("")

  // Generate create method that takes all fields
  lines.push("///|")
  let params : Array[String] = []
  for field in struct_def.fields {
    match field.field_type {
      Scalar(scalar_type) => {
        let moonbit_type = scalar_type.to_moonbit_type()
        params.push(field.name + " : " + moonbit_type)
      }
      _ => ()
    }
  }
  lines.push(
    "pub fn " +
    name +
    "Builder::create(self : " +
    name +
    "Builder, " +
    params.join(", ") +
    ") -> Int {",
  )
  lines.push("  self.builder.prep(" + size.to_string() + ", 0)")

  // Write fields in reverse order (FlatBuffers are built backwards)
  let mut rev_offset = size
  let fields_rev = struct_def.fields.copy()
  fields_rev.rev_in_place()
  for field in fields_rev {
    match field.field_type {
      Scalar(scalar_type) => {
        let field_size = match scalar_type {
          Bool | Byte | UByte => 1
          Short | UShort => 2
          Int | UInt | Float => 4
          Long | ULong | Double => 8
        }
        rev_offset = rev_offset - field_size
        let write_method = match scalar_type {
          Bool => "place_bool"
          Byte => "place_int8"
          UByte => "place_uint8"
          Short => "place_int16"
          UShort => "place_uint16"
          Int => "place_int32"
          UInt => "place_uint32"
          Long => "place_int64"
          ULong => "place_uint64"
          Float => "place_float32"
          Double => "place_float64"
        }
        lines.push("  self.builder." + write_method + "(" + field.name + ")")
      }
      _ => ()
    }
  }
  lines.push("  self.builder.offset()")
  lines.push("}")
  lines.join("\n")
}

///|
/// Generate union code
fn generate_union(union_def : UnionAst) -> String {
  let lines : Array[String] = []
  let name = union_def.name

  // Generate union type enum
  lines.push("///|")
  lines.push("/// " + name + " union type")
  lines.push("pub enum " + name + "Type {")
  lines.push("  None // = 0")
  for i, type_name in union_def.types {
    lines.push("  " + type_name + " // = " + (i + 1).to_string())
  }
  lines.push("}")
  lines.push("")

  // Generate to_int method
  lines.push("///|")
  lines.push(
    "pub fn " + name + "Type::to_int(self : " + name + "Type) -> Int {",
  )
  lines.push("  match self {")
  lines.push("    None => 0")
  for i, type_name in union_def.types {
    lines.push("    " + type_name + " => " + (i + 1).to_string())
  }
  lines.push("  }")
  lines.push("}")
  lines.push("")

  // Generate from_int method
  lines.push("///|")
  lines.push(
    "pub fn " + name + "Type::from_int(value : Int) -> " + name + "Type {",
  )
  lines.push("  match value {")
  for i, type_name in union_def.types {
    lines.push("    " + (i + 1).to_string() + " => " + type_name)
  }
  lines.push("    _ => None")
  lines.push("  }")
  lines.push("}")
  lines.push("")

  // Generate union reader struct
  lines.push("///|")
  lines.push("/// " + name + " union reader")
  lines.push("pub struct " + name + " {")
  lines.push("  union_type : " + name + "Type")
  lines.push("  table : @flatbuffers.Table?")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "::new(union_type : " +
    name +
    "Type, table : @flatbuffers.Table?) -> " +
    name +
    " {",
  )
  lines.push("  { union_type, table }")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "pub fn " + name + "::get_type(self : " + name + ") -> " + name + "Type {",
  )
  lines.push("  self.union_type")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "::get_table(self : " +
    name +
    ") -> @flatbuffers.Table? {",
  )
  lines.push("  self.table")
  lines.push("}")
  lines.join("\n")
}

///|
fn generate_table(table_def : TableAst, schema : SchemaAst) -> String {
  let lines : Array[String] = []
  let name = table_def.name
  // Generate reader struct
  lines.push("///|")
  lines.push("/// " + name + " reader")
  lines.push("pub struct " + name + " {")
  lines.push("  table : @flatbuffers.Table")
  lines.push("}")
  lines.push("")
  // Generate constructor from buffer
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "::from_buffer(buf : @flatbuffers.ByteBuffer) -> " +
    name +
    " {",
  )
  lines.push("  { table: @flatbuffers.Table::get_root(buf) }")
  lines.push("}")
  lines.push("")
  // Generate getters for each field
  for i, field in table_def.fields {
    let slot = i
    let getter = generate_field_getter(name, field, slot, schema)
    lines.push(getter)
    lines.push("")
  }
  // Generate builder struct
  lines.push("///|")
  lines.push("/// " + name + " builder")
  lines.push("pub struct " + name + "Builder {")
  lines.push("  builder : @flatbuffers.Builder")
  lines.push("  string_offsets : Map[String, Int]")
  lines.push("  vector_offsets : Map[String, Int]")
  lines.push("}")
  lines.push("")
  // Generate builder constructor
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "Builder::new(builder : @flatbuffers.Builder) -> " +
    name +
    "Builder {",
  )
  lines.push("  { builder, string_offsets: {}, vector_offsets: {} }")
  lines.push("}")
  lines.push("")
  // Generate setters for offset types (must be called before start)
  for field in table_def.fields {
    match field.field_type {
      String => {
        lines.push("///|")
        lines.push(
          "pub fn " +
          name +
          "Builder::set_" +
          field.name +
          "(self : " +
          name +
          "Builder, value : String) -> " +
          name +
          "Builder {",
        )
        lines.push("  let offset = self.builder.create_string(value)")
        lines.push("  self.string_offsets.set(\"" + field.name + "\", offset)")
        lines.push("  self")
        lines.push("}")
        lines.push("")
      }
      Vector(_) => {
        lines.push("///|")
        lines.push(
          "pub fn " +
          name +
          "Builder::set_" +
          field.name +
          "_offset(self : " +
          name +
          "Builder, offset : Int) -> " +
          name +
          "Builder {",
        )
        lines.push("  self.vector_offsets.set(\"" + field.name + "\", offset)")
        lines.push("  self")
        lines.push("}")
        lines.push("")
      }
      _ => ()
    }
  }
  // Generate start method
  lines.push("///|")
  lines.push(
    "pub fn " + name + "Builder::start(self : " + name + "Builder) -> Unit {",
  )
  lines.push(
    "  self.builder.start_object(" + table_def.fields.length().to_string() + ")",
  )
  lines.push("}")
  lines.push("")
  // Generate add methods for scalar fields
  for i, field in table_def.fields {
    let slot = i
    match field.field_type {
      Scalar(scalar_type) => {
        let moonbit_type = scalar_type.to_moonbit_type()
        let builder_method = scalar_type.to_builder_method()
        let default = match field.default_value {
          Some(d) => d
          None => scalar_type.default_value()
        }
        lines.push("///|")
        lines.push(
          "pub fn " +
          name +
          "Builder::add_" +
          field.name +
          "(self : " +
          name +
          "Builder, value : " +
          moonbit_type +
          ") -> " +
          name +
          "Builder {",
        )
        lines.push(
          "  self.builder." +
          builder_method +
          "(" +
          slot.to_string() +
          ", value, " +
          default +
          ")",
        )
        lines.push("  self")
        lines.push("}")
        lines.push("")
      }
      _ => ()
    }
  }
  // Generate finish_fields method
  lines.push("///|")
  lines.push(
    "pub fn " +
    name +
    "Builder::finish_fields(self : " +
    name +
    "Builder) -> Unit {",
  )
  for i, field in table_def.fields {
    let slot = i
    match field.field_type {
      String => {
        lines.push("  match self.string_offsets.get(\"" + field.name + "\") {")
        lines.push(
          "    Some(offset) => self.builder.add_offset(" +
          slot.to_string() +
          ", offset)",
        )
        lines.push("    None => ()")
        lines.push("  }")
      }
      Vector(_) => {
        lines.push("  match self.vector_offsets.get(\"" + field.name + "\") {")
        lines.push(
          "    Some(offset) => self.builder.add_offset(" +
          slot.to_string() +
          ", offset)",
        )
        lines.push("    None => ()")
        lines.push("  }")
      }
      _ => ()
    }
  }
  lines.push("}")
  lines.push("")
  // Generate end method
  lines.push("///|")
  lines.push(
    "pub fn " + name + "Builder::end(self : " + name + "Builder) -> Int {",
  )
  lines.push("  self.finish_fields()")
  lines.push("  self.builder.end_object()")
  lines.push("}")
  lines.push("")
  // Generate finish method
  lines.push("///|")
  lines.push(
    "pub fn " + name + "Builder::finish(self : " + name + "Builder) -> Unit {",
  )
  lines.push("  let offset = self.end()")
  lines.push("  self.builder.finish(offset)")
  lines.push("}")
  lines.join("\n")
}

///|
/// Resolve enum default value name to integer
fn resolve_enum_default(
  schema : SchemaAst,
  enum_name : String,
  default_name : String,
) -> String {
  // First check if it's already a number
  let is_numeric = {
    let mut all_digits = true
    for c in default_name {
      if not((c >= '0' && c <= '9') || c == '-') {
        all_digits = false
        break
      }
    }
    all_digits && not(default_name.is_empty())
  }
  if is_numeric {
    return default_name
  }
  // Look up the enum value by name
  for e in schema.enums {
    if e.name == enum_name {
      let mut next_value = 0
      for v in e.values {
        let value = match v.value {
          Some(n) => {
            next_value = n + 1
            n
          }
          None => {
            let n = next_value
            next_value = next_value + 1
            n
          }
        }
        if v.name == default_name {
          return value.to_string()
        }
      }
    }
  }
  "0"
}

///|
fn is_union_type(schema : SchemaAst, type_name : String) -> Bool {
  for u in schema.unions {
    if u.name == type_name {
      return true
    }
  }
  false
}

///|
fn is_struct_type(schema : SchemaAst, type_name : String) -> Bool {
  for s in schema.structs {
    if s.name == type_name {
      return true
    }
  }
  false
}

///|
fn is_enum_type(schema : SchemaAst, type_name : String) -> Bool {
  for e in schema.enums {
    if e.name == type_name {
      return true
    }
  }
  false
}

///|
fn generate_field_getter(
  type_name : String,
  field : FieldAst,
  slot : Int,
  schema : SchemaAst,
) -> String {
  let lines : Array[String] = []
  match field.field_type {
    Scalar(scalar_type) => {
      let moonbit_type = scalar_type.to_moonbit_type()
      let getter_method = scalar_type.to_getter_method()
      let default = match field.default_value {
        Some(d) => d
        None => scalar_type.default_value()
      }
      lines.push("///|")
      lines.push(
        "pub fn " +
        type_name +
        "::" +
        field.name +
        "(self : " +
        type_name +
        ") -> " +
        moonbit_type +
        " {",
      )
      lines.push(
        "  self.table." +
        getter_method +
        "(" +
        slot.to_string() +
        ", " +
        default +
        ")",
      )
      lines.push("}")
    }
    String => {
      lines.push("///|")
      lines.push(
        "pub fn " +
        type_name +
        "::" +
        field.name +
        "(self : " +
        type_name +
        ") -> String {",
      )
      lines.push("  self.table.get_string(" + slot.to_string() + ", \"\")")
      lines.push("}")
    }
    Vector(elem_type) => {
      lines.push("///|")
      lines.push(
        "pub fn " +
        type_name +
        "::" +
        field.name +
        "_length(self : " +
        type_name +
        ") -> Int {",
      )
      lines.push("  self.table.get_vector_length(" + slot.to_string() + ")")
      lines.push("}")
      match elem_type {
        Scalar(UByte) => {
          lines.push("")
          lines.push("///|")
          lines.push(
            "pub fn " +
            type_name +
            "::" +
            field.name +
            "(self : " +
            type_name +
            ", index : Int) -> Byte {",
          )
          lines.push(
            "  self.table.get_vector_byte(" + slot.to_string() + ", index)",
          )
          lines.push("}")
        }
        Scalar(Int) => {
          lines.push("")
          lines.push("///|")
          lines.push(
            "pub fn " +
            type_name +
            "::" +
            field.name +
            "(self : " +
            type_name +
            ", index : Int) -> Int {",
          )
          lines.push(
            "  self.table.get_vector_int32(" + slot.to_string() + ", index)",
          )
          lines.push("}")
        }
        Reference(ref_name) => {
          // Vector of tables
          lines.push("")
          lines.push("///|")
          lines.push(
            "pub fn " +
            type_name +
            "::" +
            field.name +
            "_table(self : " +
            type_name +
            ", index : Int) -> @flatbuffers.Table? {",
          )
          lines.push(
            "  self.table.get_vector_table(" + slot.to_string() + ", index)",
          )
          lines.push("}")
          ignore(ref_name)
        }
        _ => ()
      }
    }
    Reference(ref_type) =>
      // Check if it's a union, struct, enum, or table
      if is_union_type(schema, ref_type) {
        // Union: generates both type getter and value getter
        // Union fields actually use TWO slots: type_slot and value_slot
        // The type is stored at slot, the value at slot+1 (or we use slot-1 for type)
        // In FlatBuffers convention, union type is at field index N, union value at N+1
        lines.push("///|")
        lines.push("/// Get " + field.name + " union type")
        lines.push(
          "pub fn " +
          type_name +
          "::" +
          field.name +
          "_type(self : " +
          type_name +
          ") -> " +
          ref_type +
          "Type {",
        )
        lines.push(
          "  " +
          ref_type +
          "Type::from_int(self.table.get_uint8(" +
          slot.to_string() +
          ", 0))",
        )
        lines.push("}")
        lines.push("")
        lines.push("///|")
        lines.push("/// Get " + field.name + " union value as table")
        lines.push(
          "pub fn " +
          type_name +
          "::" +
          field.name +
          "(self : " +
          type_name +
          ") -> " +
          ref_type +
          " {",
        )
        // Note: the actual value slot is typically the next slot
        let value_slot = slot + 1
        lines.push("  let union_type = self." + field.name + "_type()")
        lines.push(
          "  let table = self.table.get_table(" + value_slot.to_string() + ")",
        )
        lines.push("  " + ref_type + "::new(union_type, table)")
        lines.push("}")
      } else if is_struct_type(schema, ref_type) {
        // Struct: read inline data
        lines.push("///|")
        lines.push(
          "pub fn " +
          type_name +
          "::" +
          field.name +
          "(self : " +
          type_name +
          ") -> " +
          ref_type +
          "? {",
        )
        lines.push("  match self.table.get_struct(" + slot.to_string() + ") {")
        lines.push(
          "    Some(pos) => Some(" + ref_type + "::new(self.table.buf, pos))",
        )
        lines.push("    None => None")
        lines.push("  }")
        lines.push("}")
      } else if is_enum_type(schema, ref_type) {
        // Enum: read as integer and convert
        lines.push("///|")
        lines.push(
          "pub fn " +
          type_name +
          "::" +
          field.name +
          "(self : " +
          type_name +
          ") -> " +
          ref_type +
          "? {",
        )
        // Resolve enum default value to integer
        let default = match field.default_value {
          Some(d) => resolve_enum_default(schema, ref_type, d)
          None => "0"
        }
        lines.push(
          "  " +
          ref_type +
          "::from_int(self.table.get_uint8(" +
          slot.to_string() +
          ", " +
          default +
          "))",
        )
        lines.push("}")
      } else {
        // Regular table reference
        lines.push("///|")
        lines.push(
          "pub fn " +
          type_name +
          "::" +
          field.name +
          "(self : " +
          type_name +
          ") -> @flatbuffers.Table? {",
        )
        lines.push("  self.table.get_table(" + slot.to_string() + ")")
        lines.push("}")
      }
  }
  lines.join("\n")
}
