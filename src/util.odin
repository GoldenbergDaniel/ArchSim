package main

// @String ///////////////////////////////////////////////////////////////////////////////

str_to_lower :: proc(str: string, allocator := context.temp_allocator) -> string
{
  result := make([]byte, len(str), allocator)
  
  for i in 0..<len(str)
  {
    if str[i] >= 65 && str[i] <= 90
    {
      result[i] = str[i] + 32
    }
    else
    {
      result[i] = str[i]
    }
  }

  return cast(string) result
}

str_is_dec :: proc(str: string) -> bool
{
  if len(str) == 0 do return false
  if len(str) > 1 && str[0] == '0' do return false

  for i in 0..<len(str)
  {
    if str[i] < '0' || str[i] > '9' do return false
  }

  return true
}

str_is_hex :: proc(str: string) -> bool
{
  if len(str) < 3    do return false
  if str[:2] != "0x" do return false

  for c in str[2:]
  {
    if (c < '0' || c > '9') && 
       (c < 'a' || c > 'f') && 
       (c < 'A' || c > 'F')
    {
      return false
    }
  }

  return true
}

str_is_bin :: proc(str: string) -> bool
{
  if len(str) < 3    do return false
  if str[:2] != "0b" do return false

  for c in str[2:]
  {
    if c != '0' && c != '1' do return false
  }

  return true
}

str_get_number_base :: proc(str: string) -> int
{
  result: int

  if str_is_bin(str) do result = 2
  if str_is_dec(str) do result = 10
  if str_is_hex(str) do result = 16

  return result
}

str_to_int :: proc(str: string) -> int
{
  result: int

  switch str_get_number_base(str)
  {
    case 2:
    {
      for i: uint = 2; i < len(str); i += 1
      {
        result += int(str[i] - 48) * int(pow_uint(2, len(str)-i-1))
      }
    }
    case 10:
    {
      is_negative: bool
      if str[0] == '-' do is_negative = true

      for i: uint; i < len(str); i += 1
      {
        result += int(str[i] - 48) * int(pow_uint(10, len(str)-i-1))
      }
    }
    case 16:
    {
      @(static)
      hex_table: [128]u8 = {
        '0' = 0,  '1' = 1,  '2' = 2,  '3' = 3,  '4' = 4,  '5' = 5,  '6' = 6,  '7' = 7,
        '8' = 8,  '9' = 9,  'a' = 10, 'b' = 11, 'c' = 12, 'd' = 13, 'e' = 14, 'f' = 15,
        'A' = 10, 'B' = 11, 'C' = 12, 'D' = 13, 'E' = 14, 'F' = 15,
      }

      for i: uint = len(str)-1; i >= 2; i -= 1
      {
        result += int(hex_table[str[i]]) * int(pow_uint(16, len(str)-i-1))
      }
    }
  }

  return result
}

str_strip_crlf :: proc(str: string) -> string
{
  result := str
  str_len := len(str)

  if str_len >= 2 && str[str_len-2] == '\r'
  {
    result = str[:len(str)-2]
  }
  else if str_len >= 1 && str[str_len-1] == '\n'
  {
    result = str[:len(str)-1]
  }

  return result
}

// @Math /////////////////////////////////////////////////////////////////////////////////

pow_uint :: proc(base, exp: uint) -> uint
{
  result: uint = 1
  
  for i: uint; i < exp; i += 1
  {
    result *= base
  }

  return result
}
