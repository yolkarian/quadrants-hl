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
  if ((param.kind == ParameterKind::scalar || param.kind == ParameterKind::mesh_relation) && param.rank != 0) {
    throw std::runtime_error(std::string("HashLink ") + what + " scalar/mesh-relation rank must be zero");
  }
  if (param.is_spec_constant() && param.kind != ParameterKind::scalar) {
    throw std::runtime_error(std::string("HashLink ") + what + " Spec<T> constants must be scalar parameters");
  }
}

const TypeTableEntry *find_type(const KernelDescriptor &descriptor, std::uint32_t type_id) {
  for (const auto &entry : descriptor.type_table) {
    if (entry.id == type_id) {
      return &entry;
    }
  }
  return nullptr;
}

bool has_arg_entry(const KernelDescriptor &descriptor, std::size_t parameter_index) {
  for (const auto &entry : descriptor.arg_table) {
    if (entry.parameter_index == parameter_index) {
      return true;
    }
  }
  return false;
}

bool has_resource_entry(const KernelDescriptor &descriptor, std::size_t parameter_index) {
  for (const auto &entry : descriptor.resource_table) {
    if (entry.parameter_index == parameter_index) {
      return true;
    }
  }
  return false;
}

bool has_spec_entry(const KernelDescriptor &descriptor, std::size_t parameter_index) {
  for (const auto &entry : descriptor.spec_table) {
    if (entry.parameter_index == parameter_index) {
      return true;
    }
  }
  return false;
}

TypeTableKind expected_type_kind(const ParameterDescriptor &param) {
  if (param.is_spec_constant()) {
    return TypeTableKind::spec;
  }
  switch (param.kind) {
    case ParameterKind::scalar:
      return TypeTableKind::primitive;
    case ParameterKind::ndarray:
      return TypeTableKind::tensor_resource;
    case ParameterKind::field:
      return TypeTableKind::field_resource;
    case ParameterKind::mesh_relation:
      return TypeTableKind::mesh_relation_resource;
    case ParameterKind::mesh_attribute:
      return TypeTableKind::mesh_attribute_resource;
  }
  throw std::runtime_error("HashLink parameter has an unsupported kind");
}

}  // namespace

void validate_descriptor(const KernelDescriptor &descriptor) {
  require_string_id(descriptor, descriptor.kernel_name_id, "kernel name");
  for (const auto &param : descriptor.parameters) {
    validate_parameter(descriptor, param, "parameter");
  }
  if (descriptor.type_table.empty() && !descriptor.parameters.empty()) {
    throw std::runtime_error("HashLink v3 descriptor TypeTable is empty");
  }
  for (const auto &entry : descriptor.type_table) {
    if (entry.id == 0) {
      throw std::runtime_error("HashLink v3 descriptor TypeTable id must be non-zero");
    }
  }
  for (std::size_t i = 0; i < descriptor.parameters.size(); ++i) {
    const auto &param = descriptor.parameters[i];
    if (!has_arg_entry(descriptor, i)) {
      throw std::runtime_error("HashLink v3 descriptor ArgTable does not match parameter table");
    }
    const bool resource = param.kind == ParameterKind::ndarray || param.kind == ParameterKind::field ||
                          param.kind == ParameterKind::mesh_relation || param.kind == ParameterKind::mesh_attribute;
    if (resource != has_resource_entry(descriptor, i)) {
      throw std::runtime_error("HashLink v3 descriptor ResourceTable does not match parameter table");
    }
    if (param.is_spec_constant() != has_spec_entry(descriptor, i)) {
      throw std::runtime_error("HashLink v3 descriptor SpecTable does not match parameter table");
    }
  }
  for (const auto &entry : descriptor.resource_table) {
    const auto &param = descriptor.parameters.at(entry.parameter_index);
    const TypeTableEntry *type = find_type(descriptor, entry.type_id);
    if (type == nullptr || type->kind != expected_type_kind(param) || type->dtype != param.dtype || type->rank != param.rank) {
      throw std::runtime_error("HashLink v3 descriptor ResourceTable type does not match parameter table");
    }
    require_string_id(descriptor, entry.name_id, "resource name");
  }
  for (const auto &entry : descriptor.spec_table) {
    const auto &param = descriptor.parameters.at(entry.parameter_index);
    const TypeTableEntry *type = find_type(descriptor, entry.type_id);
    if (type == nullptr || type->kind != TypeTableKind::spec || type->dtype != param.dtype || entry.dtype != param.dtype) {
      throw std::runtime_error("HashLink v3 descriptor SpecTable type does not match parameter table");
    }
    require_string_id(descriptor, entry.name_id, "spec name");
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
