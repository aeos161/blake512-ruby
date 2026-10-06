#include "ruby.h"
#include "ruby/encoding.h"
#include <limits.h>
#include <stdint.h>

#include "blake512_core.inc"

static VALUE aeos_blake512_digest(VALUE self, VALUE input)
{
  long length;
  uint8_t output[64];
  VALUE result;
  (void)self;

  if (!RB_TYPE_P(input, T_STRING)) rb_raise(rb_eTypeError, "expected String");
  length = RSTRING_LEN(input);
  if (length < 0) rb_raise(rb_eArgError, "negative String length");
#if LONG_MAX > UINT64_MAX
  if ((uintmax_t)length > UINT64_MAX) rb_raise(rb_eArgError, "String too long");
#endif

  /* Hold the GVL and make no Ruby call while the input pointer is in use. */
  blake512_hash(output, (const uint8_t *)RSTRING_PTR(input), (uint64_t)length);
  result = rb_str_new((const char *)output, sizeof(output));
  rb_enc_associate(result, rb_ascii8bit_encoding());
  return result;
}

void Init_blake512_native(void)
{
  VALUE aeos = rb_define_module("Aeos");
  VALUE blake512 = rb_define_module_under(aeos, "Blake512");
  rb_define_singleton_method(blake512, "digest", aeos_blake512_digest, 1);
}
