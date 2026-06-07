#include "bindings/hashlink/native/descriptor_internal.h"

#include <stdexcept>
#include <string>

namespace quadrants::hashlink {
namespace {

void require_string_id(const KernelDescriptor &descriptor, std::uint32_t id, const char *what) {
  if (id >= descriptor.strings.size()) {
    throw std::runtime_error(std::string("HashLink kernel descriptor has invalid ") + what + " string id");
  }
}

void validate_parameter(const KernelDescriptor &descriptor, const ParameterDescriptor &param, const char *what) {
  require_string_id(descriptor, param.name_id, what);
  if (param.kind == ParameterKind::scalar && param.rank != 0) {
    throw std::runtime_error(std::string("HashLink ") + what + " scalar rank must be zero");
  }
}

}  // namespace

void validate_descriptor(const KernelDescriptor &descriptor) {
  require_string_id(descriptor, descriptor.kernel_name_id, "kernel name");
  for (const auto &param : descriptor.parameters) {
    validate_parameter(descriptor, param, "parameter");
  }
  for (const auto &local : descriptor.locals) {
    require_string_id(descriptor, local.name_id, "local name");
    if (local.allocate && local.shared_size != 0) {
      throw std::runtime_error("HashLink shared local must not also request scalar allocation");
    }
  }
  for (const auto &span : descriptor.source_spans) {
    require_string_id(descriptor, span.file_name_id, "source span file");
    if (span.end < span.begin) {
      throw std::runtime_error("HashLink source span end precedes begin");
    }
  }
  for (const auto &function : descriptor.functions) {
    require_string_id(descriptor, function.name_id, "function name");
    for (const auto &param : function.parameters) {
      validate_parameter(descriptor, param, "function parameter");
    }
  }
  if (descriptor.has_return != !descriptor.return_dtypes.empty()) {
    throw std::runtime_error("HashLink kernel descriptor return metadata is inconsistent");
  }
}

}  // namespace quadrants::hashlink
