# hack to get sizeof(uv_loop_t)

type uv_loop_t {.importc: "struct uv_loop_s", header: "uv.h".} = object

proc sizeofLoop*(): int =
  return sizeof(uv_loop_t)
