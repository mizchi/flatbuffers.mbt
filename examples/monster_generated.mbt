///|
/// Auto-generated FlatBuffers code
/// DO NOT EDIT

///|
pub enum Color {
  Red // = 0
  Green // = 1
  Blue // = 2
}

///|
pub fn Color::to_int(self : Color) -> Int {
  match self {
    Red => 0
    Green => 1
    Blue => 2
  }
}

///|
pub fn Color::from_int(value : Int) -> Color? {
  match value {
    0 => Some(Red)
    1 => Some(Green)
    2 => Some(Blue)
    _ => None
  }
}

///|
/// Weapon reader
pub struct Weapon {
  table : @flatbuffers.Table
}

///|
pub fn Weapon::from_buffer(buf : @flatbuffers.ByteBuffer) -> Weapon {
  { table: @flatbuffers.Table::get_root(buf) }
}

///|
pub fn Weapon::name(self : Weapon) -> String {
  self.table.get_string(0, "")
}

///|
pub fn Weapon::damage(self : Weapon) -> Int {
  self.table.get_int16(1, 0)
}

///|
/// Weapon builder
pub struct WeaponBuilder {
  builder : @flatbuffers.Builder
  string_offsets : Map[String, Int]
  vector_offsets : Map[String, Int]
}

///|
pub fn WeaponBuilder::new(builder : @flatbuffers.Builder) -> WeaponBuilder {
  { builder, string_offsets: {}, vector_offsets: {} }
}

///|
pub fn WeaponBuilder::set_name(self : WeaponBuilder, value : String) -> WeaponBuilder {
  let offset = self.builder.create_string(value)
  self.string_offsets.set("name", offset)
  self
}

///|
pub fn WeaponBuilder::start(self : WeaponBuilder) -> Unit {
  self.builder.start_object(2)
}

///|
pub fn WeaponBuilder::add_damage(self : WeaponBuilder, value : Int) -> WeaponBuilder {
  self.builder.add_int16(1, value, 0)
  self
}

///|
pub fn WeaponBuilder::finish_fields(self : WeaponBuilder) -> Unit {
  match self.string_offsets.get("name") {
    Some(offset) => self.builder.add_offset(0, offset)
    None => ()
  }
}

///|
pub fn WeaponBuilder::end(self : WeaponBuilder) -> Int {
  self.finish_fields()
  self.builder.end_object()
}

///|
pub fn WeaponBuilder::finish(self : WeaponBuilder) -> Unit {
  let offset = self.end()
  self.builder.finish(offset)
}

///|
/// Monster reader
pub struct Monster {
  table : @flatbuffers.Table
}

///|
pub fn Monster::from_buffer(buf : @flatbuffers.ByteBuffer) -> Monster {
  { table: @flatbuffers.Table::get_root(buf) }
}

///|
pub fn Monster::pos(self : Monster) -> @flatbuffers.Table? {
  self.table.get_table(0)
}

///|
pub fn Monster::mana(self : Monster) -> Int {
  self.table.get_int16(1, 150)
}

///|
pub fn Monster::hp(self : Monster) -> Int {
  self.table.get_int16(2, 100)
}

///|
pub fn Monster::name(self : Monster) -> String {
  self.table.get_string(3, "")
}

///|
pub fn Monster::friendly(self : Monster) -> Bool {
  self.table.get_bool(4, false)
}

///|
pub fn Monster::inventory_length(self : Monster) -> Int {
  self.table.get_vector_length(5)
}

///|
pub fn Monster::inventory(self : Monster, index : Int) -> Byte {
  self.table.get_vector_byte(5, index)
}

///|
pub fn Monster::color(self : Monster) -> @flatbuffers.Table? {
  self.table.get_table(6)
}

///|
pub fn Monster::weapons_length(self : Monster) -> Int {
  self.table.get_vector_length(7)
}

///|
pub fn Monster::equipped(self : Monster) -> @flatbuffers.Table? {
  self.table.get_table(8)
}

///|
pub fn Monster::path_length(self : Monster) -> Int {
  self.table.get_vector_length(9)
}

///|
/// Monster builder
pub struct MonsterBuilder {
  builder : @flatbuffers.Builder
  string_offsets : Map[String, Int]
  vector_offsets : Map[String, Int]
}

///|
pub fn MonsterBuilder::new(builder : @flatbuffers.Builder) -> MonsterBuilder {
  { builder, string_offsets: {}, vector_offsets: {} }
}

///|
pub fn MonsterBuilder::set_name(self : MonsterBuilder, value : String) -> MonsterBuilder {
  let offset = self.builder.create_string(value)
  self.string_offsets.set("name", offset)
  self
}

///|
pub fn MonsterBuilder::set_inventory_offset(self : MonsterBuilder, offset : Int) -> MonsterBuilder {
  self.vector_offsets.set("inventory", offset)
  self
}

///|
pub fn MonsterBuilder::set_weapons_offset(self : MonsterBuilder, offset : Int) -> MonsterBuilder {
  self.vector_offsets.set("weapons", offset)
  self
}

///|
pub fn MonsterBuilder::set_path_offset(self : MonsterBuilder, offset : Int) -> MonsterBuilder {
  self.vector_offsets.set("path", offset)
  self
}

///|
pub fn MonsterBuilder::start(self : MonsterBuilder) -> Unit {
  self.builder.start_object(10)
}

///|
pub fn MonsterBuilder::add_mana(self : MonsterBuilder, value : Int) -> MonsterBuilder {
  self.builder.add_int16(1, value, 150)
  self
}

///|
pub fn MonsterBuilder::add_hp(self : MonsterBuilder, value : Int) -> MonsterBuilder {
  self.builder.add_int16(2, value, 100)
  self
}

///|
pub fn MonsterBuilder::add_friendly(self : MonsterBuilder, value : Bool) -> MonsterBuilder {
  self.builder.add_bool(4, value, false)
  self
}

///|
pub fn MonsterBuilder::finish_fields(self : MonsterBuilder) -> Unit {
  match self.string_offsets.get("name") {
    Some(offset) => self.builder.add_offset(3, offset)
    None => ()
  }
  match self.vector_offsets.get("inventory") {
    Some(offset) => self.builder.add_offset(5, offset)
    None => ()
  }
  match self.vector_offsets.get("weapons") {
    Some(offset) => self.builder.add_offset(7, offset)
    None => ()
  }
  match self.vector_offsets.get("path") {
    Some(offset) => self.builder.add_offset(9, offset)
    None => ()
  }
}

///|
pub fn MonsterBuilder::end(self : MonsterBuilder) -> Int {
  self.finish_fields()
  self.builder.end_object()
}

///|
pub fn MonsterBuilder::finish(self : MonsterBuilder) -> Unit {
  let offset = self.end()
  self.builder.finish(offset)
}
