///|
/// Benchmarks for FlatBuffers MoonBit implementation

///|
/// Benchmark: Build operations
test "bench_build" (b : @bench.T) {
  b.bench(name="simple_table", fn() {
    let builder = Builder::new()
    let name = builder.create_string("TestName")
    builder.start_object(3)
    builder.add_offset(0, name)
    builder.add_int32(1, 100, 0)
    builder.add_int16(2, 50, 0)
    let root = builder.end_object()
    builder.finish(root)
    b.keep(builder.to_bytes())
  })
  b.bench(name="string_vector", fn() {
    let builder = Builder::new()
    let s1 = builder.create_string("Item1")
    let s2 = builder.create_string("Item2")
    let s3 = builder.create_string("Item3")
    let vec = builder.create_offset_vector([s1, s2, s3])
    builder.start_object(1)
    builder.add_offset(0, vec)
    let root = builder.end_object()
    builder.finish(root)
    b.keep(builder.to_bytes())
  })
  b.bench(name="byte_vector", fn() {
    let builder = Builder::new()
    let data : FixedArray[Byte] = FixedArray::make(100, b'\x42')
    let vec = builder.create_byte_vector(data)
    builder.start_object(1)
    builder.add_offset(0, vec)
    let root = builder.end_object()
    builder.finish(root)
    b.keep(builder.to_bytes())
  })
  b.bench(name="shared_strings", fn() {
    let builder = Builder::new()
    let s1 = builder.create_shared_string("SharedString")
    let s2 = builder.create_shared_string("SharedString")
    let s3 = builder.create_shared_string("SharedString")
    let s4 = builder.create_shared_string("DifferentString")
    builder.start_object(4)
    builder.add_offset(0, s1)
    builder.add_offset(1, s2)
    builder.add_offset(2, s3)
    builder.add_offset(3, s4)
    let root = builder.end_object()
    builder.finish(root)
    b.keep(builder.to_bytes())
  })
  b.bench(name="nested_table", fn() {
    let builder = Builder::new()
    let inner_name = builder.create_string("InnerName")
    builder.start_object(2)
    builder.add_offset(0, inner_name)
    builder.add_int32(1, 50, 0)
    let inner = builder.end_object()
    let outer_name = builder.create_string("OuterName")
    builder.start_object(2)
    builder.add_offset(0, outer_name)
    builder.add_offset(1, inner)
    let root = builder.end_object()
    builder.finish(root)
    b.keep(builder.to_bytes())
  })
}

///|
fn prepare_simple_table_buffer() -> FixedArray[Byte] {
  let builder = Builder::new()
  let name = builder.create_string("TestName")
  builder.start_object(3)
  builder.add_offset(0, name)
  builder.add_int32(1, 100, 0)
  builder.add_int16(2, 50, 0)
  let root = builder.end_object()
  builder.finish(root)
  builder.to_fixed_array()
}

///|
fn prepare_byte_vector_buffer() -> FixedArray[Byte] {
  let builder = Builder::new()
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x42')
  let vec = builder.create_byte_vector(data)
  builder.start_object(1)
  builder.add_offset(0, vec)
  let root = builder.end_object()
  builder.finish(root)
  builder.to_fixed_array()
}

///|
fn prepare_nested_table_buffer() -> FixedArray[Byte] {
  let builder = Builder::new()
  let inner_name = builder.create_string("InnerName")
  builder.start_object(2)
  builder.add_offset(0, inner_name)
  builder.add_int32(1, 50, 0)
  let inner = builder.end_object()
  let outer_name = builder.create_string("OuterName")
  builder.start_object(2)
  builder.add_offset(0, outer_name)
  builder.add_offset(1, inner)
  let root = builder.end_object()
  builder.finish(root)
  builder.to_fixed_array()
}

///|
/// Benchmark: Read operations
test "bench_read" (b : @bench.T) {
  let simple_bytes = prepare_simple_table_buffer()
  // Read all fields
  b.bench(name="table_all_fields", fn() {
    let buf = ByteBuffer::new(simple_bytes)
    let table = Table::get_root(buf)
    let name = table.get_string(0, "")
    let hp = table.get_int32(1, 0)
    let mana = table.get_int16(2, 0)
    b.keep((name, hp, mana))
  })
  // Partial read: only one int field (FlatBuffers strength)
  b.bench(name="table_one_field", fn() {
    let buf = ByteBuffer::new(simple_bytes)
    let table = Table::get_root(buf)
    let hp = table.get_int32(1, 0)
    b.keep(hp)
  })
  let byte_vec_bytes = prepare_byte_vector_buffer()
  // Read all 100 bytes one by one
  b.bench(name="vec_all_100", fn() {
    let buf = ByteBuffer::new(byte_vec_bytes)
    let table = Table::get_root(buf)
    let len = table.get_vector_length(0)
    let mut sum = 0
    for i = 0; i < len; i = i + 1 {
      sum = sum + table.get_vector_byte(0, i).to_int()
    }
    b.keep(sum)
  })
  // Partial read: only first 10 bytes (FlatBuffers strength)
  b.bench(name="vec_first_10", fn() {
    let buf = ByteBuffer::new(byte_vec_bytes)
    let table = Table::get_root(buf)
    let mut sum = 0
    for i = 0; i < 10; i = i + 1 {
      sum = sum + table.get_vector_byte(0, i).to_int()
    }
    b.keep(sum)
  })
  // Partial read: only first element
  b.bench(name="vec_first_1", fn() {
    let buf = ByteBuffer::new(byte_vec_bytes)
    let table = Table::get_root(buf)
    let first = table.get_vector_byte(0, 0)
    b.keep(first)
  })
  // Bulk read all (optimized)
  b.bench(name="vec_bulk_all", fn() {
    let buf = ByteBuffer::new(byte_vec_bytes)
    let table = Table::get_root(buf)
    let bytes = table.get_vector_bytes_slice(0)
    let mut sum = 0
    for b in bytes {
      sum = sum + b.to_int()
    }
    b.keep(sum)
  })
  let nested_bytes = prepare_nested_table_buffer()
  b.bench(name="nested_table", fn() {
    let buf = ByteBuffer::new(nested_bytes)
    let table = Table::get_root(buf)
    let outer_name = table.get_string(0, "")
    let inner_table = table.get_table(1)
    match inner_table {
      Some(inner) => {
        let inner_name = inner.get_string(0, "")
        let inner_val = inner.get_int32(1, 0)
        b.keep((outer_name, inner_name, inner_val))
      }
      None => b.keep(("", "", 0))
    }
  })
}

///|
/// Benchmark: Verifier
test "bench_verify" (b : @bench.T) {
  let bytes = prepare_simple_table_buffer()
  b.bench(name="verify_buffer", fn() {
    let buf = ByteBuffer::new(bytes)
    b.keep(buf.verify())
  })
}

///|
/// Benchmark: JSON conversion
test "bench_json" (b : @bench.T) {
  let bytes = prepare_simple_table_buffer()
  b.bench(name="json_conversion", fn() {
    let buf = ByteBuffer::new(bytes)
    let table = Table::get_root(buf)
    let json = JsonObjectBuilder::new()
      .add_string("name", table.get_string(0, ""))
      .add_int("hp", table.get_int32(1, 0))
      .add_int("mana", table.get_int16(2, 0))
      .to_json_string()
    b.keep(json)
  })
}

///|
fn get_person_schema() -> TableSchema {
  TableSchema::new("Person", [
    FieldDef::new("name", 0, FieldType::string()),
    FieldDef::with_default_int("age", 1, FieldType::int32(), 0),
    FieldDef::with_default_int("score", 2, FieldType::int16(), 0),
  ])
}

///|
fn prepare_object_api_buffer(schema : TableSchema) -> FixedArray[Byte] {
  let builder = Builder::new()
  let obj = ObjectBuilder::new(builder, schema).set_string("name", "TestPerson")
  obj.start()
  ignore(obj.add_int32("age", 30))
  ignore(obj.add_int16("score", 95))
  obj.finish_buffer()
  builder.to_fixed_array()
}

///|
/// Benchmark: Object API
test "bench_object_api" (b : @bench.T) {
  let schema = get_person_schema()
  b.bench(name="object_build", fn() {
    let builder = Builder::new()
    let obj = ObjectBuilder::new(builder, schema).set_string(
      "name", "TestPerson",
    )
    obj.start()
    ignore(obj.add_int32("age", 30))
    ignore(obj.add_int16("score", 95))
    obj.finish_buffer()
    b.keep(builder.to_bytes())
  })
  let bytes = prepare_object_api_buffer(schema)
  b.bench(name="object_read", fn() {
    let buf = ByteBuffer::new(bytes)
    let table = Table::get_root(buf)
    let reader = ObjectReader::new(table, schema)
    let name = reader.get_string("name")
    let age = reader.get_int32("age")
    let score = reader.get_int16("score")
    b.keep((name, age, score))
  })
}

///|
/// Benchmark: Code generation
test "bench_codegen" (b : @bench.T) {
  let schema_text =
    #|table Monster {
    #|  name:string;
    #|  hp:short = 100;
    #|  mana:short = 50;
    #|}
  b.bench(name="schema_parse", fn() {
    let schema = parse_schema(schema_text)
    b.keep(schema.tables.length())
  })
  let schema = parse_schema(schema_text)
  b.bench(name="code_generate", fn() {
    let code = generate_moonbit(schema)
    b.keep(code.length())
  })
}
