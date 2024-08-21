package test

main :: proc()
{
  foo := "string"
  bar := 3

  bru :: #force_inline proc() -> int
  {
    return 2
  }

  bar = bru()

  switch bar
  {
    case 1:
    {
      biz := 0.1
    }
    case 2:
    {
      biz := 0.2
    }
  }
}
