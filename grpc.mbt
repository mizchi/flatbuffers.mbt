///|
/// gRPC Integration for FlatBuffers
///
/// This module provides gRPC-style service abstractions for FlatBuffers
/// serialization. While MoonBit doesn't have native HTTP/2 support,
/// this provides the interfaces and codec for gRPC integration.

// =============================================================================
// Status Codes (matching gRPC status codes)
// =============================================================================

///|
/// gRPC status codes
pub(all) enum GrpcStatus {
  Ok // 0
  Cancelled // 1
  Unknown // 2
  InvalidArgument // 3
  DeadlineExceeded // 4
  NotFound // 5
  AlreadyExists // 6
  PermissionDenied // 7
  ResourceExhausted // 8
  FailedPrecondition // 9
  Aborted // 10
  OutOfRange // 11
  Unimplemented // 12
  Internal // 13
  Unavailable // 14
  DataLoss // 15
  Unauthenticated // 16
} derive(Show, Eq)

///|
pub fn GrpcStatus::code(self : GrpcStatus) -> Int {
  match self {
    Ok => 0
    Cancelled => 1
    Unknown => 2
    InvalidArgument => 3
    DeadlineExceeded => 4
    NotFound => 5
    AlreadyExists => 6
    PermissionDenied => 7
    ResourceExhausted => 8
    FailedPrecondition => 9
    Aborted => 10
    OutOfRange => 11
    Unimplemented => 12
    Internal => 13
    Unavailable => 14
    DataLoss => 15
    Unauthenticated => 16
  }
}

///|
pub fn GrpcStatus::from_code(code : Int) -> GrpcStatus {
  match code {
    0 => Ok
    1 => Cancelled
    2 => Unknown
    3 => InvalidArgument
    4 => DeadlineExceeded
    5 => NotFound
    6 => AlreadyExists
    7 => PermissionDenied
    8 => ResourceExhausted
    9 => FailedPrecondition
    10 => Aborted
    11 => OutOfRange
    12 => Unimplemented
    13 => Internal
    14 => Unavailable
    15 => DataLoss
    16 => Unauthenticated
    _ => Unknown
  }
}

// =============================================================================
// Metadata (headers/trailers)
// =============================================================================

///|
/// Key-value metadata for gRPC calls
pub struct Metadata {
  entries : Array[(String, String)]
}

///|
pub fn Metadata::new() -> Metadata {
  { entries: [] }
}

///|
pub fn Metadata::add(self : Metadata, key : String, value : String) -> Metadata {
  self.entries.push((key, value))
  self
}

///|
pub fn Metadata::get(self : Metadata, key : String) -> String? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
pub fn Metadata::get_all(self : Metadata, key : String) -> Array[String] {
  let result : Array[String] = []
  for entry in self.entries {
    if entry.0 == key {
      result.push(entry.1)
    }
  }
  result
}

///|
pub fn Metadata::remove(self : Metadata, key : String) -> Metadata {
  let new_entries : Array[(String, String)] = []
  for entry in self.entries {
    if entry.0 != key {
      new_entries.push(entry)
    }
  }
  { entries: new_entries }
}

///|
pub fn Metadata::len(self : Metadata) -> Int {
  self.entries.length()
}

///|
pub fn Metadata::is_empty(self : Metadata) -> Bool {
  self.entries.is_empty()
}

// =============================================================================
// gRPC Error
// =============================================================================

///|
/// gRPC error with status and message
pub struct GrpcError {
  status : GrpcStatus
  message : String
  metadata : Metadata
}

///|
pub fn GrpcError::new(status : GrpcStatus, message : String) -> GrpcError {
  { status, message, metadata: Metadata::new() }
}

///|
pub fn GrpcError::with_metadata(
  status : GrpcStatus,
  message : String,
  metadata : Metadata,
) -> GrpcError {
  { status, message, metadata }
}

///|
pub impl Show for GrpcError with output(self, logger) {
  logger.write_string("GrpcError(")
  logger.write_string(self.status.to_string())
  logger.write_string(", ")
  logger.write_string(self.message)
  logger.write_string(")")
}

// =============================================================================
// Call Options
// =============================================================================

///|
/// Options for a gRPC call
pub struct CallOptions {
  timeout_ms : Int?
  metadata : Metadata
  compression : Bool
}

///|
pub fn CallOptions::new() -> CallOptions {
  { timeout_ms: None, metadata: Metadata::new(), compression: false }
}

///|
pub fn CallOptions::with_timeout(self : CallOptions, ms : Int) -> CallOptions {
  { ..self, timeout_ms: Some(ms) }
}

///|
pub fn CallOptions::with_metadata(
  self : CallOptions,
  metadata : Metadata,
) -> CallOptions {
  { ..self, metadata, }
}

///|
pub fn CallOptions::with_compression(
  self : CallOptions,
  enabled : Bool,
) -> CallOptions {
  { ..self, compression: enabled }
}

// =============================================================================
// FlatBuffers Codec
// =============================================================================

///|
/// Codec for encoding/decoding FlatBuffers messages
pub struct FlatBuffersCodec {
  /// Content type for gRPC
  content_type : String
}

///|
pub fn FlatBuffersCodec::new() -> FlatBuffersCodec {
  { content_type: "application/x-flatbuffers" }
}

///|
/// Encode a FlatBuffers message to bytes
pub fn FlatBuffersCodec::encode(
  self : FlatBuffersCodec,
  builder : Builder,
) -> FixedArray[Byte] {
  let _ = self
  let bytes = builder.to_bytes()
  let result = FixedArray::make(bytes.length(), b'\x00')
  for i = 0; i < bytes.length(); i = i + 1 {
    result[i] = bytes[i]
  }
  result
}

///|
/// Decode bytes to a ByteBuffer for reading
pub fn FlatBuffersCodec::decode(
  self : FlatBuffersCodec,
  data : FixedArray[Byte],
) -> ByteBuffer {
  let _ = self
  ByteBuffer::new(data)
}

///|
/// Get the content type
pub fn FlatBuffersCodec::get_content_type(self : FlatBuffersCodec) -> String {
  self.content_type
}

// =============================================================================
// Message Frame (for wire protocol)
// =============================================================================

///|
/// gRPC message frame (Length-Prefixed Message)
pub struct MessageFrame {
  /// Compression flag (1 byte)
  compressed : Bool
  /// Message length (4 bytes, big-endian)
  length : Int
  /// Message data
  data : FixedArray[Byte]
}

///|
pub fn MessageFrame::new(
  data : FixedArray[Byte],
  compressed : Bool,
) -> MessageFrame {
  { compressed, length: data.length(), data }
}

///|
/// Encode frame to wire format
pub fn MessageFrame::encode(self : MessageFrame) -> FixedArray[Byte] {
  let total_len = 5 + self.data.length()
  let result = FixedArray::make(total_len, b'\x00')
  // Compression flag
  result[0] = if self.compressed { b'\x01' } else { b'\x00' }
  // Length (big-endian)
  result[1] = ((self.length >> 24) & 0xFF).to_byte()
  result[2] = ((self.length >> 16) & 0xFF).to_byte()
  result[3] = ((self.length >> 8) & 0xFF).to_byte()
  result[4] = (self.length & 0xFF).to_byte()
  // Data
  for i = 0; i < self.data.length(); i = i + 1 {
    result[5 + i] = self.data[i]
  }
  result
}

///|
/// Decode frame from wire format
pub fn MessageFrame::decode(data : FixedArray[Byte]) -> MessageFrame? {
  if data.length() < 5 {
    return None
  }
  let compressed = data[0] != b'\x00'
  let length = (data[1].to_int() << 24) |
    (data[2].to_int() << 16) |
    (data[3].to_int() << 8) |
    data[4].to_int()
  if data.length() < 5 + length {
    return None
  }
  let msg_data = FixedArray::make(length, b'\x00')
  for i = 0; i < length; i = i + 1 {
    msg_data[i] = data[5 + i]
  }
  Some({ compressed, length, data: msg_data })
}

// =============================================================================
// Stream Types
// =============================================================================

///|
/// Method type for gRPC
pub(all) enum MethodType {
  Unary // Single request, single response
  ServerStreaming // Single request, stream of responses
  ClientStreaming // Stream of requests, single response
  BidirectionalStreaming // Stream of requests, stream of responses
} derive(Show, Eq)

///|
/// Method descriptor
pub struct MethodDescriptor {
  service_name : String
  method_name : String
  method_type : MethodType
  /// Full method path (e.g., "/package.Service/Method")
  full_path : String
} derive(Show)

///|
pub fn MethodDescriptor::new(
  service_name : String,
  method_name : String,
  method_type : MethodType,
) -> MethodDescriptor {
  let full_path = "/" + service_name + "/" + method_name
  { service_name, method_name, method_type, full_path }
}

// =============================================================================
// Service Descriptor
// =============================================================================

///|
/// Descriptor for a gRPC service
pub struct ServiceDescriptor {
  name : String
  methods : Array[MethodDescriptor]
} derive(Show)

///|
pub fn ServiceDescriptor::new(name : String) -> ServiceDescriptor {
  { name, methods: [] }
}

///|
pub fn ServiceDescriptor::add_method(
  self : ServiceDescriptor,
  desc : MethodDescriptor,
) -> ServiceDescriptor {
  self.methods.push(desc)
  self
}

///|
pub fn ServiceDescriptor::get_method(
  self : ServiceDescriptor,
  name : String,
) -> MethodDescriptor? {
  for m in self.methods {
    if m.method_name == name {
      return Some(m)
    }
  }
  None
}

// =============================================================================
// Server Context
// =============================================================================

///|
/// Context for server-side call handling
pub struct ServerContext {
  /// Incoming metadata from client
  metadata : Metadata
  /// Outgoing headers (sent before response)
  response_headers : Metadata
  /// Outgoing trailers (sent after response)
  response_trailers : Metadata
  /// Deadline (Unix timestamp in ms)
  deadline : Int64?
  /// Peer address
  peer : String
  /// Whether the call has been cancelled
  cancelled : Bool
}

///|
pub fn ServerContext::new() -> ServerContext {
  {
    metadata: Metadata::new(),
    response_headers: Metadata::new(),
    response_trailers: Metadata::new(),
    deadline: None,
    peer: "",
    cancelled: false,
  }
}

///|
pub fn ServerContext::with_metadata(
  self : ServerContext,
  metadata : Metadata,
) -> ServerContext {
  { ..self, metadata, }
}

///|
pub fn ServerContext::with_deadline(
  self : ServerContext,
  deadline : Int64,
) -> ServerContext {
  { ..self, deadline: Some(deadline) }
}

///|
pub fn ServerContext::with_peer(
  self : ServerContext,
  peer : String,
) -> ServerContext {
  { ..self, peer, }
}

///|
pub fn ServerContext::set_header(
  self : ServerContext,
  key : String,
  value : String,
) -> Unit {
  let _ = self.response_headers.add(key, value)

}

///|
pub fn ServerContext::set_trailer(
  self : ServerContext,
  key : String,
  value : String,
) -> Unit {
  let _ = self.response_trailers.add(key, value)

}

///|
pub fn ServerContext::is_cancelled(self : ServerContext) -> Bool {
  self.cancelled
}

// =============================================================================
// Client Context
// =============================================================================

///|
/// Context for client-side call handling
pub struct ClientContext {
  /// Outgoing metadata to server
  metadata : Metadata
  /// Response headers from server
  response_headers : Metadata
  /// Response trailers from server
  response_trailers : Metadata
  /// Call options
  options : CallOptions
}

///|
pub fn ClientContext::new() -> ClientContext {
  {
    metadata: Metadata::new(),
    response_headers: Metadata::new(),
    response_trailers: Metadata::new(),
    options: CallOptions::new(),
  }
}

///|
pub fn ClientContext::with_metadata(
  self : ClientContext,
  metadata : Metadata,
) -> ClientContext {
  { ..self, metadata, }
}

///|
pub fn ClientContext::with_options(
  self : ClientContext,
  options : CallOptions,
) -> ClientContext {
  { ..self, options, }
}

///|
pub fn ClientContext::add_metadata(
  self : ClientContext,
  key : String,
  value : String,
) -> ClientContext {
  let _ = self.metadata.add(key, value)
  self
}

// =============================================================================
// Stream Interfaces
// =============================================================================

///|
/// Readable stream of messages
pub struct ServerStream[T] {
  /// Function to read next message
  read_fn : () -> T?
  /// Whether stream is exhausted
  mut done : Bool
}

///|
pub fn[T] ServerStream::new(read_fn : () -> T?) -> ServerStream[T] {
  { read_fn, done: false }
}

///|
pub fn[T] ServerStream::read(self : ServerStream[T]) -> T? {
  if self.done {
    return None
  }
  match (self.read_fn)() {
    Some(msg) => Some(msg)
    None => {
      self.done = true
      None
    }
  }
}

///|
/// Writable stream of messages
pub struct ClientStream[T] {
  /// Function to write a message
  write_fn : (T) -> Bool
  /// Function to close the stream
  close_fn : () -> Unit
  /// Whether stream is closed
  mut closed : Bool
}

///|
pub fn[T] ClientStream::new(
  write_fn : (T) -> Bool,
  close_fn : () -> Unit,
) -> ClientStream[T] {
  { write_fn, close_fn, closed: false }
}

///|
pub fn[T] ClientStream::write(self : ClientStream[T], msg : T) -> Bool {
  if self.closed {
    return false
  }
  (self.write_fn)(msg)
}

///|
pub fn[T] ClientStream::close(self : ClientStream[T]) -> Unit {
  if not(self.closed) {
    self.closed = true
    (self.close_fn)()
  }
}

// =============================================================================
// Channel (abstract connection)
// =============================================================================

///|
/// Channel state
pub(all) enum ChannelState {
  Idle
  Connecting
  Ready
  TransientFailure
  Shutdown
} derive(Show, Eq)

///|
/// Abstract channel for gRPC communication
pub struct Channel {
  target : String
  mut state : ChannelState
  codec : FlatBuffersCodec
}

///|
pub fn Channel::new(target : String) -> Channel {
  { target, state: Idle, codec: FlatBuffersCodec::new() }
}

///|
pub fn Channel::get_state(self : Channel) -> ChannelState {
  self.state
}

///|
pub fn Channel::get_target(self : Channel) -> String {
  self.target
}

///|
pub fn Channel::connect(self : Channel) -> Unit {
  self.state = Connecting
  // In a real implementation, this would establish HTTP/2 connection
  self.state = Ready
}

///|
pub fn Channel::shutdown(self : Channel) -> Unit {
  self.state = Shutdown
}

// =============================================================================
// Interceptors
// =============================================================================

///|
/// Client interceptor for modifying outgoing calls
pub struct ClientInterceptor {
  /// Called before sending request
  on_request : (ClientContext, FixedArray[Byte]) -> FixedArray[Byte]
  /// Called after receiving response
  on_response : (ClientContext, FixedArray[Byte]) -> FixedArray[Byte]
}

///|
pub fn ClientInterceptor::new(
  on_request : (ClientContext, FixedArray[Byte]) -> FixedArray[Byte],
  on_response : (ClientContext, FixedArray[Byte]) -> FixedArray[Byte],
) -> ClientInterceptor {
  { on_request, on_response }
}

///|
/// Server interceptor for handling incoming calls
pub struct ServerInterceptor {
  /// Called before handling request
  on_request : (ServerContext, FixedArray[Byte]) -> FixedArray[Byte]
  /// Called after generating response
  on_response : (ServerContext, FixedArray[Byte]) -> FixedArray[Byte]
}

///|
pub fn ServerInterceptor::new(
  on_request : (ServerContext, FixedArray[Byte]) -> FixedArray[Byte],
  on_response : (ServerContext, FixedArray[Byte]) -> FixedArray[Byte],
) -> ServerInterceptor {
  { on_request, on_response }
}

// =============================================================================
// Health Check (standard gRPC health checking)
// =============================================================================

///|
/// Health check status
pub(all) enum ServingStatus {
  Unknown
  Serving
  NotServing
  ServiceUnknown
} derive(Show, Eq)

///|
pub fn ServingStatus::to_int(self : ServingStatus) -> Int {
  match self {
    Unknown => 0
    Serving => 1
    NotServing => 2
    ServiceUnknown => 3
  }
}

///|
/// Health check service
pub struct HealthService {
  status_map : Array[(String, ServingStatus)]
}

///|
pub fn HealthService::new() -> HealthService {
  { status_map: [] }
}

///|
pub fn HealthService::set_status(
  self : HealthService,
  service : String,
  status : ServingStatus,
) -> Unit {
  // Update or add
  for i = 0; i < self.status_map.length(); i = i + 1 {
    if self.status_map[i].0 == service {
      self.status_map[i] = (service, status)
      return
    }
  }
  self.status_map.push((service, status))
}

///|
pub fn HealthService::check(
  self : HealthService,
  service : String,
) -> ServingStatus {
  for entry in self.status_map {
    if entry.0 == service {
      return entry.1
    }
  }
  ServiceUnknown
}

///|
pub fn HealthService::clear_status(
  self : HealthService,
  service : String,
) -> Unit {
  let new_map : Array[(String, ServingStatus)] = []
  for entry in self.status_map {
    if entry.0 != service {
      new_map.push(entry)
    }
  }
  // Cannot reassign self.status_map, so clear and repopulate
  while self.status_map.length() > 0 {
    let _ = self.status_map.pop()

  }
  for entry in new_map {
    self.status_map.push(entry)
  }
}

// =============================================================================
// Reflection Service (for service discovery)
// =============================================================================

///|
/// Service for gRPC reflection
pub struct ReflectionService {
  services : Array[ServiceDescriptor]
}

///|
pub fn ReflectionService::new() -> ReflectionService {
  { services: [] }
}

///|
pub fn ReflectionService::register(
  self : ReflectionService,
  service : ServiceDescriptor,
) -> Unit {
  self.services.push(service)
}

///|
pub fn ReflectionService::list_services(
  self : ReflectionService,
) -> Array[String] {
  let result : Array[String] = []
  for service in self.services {
    result.push(service.name)
  }
  result
}

///|
pub fn ReflectionService::get_service(
  self : ReflectionService,
  name : String,
) -> ServiceDescriptor? {
  for service in self.services {
    if service.name == name {
      return Some(service)
    }
  }
  None
}
