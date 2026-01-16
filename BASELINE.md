# FlatBuffers.mbt Performance Baseline

Date: 2026-01-16

## Build Operations
| Name | Mean | Range |
|------|------|-------|
| simple_table | 0.23 µs | 0.22 - 0.25 µs |
| string_vector | 0.33 µs | 0.33 - 0.34 µs |
| byte_vector | 0.31 µs | 0.30 - 0.32 µs |
| shared_strings | 0.50 µs | 0.49 - 0.52 µs |
| nested_table | 0.34 µs | 0.32 - 0.35 µs |

## Read Operations
| Name | Mean | Range |
|------|------|-------|
| simple_table | 0.07 µs | 0.07 - 0.07 µs |
| byte_vector | 0.45 µs | 0.42 - 0.50 µs |
| nested_table | 0.14 µs | 0.13 - 0.14 µs |

## Verify Operations
| Name | Mean | Range |
|------|------|-------|
| verify_buffer | 0.01 µs | 0.01 - 0.01 µs |

## JSON Conversion
| Name | Mean | Range |
|------|------|-------|
| json_conversion | 0.78 µs | 0.77 - 0.80 µs |

## Object API
| Name | Mean | Range |
|------|------|-------|
| object_build | 0.30 µs | 0.29 - 0.31 µs |
| object_read | 0.11 µs | 0.11 - 0.12 µs |

## Code Generation
| Name | Mean | Range |
|------|------|-------|
| schema_parse | 0.55 µs | 0.53 - 0.57 µs |
| code_generate | 7.29 µs | 7.19 - 7.51 µs |

## Improvement Targets (by impact)
1. **code_generate** (7.29 µs) - Highest impact
2. **json_conversion** (0.78 µs)
3. **schema_parse** (0.55 µs)
4. **shared_strings** (0.50 µs)
5. **byte_vector read** (0.45 µs)

---

# Optimization Results (2026-01-16)

## Applied Optimizations

### 1. byte_vector bulk read - `get_vector_bytes_slice()` with blit
- **Before**: 0.45 µs (per-element access)
- **After**: 0.05 µs (bulk with blit)
- **Improvement**: **9x faster**

### 2. JSON serialization - Buffer-based implementation
- **Before**: 0.78 µs
- **After**: 0.60 µs
- **Improvement**: **23% faster**

### 3. code_generate - Buffer optimization (reverted)
- Buffer-based string generation showed no improvement
- Original Array + join implementation retained

## Current Performance (After Optimization)

| Benchmark | Mean |
|-----------|------|
| simple_table (build) | 0.23 µs |
| byte_vector_bulk (read) | 0.05 µs |
| json_conversion | 0.60 µs |
| code_generate | 7.59 µs |

## Key Learnings
- `FixedArray::unsafe_blit` significantly faster than per-element loops
- Buffer-based JSON serialization effective (avoids intermediate arrays)
- Buffer-based code generation adds overhead due to frequent small writes
