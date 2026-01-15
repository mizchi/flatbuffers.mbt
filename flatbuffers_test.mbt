///|
test "ByteBuffer read/write uint8" {
  let data : FixedArray[Byte] = [b'\x00', b'\xFF', b'\x7F', b'\x80']
  let buf = @flatbuffers.ByteBuffer::new(data)
  inspect(buf.read_uint8(0), content="0")
  inspect(buf.read_uint8(1), content="255")
  inspect(buf.read_uint8(2), content="127")
  inspect(buf.read_uint8(3), content="128")
}

///|
test "ByteBuffer read/write int8" {
  let data : FixedArray[Byte] = [b'\x00', b'\xFF', b'\x7F', b'\x80']
  let buf = @flatbuffers.ByteBuffer::new(data)
  inspect(buf.read_int8(0), content="0")
  inspect(buf.read_int8(1), content="-1")
  inspect(buf.read_int8(2), content="127")
  inspect(buf.read_int8(3), content="-128")
}

///|
test "ByteBuffer read uint16 little-endian" {
  // 0x0102 in little-endian is [0x02, 0x01]
  let data : FixedArray[Byte] = [b'\x02', b'\x01', b'\xFF', b'\xFF']
  let buf = @flatbuffers.ByteBuffer::new(data)
  inspect(buf.read_uint16(0), content="258")
  inspect(buf.read_uint16(2), content="65535")
}

///|
test "ByteBuffer read uint32 little-endian" {
  // 0x01020304 in little-endian is [0x04, 0x03, 0x02, 0x01]
  let data : FixedArray[Byte] = [b'\x04', b'\x03', b'\x02', b'\x01']
  let buf = @flatbuffers.ByteBuffer::new(data)
  inspect(buf.read_uint32(0), content="16909060")
}

///|
test "ByteBuffer read int32 little-endian" {
  // -1 in little-endian is [0xFF, 0xFF, 0xFF, 0xFF]
  let data : FixedArray[Byte] = [b'\xFF', b'\xFF', b'\xFF', b'\xFF']
  let buf = @flatbuffers.ByteBuffer::new(data)
  inspect(buf.read_int32(0), content="-1")
}

///|
test "Builder create_string and read back" {
  let builder = @flatbuffers.Builder::new()
  let str_offset = builder.create_string("Hello")
  builder.start_object(1)
  builder.add_offset(0, str_offset)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let result = root.get_string(0, "")
  inspect(result, content="Hello")
}

///|
test "Builder int32 field" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 42, 0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_int32(0, 0), content="42")
}

///|
test "Builder multiple fields" {
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Bob")
  builder.start_object(3)
  builder.add_offset(0, name) // name
  builder.add_int32(1, 25, 0) // age
  builder.add_bool(2, true, false) // active
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_string(0, ""), content="Bob")
  inspect(root.get_int32(1, 0), content="25")
  inspect(root.get_bool(2, false), content="true")
}

///|
test "Builder default value optimization" {
  let builder = @flatbuffers.Builder::new()

  // When value equals default, field should not be serialized
  builder.start_object(2)
  builder.add_int32(0, 0, 0) // equals default, not serialized
  builder.add_int32(1, 100, 0) // not default, serialized
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)

  // Field 0 should return default since it wasn't serialized
  inspect(root.get_int32(0, 99), content="99")
  // Field 1 should return actual value
  inspect(root.get_int32(1, 0), content="100")
}

///|
test "Builder float32" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_float32(0, 3.14, 0.0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let val = root.get_float32(0, 0.0)
  // Check approximate equality for float
  assert_true(val > 3.13 && val < 3.15)
}

///|
test "Builder int64" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int64(0, 9223372036854775807L, 0L) // max int64
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_int64(0, 0L), content="9223372036854775807")
}

///|
test "has_field check" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(2)
  builder.add_int32(0, 42, 0) // present
  // Field 1 not added
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.has_field(0), content="true")
  inspect(root.has_field(1), content="false")
}

// =============================================================================
// Vector Tests
// =============================================================================

///|
test "create_int32_vector" {
  let builder = @flatbuffers.Builder::new()
  let vec = builder.create_int32_vector([1, 2, 3, 4, 5])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_vector_length(0), content="5")
  inspect(root.get_vector_int32(0, 0), content="1")
  inspect(root.get_vector_int32(0, 2), content="3")
  inspect(root.get_vector_int32(0, 4), content="5")
}

///|
test "create_string_vector" {
  let builder = @flatbuffers.Builder::new()
  let vec = builder.create_string_vector(["apple", "banana", "cherry"])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_vector_length(0), content="3")
  inspect(root.get_vector_string(0, 0), content="apple")
  inspect(root.get_vector_string(0, 1), content="banana")
  inspect(root.get_vector_string(0, 2), content="cherry")
}

///|
test "create_float64_vector" {
  let builder = @flatbuffers.Builder::new()
  let vec = builder.create_float64_vector([1.1, 2.2, 3.3])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_vector_length(0), content="3")
  let v0 = root.get_vector_float64(0, 0)
  let v2 = root.get_vector_float64(0, 2)
  assert_true(v0 > 1.0 && v0 < 1.2)
  assert_true(v2 > 3.2 && v2 < 3.4)
}

///|
test "create_bool_vector" {
  let builder = @flatbuffers.Builder::new()
  let vec = builder.create_bool_vector([true, false, true, true])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_vector_length(0), content="4")
  inspect(root.get_vector_byte(0, 0) != b'\x00', content="true")
  inspect(root.get_vector_byte(0, 1) != b'\x00', content="false")
  inspect(root.get_vector_byte(0, 2) != b'\x00', content="true")
}

///|
test "nested tables in vector" {
  let builder = @flatbuffers.Builder::new()

  // Create child tables first
  let name1 = builder.create_string("Child1")
  builder.start_object(2)
  builder.add_offset(0, name1)
  builder.add_int32(1, 10, 0)
  let child1 = builder.end_object()
  let name2 = builder.create_string("Child2")
  builder.start_object(2)
  builder.add_offset(0, name2)
  builder.add_int32(1, 20, 0)
  let child2 = builder.end_object()

  // Create vector of tables
  let vec = builder.create_offset_vector([child1, child2])

  // Create parent table
  builder.start_object(1)
  builder.add_offset(0, vec)
  let parent = builder.end_object()
  builder.finish(parent)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_vector_length(0), content="2")
  let t1 = root.get_vector_table(0, 0)
  assert_true(t1 is Some(_))
  inspect(t1.unwrap().get_string(0, ""), content="Child1")
  inspect(t1.unwrap().get_int32(1, 0), content="10")
  let t2 = root.get_vector_table(0, 1)
  inspect(t2.unwrap().get_string(0, ""), content="Child2")
  inspect(t2.unwrap().get_int32(1, 0), content="20")
}

// =============================================================================
// File Identifier Tests
// =============================================================================

///|
test "file identifier" {
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Test")
  builder.start_object(1)
  builder.add_offset(0, name)
  let table = builder.end_object()
  builder.finish_with_identifier(table, "MONS")
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  inspect(buf.has_identifier("MONS"), content="true")
  inspect(buf.has_identifier("TEST"), content="false")
  inspect(buf.get_identifier(), content="MONS")
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_string(0, ""), content="Test")
}

// =============================================================================
// Size-Prefixed Buffer Tests
// =============================================================================

///|
test "size prefixed buffer" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 42, 0)
  let table = builder.end_object()
  builder.finish_size_prefixed(table)
  let data = builder.to_fixed_array()
  let buf = @flatbuffers.ByteBuffer::new(data)

  // First 4 bytes should be size
  let size = buf.read_uint32(0).reinterpret_as_int()
  inspect(size > 0, content="true")
  let root = @flatbuffers.Table::get_root_size_prefixed(buf)
  inspect(root.get_int32(0, 0), content="42")
}

// =============================================================================
// Monster-like Schema Test (Comprehensive)
// =============================================================================

///|
/// Monster schema test - simulates a real FlatBuffers schema
/// Schema:
///   table Monster {
///     name: string;        // field 0
///     hp: short = 100;     // field 1
///     mana: short = 150;   // field 2
///     inventory: [ubyte];  // field 3
///     color: ubyte = 2;    // field 4 (Blue)
///     weapons: [Weapon];   // field 5 (table vector)
///   }
///   table Weapon {
///     name: string;        // field 0
///     damage: short;       // field 1
///   }
test "monster schema simulation" {
  let builder = @flatbuffers.Builder::new()

  // Create weapons first (must be created before parent)
  let sword_name = builder.create_string("Sword")
  builder.start_object(2)
  builder.add_offset(0, sword_name)
  builder.add_int16(1, 50, 0)
  let sword = builder.end_object()
  let axe_name = builder.create_string("Axe")
  builder.start_object(2)
  builder.add_offset(0, axe_name)
  builder.add_int16(1, 75, 0)
  let axe = builder.end_object()

  // Create weapons vector
  let weapons_vec = builder.create_offset_vector([sword, axe])

  // Create inventory (byte array)
  let inventory = builder.create_byte_vector([
    b'\x01', b'\x02', b'\x03', b'\x04',
  ])

  // Create monster name
  let monster_name = builder.create_string("Orc")

  // Create monster table
  builder.start_object(6)
  builder.add_offset(0, monster_name)
  builder.add_int16(1, 300, 100) // hp, non-default
  builder.add_int16(2, 150, 150) // mana, equals default - not serialized
  builder.add_offset(3, inventory)
  builder.add_uint8(4, 2, 2) // color Blue, equals default - not serialized
  builder.add_offset(5, weapons_vec)
  let monster = builder.end_object()
  builder.finish_with_identifier(monster, "MONS")

  // Read it back
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  inspect(buf.has_identifier("MONS"), content="true")
  let m = @flatbuffers.Table::get_root(buf)
  inspect(m.get_string(0, ""), content="Orc")
  inspect(m.get_int16(1, 100), content="300") // hp
  inspect(m.get_int16(2, 150), content="150") // mana (default)
  inspect(m.get_uint8(4, 2), content="2") // color (default)

  // Check inventory
  inspect(m.get_vector_length(3), content="4")
  inspect(m.get_vector_byte(3, 0), content="b'\\x01'")
  inspect(m.get_vector_byte(3, 3), content="b'\\x04'")

  // Check weapons
  inspect(m.get_vector_length(5), content="2")
  let w0 = m.get_vector_table(5, 0).unwrap()
  inspect(w0.get_string(0, ""), content="Sword")
  inspect(w0.get_int16(1, 0), content="50")
  let w1 = m.get_vector_table(5, 1).unwrap()
  inspect(w1.get_string(0, ""), content="Axe")
  inspect(w1.get_int16(1, 0), content="75")
}

// =============================================================================
// Builder Reset Test
// =============================================================================

///|
test "builder reset and reuse" {
  let builder = @flatbuffers.Builder::new()

  // First use
  builder.start_object(1)
  builder.add_int32(0, 100, 0)
  let t1 = builder.end_object()
  builder.finish(t1)
  let data1 = builder.to_fixed_array()
  let buf1 = @flatbuffers.ByteBuffer::new(data1)
  let root1 = @flatbuffers.Table::get_root(buf1)
  inspect(root1.get_int32(0, 0), content="100")

  // Reset and reuse
  builder.reset()

  // Second use
  builder.start_object(1)
  builder.add_int32(0, 200, 0)
  let t2 = builder.end_object()
  builder.finish(t2)
  let data2 = builder.to_fixed_array()
  let buf2 = @flatbuffers.ByteBuffer::new(data2)
  let root2 = @flatbuffers.Table::get_root(buf2)
  inspect(root2.get_int32(0, 0), content="200")
}

// =============================================================================
// Enum Support Tests
// =============================================================================

///|
/// Test enum as ubyte (most common case)
/// Schema: enum Color:ubyte { Red = 0, Green = 1, Blue = 2 }
test "enum as ubyte" {
  let builder = @flatbuffers.Builder::new()

  // Color values (use Int since FlatBuffers API uses Int)
  let color_red = 0
  let color_blue = 2
  builder.start_object(1)
  builder.add_uint8(0, color_blue, 0) // default is Red (0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_uint8(0, color_red), content="2") // Blue
}

///|
/// Test enum as byte with negative values
/// Schema: enum Race:byte { None = -1, Human = 0, Dwarf = 1, Elf = 2 }
test "enum as byte with negative" {
  let builder = @flatbuffers.Builder::new()

  // Race values
  let race_none = -1
  let race_human = 0
  let race_elf = 2
  builder.start_object(1)
  builder.add_int8(0, race_elf, race_human)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_int8(0, race_none), content="2") // Elf
}

///|
/// Test bit_flags enum
/// Schema: enum Color:ubyte (bit_flags) { Red = 1, Green = 2, Blue = 4 }
test "enum bit_flags" {
  let builder = @flatbuffers.Builder::new()

  // Color bit flags
  let color_red = 1
  let color_green = 2
  let color_blue = 4

  // Combine flags: Red | Blue = 5
  let combined = color_red | color_blue
  builder.start_object(1)
  builder.add_uint8(0, combined, 0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let value = root.get_uint8(0, 0)
  inspect(value, content="5") // Red | Blue

  // Check individual flags
  let has_red = (value & color_red) != 0
  let has_green = (value & color_green) != 0
  let has_blue = (value & color_blue) != 0
  inspect(has_red, content="true")
  inspect(has_green, content="false")
  inspect(has_blue, content="true")
}

// =============================================================================
// Union Support Tests
// =============================================================================

///|
/// Test union basic usage
/// Schema:
///   union Equipment { Weapon, Armor }
///   table Weapon { name: string; damage: short; }
///   table Armor { name: string; defense: short; }
///   table Character { equip_type: ubyte; equip: Equipment; }
test "union basic" {
  let builder = @flatbuffers.Builder::new()

  // Union type values
  let equip_none = 0
  let equip_weapon = 1
  let equip_armor = 2

  // Create a Weapon
  let weapon_name = builder.create_string("Excalibur")
  builder.start_object(2)
  builder.add_offset(0, weapon_name)
  builder.add_int16(1, 100, 0) // damage
  let weapon = builder.end_object()

  // Create Character with Weapon equipped
  builder.start_object(2)
  // Union: type_slot=0, value_slot=1
  builder.add_union(0, equip_weapon, 1, weapon)
  let character = builder.end_object()
  builder.finish(character)

  // Read it back
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)

  // Check union type
  let union_type = root.get_union_type(0)
  inspect(union_type, content="1") // Weapon

  // Get union table and read its fields
  let equip_table = root.get_union_table(1)
  guard equip_table is Some(t) else { fail("Expected union table") }
  inspect(t.get_string(0, ""), content="Excalibur")
  inspect(t.get_int16(1, 0), content="100")
  ignore(equip_none)
  ignore(equip_armor)
}

///|
/// Test union with NONE type
test "union none type" {
  let builder = @flatbuffers.Builder::new()
  let equip_none = 0

  // Create Character with no equipment
  builder.start_object(2)
  builder.add_union(0, equip_none, 1, 0) // type=NONE, offset=0 (ignored)
  let character = builder.end_object()
  builder.finish(character)

  // Read it back
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)

  // Check union type is NONE
  let union_type = root.get_union_type(0)
  inspect(union_type, content="0") // NONE

  // Union table should be None
  let equip_table = root.get_union_table(1)
  inspect(equip_table is None, content="true")
}

///|
/// Test union with different types
/// Schema:
///   union Any { Monster, Weapon }
///   table Monster { name: string; hp: short; }
///   table Container { thing_type: ubyte; thing: Any; }
test "union different types" {
  let builder = @flatbuffers.Builder::new()
  let any_monster = 1
  let any_weapon = 2

  // First container: Monster
  let monster_name = builder.create_string("Goblin")
  builder.start_object(2)
  builder.add_offset(0, monster_name)
  builder.add_int16(1, 50, 0) // hp
  let monster = builder.end_object()
  builder.start_object(2)
  builder.add_union(0, any_monster, 1, monster)
  let container1 = builder.end_object()
  builder.finish(container1)
  let buf1 = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root1 = @flatbuffers.Table::get_root(buf1)
  inspect(root1.get_union_type(0), content="1") // Monster
  let t1 = root1.get_union_table(1)
  guard t1 is Some(m) else { fail("Expected monster") }
  inspect(m.get_string(0, ""), content="Goblin")
  inspect(m.get_int16(1, 0), content="50")

  // Second container: Weapon
  builder.reset()
  let weapon_name = builder.create_string("Dagger")
  builder.start_object(2)
  builder.add_offset(0, weapon_name)
  builder.add_int16(1, 15, 0) // damage
  let weapon = builder.end_object()
  builder.start_object(2)
  builder.add_union(0, any_weapon, 1, weapon)
  let container2 = builder.end_object()
  builder.finish(container2)
  let buf2 = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root2 = @flatbuffers.Table::get_root(buf2)
  inspect(root2.get_union_type(0), content="2") // Weapon
  let t2 = root2.get_union_table(1)
  guard t2 is Some(w) else { fail("Expected weapon") }
  inspect(w.get_string(0, ""), content="Dagger")
  inspect(w.get_int16(1, 0), content="15")
}

// =============================================================================
// Verifier Tests
// =============================================================================

///|
test "verifier valid buffer" {
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Test")
  builder.start_object(1)
  builder.add_offset(0, name)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  inspect(buf.verify(), content="true")
}

///|
test "verifier valid buffer with identifier" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 42, 0)
  let table = builder.end_object()
  builder.finish_with_identifier(table, "TEST")
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  inspect(buf.verify_with_identifier("TEST"), content="true")
  inspect(buf.verify_with_identifier("FAIL"), content="false")
}

///|
test "verifier size-prefixed buffer" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 100, 0)
  let table = builder.end_object()
  builder.finish_size_prefixed(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  inspect(buf.verify_size_prefixed(), content="true")
}

///|
test "verifier empty buffer fails" {
  let buf = @flatbuffers.ByteBuffer::new([])
  inspect(buf.verify(), content="false")
}

///|
test "verifier truncated buffer fails" {
  // Buffer too small to contain root offset
  let buf = @flatbuffers.ByteBuffer::new([b'\x00', b'\x00'])
  inspect(buf.verify(), content="false")
}

///|
test "verifier invalid root offset fails" {
  // Root offset pointing outside buffer
  let buf = @flatbuffers.ByteBuffer::new([b'\xFF', b'\xFF', b'\x00', b'\x00'], // root offset = 65535 (invalid)
  )
  inspect(buf.verify(), content="false")
}

///|
test "verifier string validation" {
  let builder = @flatbuffers.Builder::new()
  let str = builder.create_string("Hello World")
  builder.start_object(1)
  builder.add_offset(0, str)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())

  // Verify the buffer is valid (includes string validation)
  inspect(buf.verify(), content="true")

  // Also verify reading the string works correctly
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_string(0, ""), content="Hello World")
}

///|
test "verifier depth limit" {
  let opts = @flatbuffers.VerifierOptions::new(2, 1000000, true)
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 1, 0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let verifier = @flatbuffers.Verifier::new(buf, opts)

  // Should succeed with shallow nesting
  inspect(verifier.verify_buffer(), content="true")
}

///|
test "verifier table count limit" {
  let opts = @flatbuffers.VerifierOptions::new(64, 1, true)
  let builder = @flatbuffers.Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 1, 0)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let verifier = @flatbuffers.Verifier::new(buf, opts)

  // First table should succeed
  inspect(verifier.verify_buffer(), content="true")

  // Second verification should fail (limit reached)
  inspect(verifier.verify_table_start(0), content="false")
}

// =============================================================================
// Nested FlatBuffer Tests
// =============================================================================

///|
test "nested flatbuffer basic" {
  // Create inner FlatBuffer
  let inner_builder = @flatbuffers.Builder::new()
  let inner_name = inner_builder.create_string("Inner")
  inner_builder.start_object(2)
  inner_builder.add_offset(0, inner_name)
  inner_builder.add_int32(1, 42, 0)
  let inner_table = inner_builder.end_object()
  inner_builder.finish(inner_table)

  // Create outer FlatBuffer with nested inner
  let outer_builder = @flatbuffers.Builder::new()
  let nested = outer_builder.create_nested_flatbuffer(
    inner_builder.to_fixed_array(),
  )
  let outer_name = outer_builder.create_string("Outer")
  outer_builder.start_object(2)
  outer_builder.add_offset(0, outer_name)
  outer_builder.add_offset(1, nested) // field 1: nested flatbuffer
  let outer_table = outer_builder.end_object()
  outer_builder.finish(outer_table)

  // Read outer
  let buf = @flatbuffers.ByteBuffer::new(outer_builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  inspect(root.get_string(0, ""), content="Outer")

  // Read nested flatbuffer
  let inner_buf = root.get_nested_flatbuffer(1)
  guard inner_buf is Some(nb) else { fail("Expected nested flatbuffer") }
  let inner_root = @flatbuffers.Table::get_root(nb)
  inspect(inner_root.get_string(0, ""), content="Inner")
  inspect(inner_root.get_int32(1, 0), content="42")
}

///|
test "nested flatbuffer get_nested_root" {
  // Create inner FlatBuffer
  let inner_builder = @flatbuffers.Builder::new()
  inner_builder.start_object(1)
  inner_builder.add_int32(0, 100, 0)
  let inner_table = inner_builder.end_object()
  inner_builder.finish(inner_table)

  // Create outer FlatBuffer
  let outer_builder = @flatbuffers.Builder::new()
  let nested = outer_builder.create_nested_flatbuffer_from_builder(
    inner_builder,
  )
  outer_builder.start_object(1)
  outer_builder.add_offset(0, nested)
  let outer_table = outer_builder.end_object()
  outer_builder.finish(outer_table)

  // Read using get_nested_root
  let buf = @flatbuffers.ByteBuffer::new(outer_builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let inner_root = root.get_nested_root(0)
  guard inner_root is Some(ir) else { fail("Expected nested root") }
  inspect(ir.get_int32(0, 0), content="100")
}

///|
test "nested flatbuffer absent field" {
  let builder = @flatbuffers.Builder::new()
  builder.start_object(2)
  builder.add_int32(0, 1, 0) // Only field 0 is set
  // field 1 (nested) is not set
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)

  // Nested field should return None
  let nested = root.get_nested_flatbuffer(1)
  inspect(nested is None, content="true")
  let nested_root = root.get_nested_root(1)
  inspect(nested_root is None, content="true")
}

///|
test "nested flatbuffer verification" {
  // Create inner FlatBuffer
  let inner_builder = @flatbuffers.Builder::new()
  inner_builder.start_object(1)
  inner_builder.add_int32(0, 123, 0)
  let inner_table = inner_builder.end_object()
  inner_builder.finish(inner_table)

  // Create outer FlatBuffer
  let outer_builder = @flatbuffers.Builder::new()
  let nested = outer_builder.create_nested_flatbuffer(
    inner_builder.to_fixed_array(),
  )
  outer_builder.start_object(1)
  outer_builder.add_offset(0, nested)
  let outer_table = outer_builder.end_object()
  outer_builder.finish(outer_table)
  let buf = @flatbuffers.ByteBuffer::new(outer_builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let verifier = @flatbuffers.Verifier::from_buffer(buf)

  // Verify nested flatbuffer
  inspect(root.verify_nested_flatbuffer(0, verifier), content="true")
}

///|
test "nested flatbuffer multiple levels" {
  // Create level 3 (innermost)
  let level3 = @flatbuffers.Builder::new()
  let l3_name = level3.create_string("Level3")
  level3.start_object(1)
  level3.add_offset(0, l3_name)
  let l3_table = level3.end_object()
  level3.finish(l3_table)

  // Create level 2 containing level 3
  let level2 = @flatbuffers.Builder::new()
  let l2_nested = level2.create_nested_flatbuffer(level3.to_fixed_array())
  let l2_name = level2.create_string("Level2")
  level2.start_object(2)
  level2.add_offset(0, l2_name)
  level2.add_offset(1, l2_nested)
  let l2_table = level2.end_object()
  level2.finish(l2_table)

  // Create level 1 (outermost) containing level 2
  let level1 = @flatbuffers.Builder::new()
  let l1_nested = level1.create_nested_flatbuffer(level2.to_fixed_array())
  let l1_name = level1.create_string("Level1")
  level1.start_object(2)
  level1.add_offset(0, l1_name)
  level1.add_offset(1, l1_nested)
  let l1_table = level1.end_object()
  level1.finish(l1_table)

  // Read all levels
  let buf = @flatbuffers.ByteBuffer::new(level1.to_fixed_array())
  let root1 = @flatbuffers.Table::get_root(buf)
  inspect(root1.get_string(0, ""), content="Level1")
  let root2 = root1.get_nested_root(1)
  guard root2 is Some(r2) else { fail("Expected level 2") }
  inspect(r2.get_string(0, ""), content="Level2")
  let root3 = r2.get_nested_root(1)
  guard root3 is Some(r3) else { fail("Expected level 3") }
  inspect(r3.get_string(0, ""), content="Level3")
}

// =============================================================================
// Shared Strings Tests
// =============================================================================

///|
test "shared strings deduplication" {
  let builder = @flatbuffers.Builder::new()

  // Create the same string twice with sharing
  let s1 = builder.create_shared_string("Hello")
  let s2 = builder.create_shared_string("Hello")

  // Should return the same offset
  inspect(s1 == s2, content="true")
}

///|
test "shared strings different strings" {
  let builder = @flatbuffers.Builder::new()
  let s1 = builder.create_shared_string("Hello")
  let s2 = builder.create_shared_string("World")

  // Different strings should have different offsets
  inspect(s1 != s2, content="true")
}

///|
test "shared strings reduces size" {
  // Without sharing
  let builder1 = @flatbuffers.Builder::new()
  let a1 = builder1.create_string("SharedString")
  let b1 = builder1.create_string("SharedString")
  let c1 = builder1.create_string("SharedString")
  builder1.start_object(3)
  builder1.add_offset(0, a1)
  builder1.add_offset(1, b1)
  builder1.add_offset(2, c1)
  let t1 = builder1.end_object()
  builder1.finish(t1)
  let size_without = builder1.to_fixed_array().length()

  // With sharing
  let builder2 = @flatbuffers.Builder::new()
  let a2 = builder2.create_shared_string("SharedString")
  let b2 = builder2.create_shared_string("SharedString")
  let c2 = builder2.create_shared_string("SharedString")
  builder2.start_object(3)
  builder2.add_offset(0, a2)
  builder2.add_offset(1, b2)
  builder2.add_offset(2, c2)
  let t2 = builder2.end_object()
  builder2.finish(t2)
  let size_with = builder2.to_fixed_array().length()

  // Shared version should be smaller
  inspect(size_with < size_without, content="true")
}

///|
test "shared strings clear cache" {
  let builder = @flatbuffers.Builder::new()
  let s1 = builder.create_shared_string("Test")
  builder.clear_string_cache()
  let s2 = builder.create_shared_string("Test")

  // After clearing cache, should create new string
  inspect(s1 != s2, content="true")
}

// =============================================================================
// Force Defaults Tests
// =============================================================================

///|
test "force defaults off by default" {
  let builder = @flatbuffers.Builder::new()
  inspect(builder.get_force_defaults(), content="false")
}

///|
test "force defaults serializes default values" {
  // Without force defaults - default value not serialized
  let builder1 = @flatbuffers.Builder::new()
  builder1.start_object(1)
  builder1.add_int32(0, 0, 0) // value equals default
  let t1 = builder1.end_object()
  builder1.finish(t1)
  let buf1 = @flatbuffers.ByteBuffer::new(builder1.to_fixed_array())
  let root1 = @flatbuffers.Table::get_root(buf1)
  // Field offset should be 0 (not present in vtable)
  let offset1 = root1.vtable_offset(4) // field 0
  inspect(offset1, content="0")

  // With force defaults - default value is serialized
  let builder2 = @flatbuffers.Builder::new()
  builder2.set_force_defaults(true)
  builder2.start_object(1)
  builder2.add_int32(0, 0, 0) // value equals default
  let t2 = builder2.end_object()
  builder2.finish(t2)
  let buf2 = @flatbuffers.ByteBuffer::new(builder2.to_fixed_array())
  let root2 = @flatbuffers.Table::get_root(buf2)
  // Field offset should be non-zero (present in vtable)
  let offset2 = root2.vtable_offset(4) // field 0
  inspect(offset2 != 0, content="true")
}

///|
test "force defaults with multiple fields" {
  let builder = @flatbuffers.Builder::new()
  builder.set_force_defaults(true)
  builder.start_object(3)
  builder.add_int32(0, 0, 0) // equals default
  builder.add_int32(1, 100, 100) // equals default
  builder.add_bool(2, false, false) // equals default
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)

  // All fields should be present even though they equal defaults
  inspect(root.get_int32(0, -1), content="0")
  inspect(root.get_int32(1, -1), content="100")
  inspect(root.get_bool(2, true), content="false")
}

///|
test "force defaults resets with builder" {
  let builder = @flatbuffers.Builder::new()
  builder.set_force_defaults(true)
  inspect(builder.get_force_defaults(), content="true")
  builder.reset()
  inspect(builder.get_force_defaults(), content="false")
}

// =============================================================================
// JSON Tests
// =============================================================================

///|
test "json value null" {
  let v = @flatbuffers.JsonValue::null()
  inspect(v.to_string(), content="null")
}

///|
test "json value bool" {
  let t = @flatbuffers.JsonValue::bool(true)
  let f = @flatbuffers.JsonValue::bool(false)
  inspect(t.to_string(), content="true")
  inspect(f.to_string(), content="false")
}

///|
test "json value int" {
  let v = @flatbuffers.JsonValue::int(42)
  inspect(v.to_string(), content="42")
}

///|
test "json value string" {
  let v = @flatbuffers.JsonValue::string("hello")
  inspect(v.to_string(), content="\"hello\"")
}

///|
test "json value string escape" {
  let v = @flatbuffers.JsonValue::string("line1\nline2")
  inspect(v.to_string(), content="\"line1\\nline2\"")
}

///|
test "json value array" {
  let arr : Array[@flatbuffers.JsonValue] = [
    @flatbuffers.JsonValue::int(1),
    @flatbuffers.JsonValue::int(2),
    @flatbuffers.JsonValue::int(3),
  ]
  let v = @flatbuffers.JsonValue::array(arr)
  inspect(v.to_string(), content="[1, 2, 3]")
}

///|
test "json object builder" {
  let json = @flatbuffers.JsonObjectBuilder::new()
    .add_string("name", "Alice")
    .add_int("age", 30)
    .add_bool("active", true)
  inspect(
    json.to_json_string(),
    content="{\"name\": \"Alice\", \"age\": 30, \"active\": true}",
  )
}

///|
test "json nested object" {
  let inner = @flatbuffers.JsonObjectBuilder::new()
    .add_string("city", "Tokyo")
    .add_int("zip", 12345)
  let outer = @flatbuffers.JsonObjectBuilder::new()
    .add_string("name", "Bob")
    .add_object("address", inner)
  inspect(
    outer.to_json_string(),
    content="{\"name\": \"Bob\", \"address\": {\"city\": \"Tokyo\", \"zip\": 12345}}",
  )
}

///|
test "json from flatbuffer table" {
  // Create a FlatBuffer
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Monster")
  builder.start_object(3)
  builder.add_offset(0, name)
  builder.add_int32(1, 100, 0) // hp
  builder.add_int32(2, 50, 0) // mana
  let table = builder.end_object()
  builder.finish(table)

  // Read and convert to JSON
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let json = @flatbuffers.JsonObjectBuilder::new()
    .add_string("name", root.get_string(0, ""))
    .add_int("hp", root.get_int32(1, 0))
    .add_int("mana", root.get_int32(2, 0))
  inspect(
    json.to_json_string(),
    content="{\"name\": \"Monster\", \"hp\": 100, \"mana\": 50}",
  )
}

///|
test "json vector to array" {
  let builder = @flatbuffers.Builder::new()
  let vec = builder.create_int32_vector([10, 20, 30, 40])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let table = builder.end_object()
  builder.finish(table)
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let arr_json = root.vector_int32_to_json(0)
  inspect(arr_json.to_string(), content="[10, 20, 30, 40]")
}

// =============================================================================
// Object API Tests
// =============================================================================

///|
test "object api schema creation" {
  let schema = @flatbuffers.TableSchema::new("Person", [
    @flatbuffers.FieldDef::new("name", 0, @flatbuffers.FieldType::string()),
    @flatbuffers.FieldDef::with_default_int(
      "age",
      1,
      @flatbuffers.FieldType::int32(),
      0,
    ),
    @flatbuffers.FieldDef::with_default_bool("active", 2, true),
  ])
  inspect(schema.name, content="Person")
  inspect(schema.field_count(), content="3")
  let name_field = schema.get_field("name")
  guard name_field is Some(f) else { fail("Expected name field") }
  inspect(f.slot, content="0")
  let missing = schema.get_field("missing")
  inspect(missing is None, content="true")
}

///|
test "object api reader" {
  // Create a FlatBuffer using raw Builder
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Alice")
  builder.start_object(3)
  builder.add_offset(0, name)
  builder.add_int32(1, 25, 0)
  builder.add_bool(2, true, false)
  let table = builder.end_object()
  builder.finish(table)

  // Define schema
  let schema = @flatbuffers.TableSchema::new("Person", [
    @flatbuffers.FieldDef::new("name", 0, @flatbuffers.FieldType::string()),
    @flatbuffers.FieldDef::with_default_int(
      "age",
      1,
      @flatbuffers.FieldType::int32(),
      0,
    ),
    @flatbuffers.FieldDef::with_default_bool("active", 2, false),
  ])

  // Read using ObjectReader
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let reader = @flatbuffers.ObjectReader::new(root, schema)
  inspect(reader.get_string("name"), content="Alice")
  inspect(reader.get_int32("age"), content="25")
  inspect(reader.get_bool("active"), content="true")

  // Unknown field returns default
  inspect(reader.get_int32("unknown"), content="0")
}

///|
test "object api builder" {
  let schema = @flatbuffers.TableSchema::new("Monster", [
    @flatbuffers.FieldDef::new("name", 0, @flatbuffers.FieldType::string()),
    @flatbuffers.FieldDef::with_default_int(
      "hp",
      1,
      @flatbuffers.FieldType::int16(),
      100,
    ),
    @flatbuffers.FieldDef::with_default_int(
      "mana",
      2,
      @flatbuffers.FieldType::int16(),
      50,
    ),
  ])

  // Build using ObjectBuilder
  let builder = @flatbuffers.Builder::new()
  let obj_builder = @flatbuffers.ObjectBuilder::new(builder, schema).set_string(
    "name", "Goblin",
  )
  obj_builder.start()
  ignore(obj_builder.add_int16("hp", 30).add_int16("mana", 20))
  obj_builder.finish_buffer()

  // Read it back using ObjectReader
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let reader = @flatbuffers.ObjectReader::new(root, schema)
  inspect(reader.get_string("name"), content="Goblin")
  inspect(reader.get_int16("hp"), content="30")
  inspect(reader.get_int16("mana"), content="20")
}

///|
test "object api to json" {
  // Create a FlatBuffer
  let builder = @flatbuffers.Builder::new()
  let name = builder.create_string("Dragon")
  builder.start_object(2)
  builder.add_offset(0, name)
  builder.add_int32(1, 500, 0)
  let table = builder.end_object()
  builder.finish(table)

  // Define schema
  let schema = @flatbuffers.TableSchema::new("Monster", [
    @flatbuffers.FieldDef::new("name", 0, @flatbuffers.FieldType::string()),
    @flatbuffers.FieldDef::with_default_int(
      "hp",
      1,
      @flatbuffers.FieldType::int32(),
      0,
    ),
  ])

  // Read and convert to JSON
  let buf = @flatbuffers.ByteBuffer::new(builder.to_fixed_array())
  let root = @flatbuffers.Table::get_root(buf)
  let reader = @flatbuffers.ObjectReader::new(root, schema)
  let json = reader.to_json()
  inspect(json.to_string(), content="{\"name\": \"Dragon\", \"hp\": 500}")
}

// =============================================================================
// Code Generator Tests
// =============================================================================

///|
test "codegen parse simple enum" {
  let schema_text =
    #|enum Color:ubyte {
    #|  Red = 0,
    #|  Green,
    #|  Blue = 3,
    #|}
  let schema = @flatbuffers.parse_schema(schema_text)
  inspect(schema.enums.length(), content="1")
  let color_enum = schema.enums[0]
  inspect(color_enum.name, content="Color")
  inspect(color_enum.values.length(), content="3")
  inspect(color_enum.values[0].name, content="Red")
  inspect(color_enum.values[1].name, content="Green")
  inspect(color_enum.values[2].name, content="Blue")
}

///|
test "codegen parse simple table" {
  let schema_text =
    #|table Monster {
    #|  name:string;
    #|  hp:short = 100;
    #|  mana:short = 50;
    #|}
  let schema = @flatbuffers.parse_schema(schema_text)
  inspect(schema.tables.length(), content="1")
  let monster = schema.tables[0]
  inspect(monster.name, content="Monster")
  inspect(monster.fields.length(), content="3")
  inspect(monster.fields[0].name, content="name")
  inspect(monster.fields[1].name, content="hp")
  inspect(monster.fields[2].name, content="mana")
}

///|
test "codegen parse namespace" {
  let schema_text =
    #|namespace MyGame.Example;
    #|
    #|table Player {
    #|  name:string;
    #|}
  let schema = @flatbuffers.parse_schema(schema_text)
  inspect(schema.ns, content="MyGame.Example")
  inspect(schema.tables.length(), content="1")
}

///|
test "codegen parse union" {
  let schema_text =
    #|union Equipment { Weapon, Armor, Shield }
  let schema = @flatbuffers.parse_schema(schema_text)
  inspect(schema.unions.length(), content="1")
  let equip = schema.unions[0]
  inspect(equip.name, content="Equipment")
  inspect(equip.types.length(), content="3")
  inspect(equip.types[0], content="Weapon")
  inspect(equip.types[1], content="Armor")
  inspect(equip.types[2], content="Shield")
}

///|
test "codegen generate enum code" {
  let schema_text =
    #|enum Color:ubyte {
    #|  Red = 0,
    #|  Green,
    #|  Blue,
    #|}
  let schema = @flatbuffers.parse_schema(schema_text)
  let code = @flatbuffers.generate_moonbit(schema)
  // Check that enum is generated
  inspect(code.contains("pub enum Color"), content="true")
  inspect(code.contains("Red"), content="true")
  inspect(code.contains("Green"), content="true")
  inspect(code.contains("Blue"), content="true")
  inspect(code.contains("to_int"), content="true")
  inspect(code.contains("from_int"), content="true")
}

///|
test "codegen generate table code" {
  let schema_text =
    #|table Person {
    #|  name:string;
    #|  age:int = 0;
    #|}
  let schema = @flatbuffers.parse_schema(schema_text)
  let code = @flatbuffers.generate_moonbit(schema)
  // Check reader struct
  inspect(code.contains("pub struct Person"), content="true")
  inspect(code.contains("table : @flatbuffers.Table"), content="true")
  // Check getters
  inspect(code.contains("Person::name"), content="true")
  inspect(code.contains("Person::age"), content="true")
  // Check builder
  inspect(code.contains("pub struct PersonBuilder"), content="true")
  inspect(code.contains("PersonBuilder::new"), content="true")
  inspect(code.contains("PersonBuilder::set_name"), content="true")
  inspect(code.contains("PersonBuilder::add_age"), content="true")
}

// =============================================================================
// FlexBuffers Tests
// =============================================================================

///|
test "FlexBuffer build and read int" {
  let builder = FlexBuilder::new()
  let data = builder.add_int(42L).finish()
  let root = flex_parse(data)
  inspect(root.as_int(), content="42")
}

///|
test "FlexBuffer build and read negative int" {
  let builder = FlexBuilder::new()
  let data = builder.add_int(-100L).finish()
  let root = flex_parse(data)
  inspect(root.as_int(), content="-100")
}

///|
test "FlexBuffer build and read uint" {
  let builder = FlexBuilder::new()
  let data = builder.add_uint(255UL).finish()
  let root = flex_parse(data)
  inspect(root.as_uint64(), content="255")
}

///|
test "FlexBuffer build and read bool true" {
  let builder = FlexBuilder::new()
  let data = builder.add_bool(true).finish()
  let root = flex_parse(data)
  inspect(root.as_bool(), content="true")
}

///|
test "FlexBuffer build and read bool false" {
  let builder = FlexBuilder::new()
  let data = builder.add_bool(false).finish()
  let root = flex_parse(data)
  inspect(root.as_bool(), content="false")
}

///|
test "FlexBuffer build and read null" {
  let builder = FlexBuilder::new()
  let data = builder.add_null().finish()
  let root = flex_parse(data)
  inspect(root.is_null(), content="true")
}

///|
test "FlexBuffer build and read string" {
  let builder = FlexBuilder::new()
  let data = builder.add_string("Hello").finish()
  let root = flex_parse(data)
  inspect(root.as_string(), content="Hello")
}

///|
test "FlexBuffer build and read vector of ints" {
  let builder = FlexBuilder::new()
  let data = builder.add_int(1L).add_int(2L).add_int(3L).end_vector(3).finish()
  let root = flex_parse(data)
  inspect(root.length(), content="3")
  inspect(root.get(0).as_int(), content="1")
  inspect(root.get(1).as_int(), content="2")
  inspect(root.get(2).as_int(), content="3")
}

///|
test "FlexBuffer build empty vector" {
  let builder = FlexBuilder::new()
  let data = builder.end_vector(0).finish()
  let root = flex_parse(data)
  inspect(root.length(), content="0")
}

///|
test "FlexBuffer build mixed vector" {
  let builder = FlexBuilder::new()
  let data = builder
    .add_int(42L)
    .add_string("test")
    .add_bool(true)
    .end_vector(3)
    .finish()
  let root = flex_parse(data)
  inspect(root.length(), content="3")
  inspect(root.get(0).as_int(), content="42")
  inspect(root.get(1).as_string(), content="test")
  inspect(root.get(2).as_bool(), content="true")
}

///|
test "FlexBuffer type detection" {
  let builder = FlexBuilder::new()
  let data = builder.add_int(42L).finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="Int")
}

///|
test "FlexBuffer string type detection" {
  let builder = FlexBuilder::new()
  let data = builder.add_string("test").finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="String")
}

///|
test "FlexBuffer blob" {
  let builder = FlexBuilder::new()
  let blob_data : FixedArray[Byte] = [b'\x01', b'\x02', b'\x03', b'\x04']
  let data = builder.add_blob(blob_data).finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="Blob")
  let result = root.as_blob()
  inspect(result.length(), content="4")
  inspect(result[0].to_int(), content="1")
  inspect(result[3].to_int(), content="4")
}

///|
test "FlexBuffer typed int vector" {
  let builder = FlexBuilder::new()
  let data = builder
    .add_int(10L)
    .add_int(20L)
    .add_int(30L)
    .end_int_vector(3)
    .finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="VectorInt")
  inspect(root.length(), content="3")
  inspect(root.get(0).as_int(), content="10")
  inspect(root.get(1).as_int(), content="20")
  inspect(root.get(2).as_int(), content="30")
}

///|
test "FlexBuffer typed float vector" {
  let builder = FlexBuilder::new()
  let data = builder.add_float(1.5).add_float(2.5).end_float_vector(2).finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="VectorFloat")
  inspect(root.length(), content="2")
  inspect(root.get(0).as_double(), content="1.5")
  inspect(root.get(1).as_double(), content="2.5")
}

///|
test "FlexBuffer simple map" {
  let builder = FlexBuilder::new()
  let data = builder
    .add_key("name")
    .add_string("Alice")
    .add_key("age")
    .add_int(30L)
    .end_map(2)
    .finish()
  let root = flex_parse(data)
  inspect(root.get_type(), content="Map")
  inspect(root.is_map(), content="true")
  inspect(root.length(), content="2")
}

///|
test "FlexBuffer is_vector" {
  let builder = FlexBuilder::new()
  let data = builder.add_int(1L).add_int(2L).end_vector(2).finish()
  let root = flex_parse(data)
  inspect(root.is_vector(), content="true")
  inspect(root.is_map(), content="false")
}

// =============================================================================
// Mutation API Tests
// =============================================================================

///|
test "Mutation API - mutate int32" {
  // Build a simple table with one int32 field
  let builder = Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 42, 0)
  let root_offset = builder.end_object()
  builder.finish(root_offset)

  // Read and verify initial value
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_int32(0, 0), content="42")

  // Mutate the value
  let mutated = root.mutate_int32(0, 100)
  inspect(mutated, content="true")

  // Verify the new value
  inspect(root.get_int32(0, 0), content="100")
}

///|
test "Mutation API - mutate bool" {
  let builder = Builder::new()
  builder.start_object(1)
  builder.add_bool(0, true, false)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_bool(0, false), content="true")
  ignore(root.mutate_bool(0, false))
  inspect(root.get_bool(0, true), content="false")
}

///|
test "Mutation API - mutate float64" {
  let builder = Builder::new()
  builder.start_object(1)
  builder.add_float64(0, 3.14, 0.0)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_float64(0, 0.0), content="3.14")
  ignore(root.mutate_float64(0, 2.718))
  inspect(root.get_float64(0, 0.0), content="2.718")
}

///|
test "Mutation API - mutate non-existent field returns false" {
  let builder = Builder::new()
  builder.start_object(1)
  builder.add_int32(0, 42, 0)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)

  // Try to mutate a field that doesn't exist
  let mutated = root.mutate_int32(5, 100)
  inspect(mutated, content="false")
}

///|
test "Mutation API - mutate vector element" {
  let builder = Builder::new()
  let vec = builder.create_int32_vector([10, 20, 30])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)

  // Verify initial values
  inspect(root.get_vector_int32(0, 0), content="10")
  inspect(root.get_vector_int32(0, 1), content="20")
  inspect(root.get_vector_int32(0, 2), content="30")

  // Mutate middle element
  let mutated = root.mutate_vector_int32(0, 1, 200)
  inspect(mutated, content="true")

  // Verify mutation
  inspect(root.get_vector_int32(0, 0), content="10")
  inspect(root.get_vector_int32(0, 1), content="200")
  inspect(root.get_vector_int32(0, 2), content="30")
}

// =============================================================================
// Optional Scalar Tests
// =============================================================================

///|
test "Optional scalar - present field returns Some" {
  let builder = Builder::new()
  builder.start_object(2)
  builder.add_int32(0, 42, 0)
  builder.add_bool(1, true, false)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)

  // Present fields return Some
  inspect(root.get_int32_optional(0), content="Some(42)")
  inspect(root.get_bool_optional(1), content="Some(true)")
}

///|
test "Optional scalar - absent field returns None" {
  let builder = Builder::new()
  builder.start_object(3)
  builder.add_int32(0, 42, 0)
  // Field 1 is not set
  // Field 2 is not set
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)

  // Present field returns Some
  inspect(root.get_int32_optional(0), content="Some(42)")
  // Absent field returns None
  inspect(root.get_int32_optional(1), content="None")
  inspect(root.get_bool_optional(2), content="None")
}

///|
test "Optional scalar - all types" {
  let builder = Builder::new()
  builder.start_object(6)
  builder.add_int8(0, -10, 0)
  builder.add_uint16(1, 1000, 0)
  builder.add_int64(2, 9999999999L, 0L)
  builder.add_float32(3, 1.5, 0.0)
  builder.add_float64(4, 3.14159, 0.0)
  // Field 5 is not set
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_int8_optional(0), content="Some(-10)")
  inspect(root.get_uint16_optional(1), content="Some(1000)")
  inspect(root.get_int64_optional(2), content="Some(9999999999)")
  inspect(root.get_float32_optional(3), content="Some(1.5)")
  inspect(root.get_float64_optional(4), content="Some(3.14159)")
  inspect(root.get_float64_optional(5), content="None")
}

///|
test "Optional string" {
  let builder = Builder::new()
  let name_offset = builder.create_string("Alice")
  builder.start_object(2)
  builder.add_offset(0, name_offset)
  // Field 1 is not set (no string)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_string_optional(0), content="Some(\"Alice\")")
  inspect(root.get_string_optional(1), content="None")
}

// =============================================================================
// Performance Optimization Tests
// =============================================================================

///|
test "BuilderPool - acquire and release" {
  let pool = BuilderPool::new(pool_size=2)

  // Acquire a builder
  let b1 = pool.acquire()
  b1.start_object(1)
  b1.add_int32(0, 42, 0)
  let off1 = b1.end_object()
  b1.finish(off1)

  // Release it back
  pool.release(b1)

  // Acquire again - should get the same (reset) builder
  let b2 = pool.acquire()
  b2.start_object(1)
  b2.add_int32(0, 100, 0)
  let off2 = b2.end_object()
  b2.finish(off2)
  let buf = ByteBuffer::new(b2.to_fixed_array())
  let root = Table::get_root(buf)
  inspect(root.get_int32(0, 0), content="100")
}

///|
test "CachedTableReader - fast reads" {
  let builder = Builder::new()
  let name = builder.create_string("test")
  builder.start_object(4)
  builder.add_int32(0, 42, 0)
  builder.add_float64(1, 3.14, 0.0)
  builder.add_bool(2, true, false)
  builder.add_offset(3, name)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let table = Table::get_root(buf)

  // Create cached reader for faster repeated access
  let reader = CachedTableReader::new(table)
  inspect(reader.get_int32(0, 0), content="42")
  inspect(reader.get_float64(1, 0.0), content="3.14")
  inspect(reader.get_bool(2, false), content="true")
  inspect(reader.get_string(3, ""), content="test")
}

///|
test "Batch vector read" {
  let builder = Builder::new()
  let vec = builder.create_int32_vector([10, 20, 30, 40, 50])
  builder.start_object(1)
  builder.add_offset(0, vec)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)

  // Read batch of values
  let batch = root.get_vector_int32_batch(0, 1, 3)
  inspect(batch.length(), content="3")
  inspect(batch[0], content="20")
  inspect(batch[1], content="30")
  inspect(batch[2], content="40")
}

///|
test "Get vector bytes slice" {
  let builder = Builder::new()
  let data : FixedArray[Byte] = [b'\x01', b'\x02', b'\x03', b'\x04', b'\x05']
  let vec = builder.create_byte_vector(data)
  builder.start_object(1)
  builder.add_offset(0, vec)
  let root_offset = builder.end_object()
  builder.finish(root_offset)
  let buf = ByteBuffer::new(builder.to_fixed_array())
  let root = Table::get_root(buf)
  let slice = root.get_vector_bytes_slice(0)
  inspect(slice.length(), content="5")
  inspect(slice[0].to_int(), content="1")
  inspect(slice[4].to_int(), content="5")
}
