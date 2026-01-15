# FlatBuffers for MoonBit

A pure MoonBit implementation of [Google FlatBuffers](https://google.github.io/flatbuffers/) - an efficient cross-platform serialization library.

## Features

- **Zero-copy deserialization** - Read data directly from buffer without parsing
- **Memory efficient** - No intermediate allocations during read
- **Type safe** - Compile-time type checking
- **Schema support** - Parse `.fbs` schemas and generate MoonBit code
- **Full FlatBuffers compatibility** - Binary format compatible with other languages

## Installation

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "mizchi/flatbuffers": "0.1.0"
  }
}
```

## Quick Start

### Basic Usage

```moonbit
// Create a FlatBuffer
let builder = @flatbuffers.Builder::new()

// Create a string (must be created before the table)
let name = builder.create_string("Alice")

// Build a table with 2 fields
builder.start_object(2)
builder.add_offset(0, name)     // field 0: name (string)
builder.add_int32(1, 30, 0)     // field 1: age (int32, default 0)
let person = builder.end_object()

// Finish the buffer
builder.finish(person)

// Get serialized bytes
let bytes = builder.to_bytes()

// Read it back
let buf = @flatbuffers.ByteBuffer::from_bytes(bytes)
let root = @flatbuffers.Table::get_root(buf)
let name = root.get_string(0, "")   // "Alice"
let age = root.get_int32(1, 0)      // 30
```

### Using Object API (Schema-based)

```moonbit
// Define schema
let schema = @flatbuffers.TableSchema::new("Person", [
  @flatbuffers.FieldDef::new("name", 0, @flatbuffers.FieldType::string()),
  @flatbuffers.FieldDef::with_default_int("age", 1, @flatbuffers.FieldType::int32(), 0),
])

// Build using ObjectBuilder
let builder = @flatbuffers.Builder::new()
let obj = @flatbuffers.ObjectBuilder::new(builder, schema)
  .set_string("name", "Bob")
obj.start()
ignore(obj.add_int32("age", 25))
obj.finish_buffer()

// Read using ObjectReader
let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
let root = @flatbuffers.Table::get_root(buf)
let reader = @flatbuffers.ObjectReader::new(root, schema)
println(reader.get_string("name"))  // "Bob"
println(reader.get_int32("age"))    // 25
```

### Code Generation

Generate MoonBit code from FlatBuffers schema:

```moonbit
///|
let schema_text =
  #|table Monster {
  #|  name:string;
  #|  hp:short = 100;
  #|}

///|
let schema = @flatbuffers.parse_schema(schema_text)

///|
let code = @flatbuffers.generate_moonbit(schema)
// Save `code` to a .mbt file
```

Run the code generator CLI:

```bash
moon run cmd/codegen
```

## API Reference

### Core Types

| Type | Description |
|------|-------------|
| `ByteBuffer` | Read-only buffer for deserialization |
| `Builder` | Mutable builder for serialization |
| `Table` | Reader for table data |

### Builder Methods

```moonbit
// Scalars
builder.add_bool(slot, value, default)
builder.add_int8(slot, value, default)
builder.add_uint8(slot, value, default)
builder.add_int16(slot, value, default)
builder.add_uint16(slot, value, default)
builder.add_int32(slot, value, default)
builder.add_uint32(slot, value, default)
builder.add_int64(slot, value, default)
builder.add_uint64(slot, value, default)
builder.add_float32(slot, value, default)
builder.add_float64(slot, value, default)

// Strings and Vectors
builder.create_string(s)
builder.create_shared_string(s)  // Deduplicates strings
builder.create_byte_vector(data)
builder.create_int32_vector(data)

// Table construction
builder.start_object(num_fields)
builder.add_offset(slot, offset)
builder.end_object() -> Int

// Finishing
builder.finish(root_offset)
builder.finish_with_identifier(root_offset, "FILE")
builder.finish_size_prefixed(root_offset)
```

### Table Reader Methods

```moonbit
// Scalars
table.get_bool(slot, default) -> Bool
table.get_int8(slot, default) -> Int
table.get_int16(slot, default) -> Int
table.get_int32(slot, default) -> Int
table.get_int64(slot, default) -> Int64
table.get_float32(slot, default) -> Float
table.get_float64(slot, default) -> Double

// Strings
table.get_string(slot, default) -> String

// Vectors
table.get_vector_length(slot) -> Int
table.get_vector_byte(slot, index) -> Byte
table.get_vector_int32(slot, index) -> Int

// Nested tables
table.get_table(slot) -> Table?

// Unions
table.get_union_type(slot) -> Int
table.get_union_table(slot) -> Table?
```

### Advanced Features

#### Shared Strings

Reduce buffer size by deduplicating identical strings:

```moonbit
///|
let s1 = builder.create_shared_string("repeated")

///|
let s2 = builder.create_shared_string("repeated") // Same offset as s1
```

#### Force Defaults

Serialize fields even when they equal the default value:

```moonbit
builder.set_force_defaults(true)
builder.add_int32(0, 0, 0)  // Serialized even though value == default
```

#### JSON Conversion

Convert FlatBuffers to JSON:

```moonbit
///|
let json = @flatbuffers.JsonObjectBuilder::new()
  .add_string("name", table.get_string(0, ""))
  .add_int("hp", table.get_int32(1, 0))
  .to_json_string()
// {"name": "Monster", "hp": 100}
```

#### Verifier

Validate buffer integrity before reading:

```moonbit
let buf = @flatbuffers.ByteBuffer::new(data)
if buf.verify() {
  let root = @flatbuffers.Table::get_root(buf)
  // Safe to read
}
```

#### Nested FlatBuffers

Embed complete FlatBuffers inside other FlatBuffers:

```moonbit
// Create nested buffer
let inner_builder = @flatbuffers.Builder::new()
// ... build inner ...

// Embed in outer buffer
let nested = outer_builder.create_nested_flatbuffer(inner_builder.to_fixed_array())
outer_builder.add_offset(slot, nested)

// Read nested
let nested_root = table.get_nested_root(slot)
```

## Supported Schema Features

| Feature | Status |
|---------|--------|
| Tables | Supported |
| Structs | Supported |
| Enums | Supported |
| Unions | Supported |
| Vectors | Supported |
| Strings | Supported |
| Nested FlatBuffers | Supported |
| Default values | Supported |
| File identifiers | Supported |
| Size-prefixed buffers | Supported |

## Running Tests

```bash
moon test
```

## Running Benchmarks

```bash
moon bench
```

## License

Apache-2.0

## Acknowledgments

Based on [Google FlatBuffers](https://github.com/google/flatbuffers).
