# QuickJS Bytecode Serialization Implementation

## Summary

Successfully implemented QuickJS bytecode serialization/deserialization support for p5-JavaScript-QuickJS, allowing functions to be serialized to binary format and restored in different JavaScript contexts or even different processes.

## Implementation Details

### XS Implementation (QuickJS.xs)

Three new methods were added:

1. **`to_bytecode()` (JavaScript::QuickJS::Function)**
   - Serializes a JavaScript function to QuickJS bytecode format
   - Returns a binary string that can be saved to disk/database
   - Implementation:
     - Gets function source via `Function.prototype.toString()`
     - Recompiles with `JS_EVAL_FLAG_COMPILE_ONLY`
     - Serializes compiled bytecode with `JS_WriteObject(JS_WRITE_OBJ_BYTECODE)`

2. **`from_bytecode($bytecode)` (JavaScript::QuickJS)**
   - Deserializes bytecode and returns an executable function
   - Implementation:
     - Deserializes with `JS_ReadObject(JS_READ_OBJ_BYTECODE)`
     - Evaluates with `JS_EvalFunction()` to make it executable
     - Returns a `JavaScript::QuickJS::Function` object

3. **`compile($code)` (JavaScript::QuickJS)**
   - Compiles JavaScript code without executing it
   - Returns a function that can be serialized
   - Implementation:
     - Compiles with `JS_EVAL_FLAG_COMPILE_ONLY`
     - Evaluates to make it a regular function object

### Perl Module Documentation

#### JavaScript::QuickJS::Function

Added documentation for `to_bytecode()`:
- Usage examples
- File I/O example
- Important notes about version compatibility
- Warnings about closures and external variables

#### JavaScript::QuickJS

Added documentation for:
- `compile()` - Pre-compilation without execution
- `from_bytecode()` - Deserialization and restoration
- Use cases (event handlers, build-time compilation, persistence)
- Important compatibility and security notes

### Test Suite (t/bytecode_serialization.t)

Comprehensive test suite with 35 tests covering:
- Basic serialization/deserialization
- Complex functions (multi-param, strings, objects, arrays)
- Context destruction survival
- Multiple serialization cycles
- Arrow functions and multi-line functions
- Compile method
- Recursive functions
- Math and JSON operations
- Null/undefined handling
- Bytecode size validation
- Context independence
- Error handling (invalid/empty bytecode)
- Try/catch constructs

### Test Results

```
Files=39, Tests=540
Result: PASS
All tests successful
```

The new bytecode serialization test adds 35 tests to the existing 505 tests, all passing.

## Usage Examples

### Basic Serialization

```perl
my $js1 = JavaScript::QuickJS->new();
my $func = $js1->eval('(x) => x * 2');
my $bytecode = $func->to_bytecode();  # Binary string

# Later, in a new context:
my $js2 = JavaScript::QuickJS->new();
my $restored = $js2->from_bytecode($bytecode);
my $result = $restored->(5);  # Returns 10
```

### Persistent Event Handlers

```perl
# Session 1: Register event handler
my $js1 = JavaScript::QuickJS->new();
my $handler = $js1->eval('(data) => { console.log(data); return data * 2; }');

# Save for later
my $bytecode = $handler->to_bytecode();
store_in_database($bytecode);

# Destroy VM
undef $js1;
undef $handler;

# Session 2: Restore and call handler
my $js2 = JavaScript::QuickJS->new();
my $restored = $js2->from_bytecode(load_from_database());
my $result = $restored->(5);  # Works! Returns 10
```

### Pre-compilation

```perl
my $js = JavaScript::QuickJS->new();
my $compiled = $js->compile('(x) => x * 3');

# Compiled but not executed yet
my $bytecode = $compiled->to_bytecode();

# Can be saved and loaded later
```

## Technical Notes

### Function Source Reconstruction

The implementation handles the limitation that `JS_WriteObject` only works with compiled bytecode (from `JS_EVAL_FLAG_COMPILE_ONLY`), not regular evaluated functions. The solution:

1. Get function source with `Function.prototype.toString()`
2. Recompile the source with `JS_EVAL_FLAG_COMPILE_ONLY`
3. Serialize the compiled bytecode

### Function Type Support

- ✅ Arrow functions: `(x) => x * 2`
- ✅ Multi-line arrow functions: `(x) => { return x * 2; }`
- ✅ Anonymous function expressions (via variable): `var f = function(x) { return x * 2; }; f`
- ⚠️  Named function expressions: Limited support (QuickJS `toString()` / re-parse issues)
- ⚠️  Function declarations: Must be wrapped as expressions

### Limitations

1. **Version Compatibility**: Bytecode is specific to QuickJS version
2. **Closures**: Functions with closures over external variables may not serialize correctly
3. **Binary Format**: Bytecode must be handled as byte string, not character string
4. **Context Independence**: Deserialized functions don't share state with original context

## Files Modified

- `QuickJS.xs` - XS implementations
- `lib/JavaScript/QuickJS.pm` - Documentation for `compile()` and `from_bytecode()`
- `lib/JavaScript/QuickJS/Function.pm` - Documentation for `to_bytecode()`
- `t/bytecode_serialization.t` - Comprehensive test suite

All files follow project coding standards with proper error handling, memory management, and whitespace cleanup applied.

## References

- QuickJS source: `quickjs/qjsc.c` - bytecode compilation example
- QuickJS API: `JS_WriteObject()`, `JS_ReadObject()`, `JS_EvalFunction()`
- QuickJS flags: `JS_EVAL_FLAG_COMPILE_ONLY`, `JS_WRITE_OBJ_BYTECODE`, `JS_READ_OBJ_BYTECODE`
