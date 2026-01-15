///|
/// FlatBuffers Code Generator CLI
///
/// Usage:
///   moon run cmd/codegen -- <input.fbs> [-o <output.mbt>]
///
/// Examples:
///   moon run cmd/codegen -- schema.fbs
///   moon run cmd/codegen -- schema.fbs -o generated.mbt
///
/// If no output file is specified, outputs to stdout.

///|
fn print_usage() -> Unit {
  println("FlatBuffers MoonBit Code Generator")
  println("")
  println("Usage:")
  println("  moon run cmd/codegen -- <input.fbs> [-o <output.mbt>]")
  println("")
  println("Arguments:")
  println("  <input.fbs>    Input FlatBuffers schema file")
  println("  -o <output>    Output MoonBit file (default: stdout)")
  println("")
  println("Examples:")
  println("  moon run cmd/codegen -- schema.fbs")
  println("  moon run cmd/codegen -- schema.fbs -o generated.mbt")
}

///|
fn main {
  let args = @sys.get_cli_args()

  // Parse arguments
  let mut input_file : String? = None
  let mut output_file : String? = None
  let mut i = 1 // Skip program name
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      print_usage()
      return
    } else if arg == "-o" || arg == "--output" {
      i = i + 1
      if i < args.length() {
        output_file = Some(args[i])
      } else {
        println("Error: -o requires an argument")
        @sys.exit(1)
      }
    } else if arg.has_prefix("-") {
      println("Error: Unknown option: " + arg)
      print_usage()
      @sys.exit(1)
    } else {
      input_file = Some(arg)
    }
    i = i + 1
  }

  // Validate input
  match input_file {
    None => {
      println("Error: No input file specified")
      println("")
      print_usage()
      @sys.exit(1)
    }
    Some(path) => {
      // Check if file exists
      if not(@fs.path_exists(path)) {
        println("Error: File not found: " + path)
        @sys.exit(1)
      }

      // Read schema file
      let schema_text = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => {
          println("Error reading file: " + msg)
          @sys.exit(1)
          // This line is unreachable but needed for type checking
          ""
        }
      }

      // Parse and generate
      let schema = @lib.parse_schema(schema_text)
      let code = @lib.generate_moonbit(schema)

      // Output
      match output_file {
        None =>
          // Output to stdout
          println(code)
        Some(out_path) =>
          // Write to file
          try {
            @fs.write_string_to_file(out_path, code)
            println("Generated: " + out_path)
            println("  Namespace: " + schema.ns)
            println("  Enums: " + schema.enums.length().to_string())
            println("  Tables: " + schema.tables.length().to_string())
            println("  Lines: " + count_lines(code).to_string())
          } catch {
            @fs.IOError(msg) => {
              println("Error writing file: " + msg)
              @sys.exit(1)
            }
          }
      }
    }
  }
}

///|
fn count_lines(s : String) -> Int {
  let mut count = 1
  for c in s {
    if c == '\n' {
      count = count + 1
    }
  }
  count
}
