#include <cstdint>

namespace quadrants::hashlink {

struct HashLinkCapabilitiesV3 {
  bool field_resource_param{true};
  bool struct_tensor{false};
  bool mesh_kernel_access{false};
  bool quant_kernel_param{false};
  bool stream_parallel{false};
  bool native_sparse{false};
  bool memory_profiler{false};
  std::uint32_t descriptor_schema_version{3};
};

HashLinkCapabilitiesV3 default_hashlink_capabilities_v3() {
  return HashLinkCapabilitiesV3{};
}

}  // namespace quadrants::hashlink
