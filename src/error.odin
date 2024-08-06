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
  line: int,
  column: int,
  token: Token,
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
