package main

Error :: union
{
  bool,
  SyntaxError,
  TypeError,
  OpcodeError,
}

SyntaxError :: struct
{
  type: SyntaxErrorType,
  line: int,
  column: int,
  token: Token,
}

SyntaxErrorType :: enum
{
  MISSING_IDENTIFIER,
  MISSING_LITERAL,
  MISSING_COLON,
  UNIDENTIFIED_IDENTIFIER,
}

TypeError :: struct
{
  line: int,
  column: int,
  expected_type: TokenType,
  actual_type: TokenType,
  token: Token,
}

OpcodeError :: struct
{
  line: int,
  column: int,
  token: Token,
}

resolve_error :: proc(error: Error) -> bool
{
  term.color(.RED)

  switch v in error
  {
    case SyntaxError:
    {
      fmt.print("[ERROR]: ")
      if v.type == .MISSING_COLON
      {
        fmt.printf("Missing colon after label on line %i.\n", v.line)
      }
    }
    case TypeError: {}
    case OpcodeError: {}
    case bool: {}
  }

  term.color(.WHITE)

  if error != nil do return true

  return false
}

import "core:fmt"

import "term"
