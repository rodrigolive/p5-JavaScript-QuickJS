# Upgrade Notes for JavaScript::QuickJS 0.22

## Critical Fix: NaN/Infinity JSON Serialization

### Issue
JavaScript `NaN`, `Infinity`, and `-Infinity` values were being converted to Perl's shared `&PL_sv_undef` scalar, which could retain numeric flags. When serialized by JSON::XS, these values would produce invalid JSON tokens like `nan` instead of `null`, causing GraphQL parsers and other JSON consumers to fail.

### Symptoms
- GraphQL queries failing with: `"unexpected token: 'nan'"`
- JSON parsing errors when JavaScript code produces NaN or Infinity values
- Invalid JSON output containing literal `nan`, `inf`, or `-inf` tokens

### The Fix
Changed `QuickJS.xs:243` from:
```c
RETVAL = &PL_sv_undef;
```

To:
```c
RETVAL = newSV(0);
```

This creates a fresh undef SV without numeric flags, ensuring JSON::XS serializes it correctly as `null`.

### Upgrading

**IMPORTANT**: After installing this version, you MUST restart your application server/process to load the newly compiled XS module.

#### From CPAN (when released):
```bash
cpanm JavaScript::QuickJS
# Then restart your application
```

#### From Source:
```bash
cd JavaScript-QuickJS-0.22
perl Makefile.PL
make
make test
make install  # or sudo make install if needed
# Then restart your application
```

### Verification

Test that the fix is working:

```perl
use JavaScript::QuickJS;
use JSON::XS;

my $js = JavaScript::QuickJS->new();
my $json = JSON::XS->new()->canonical();

# Test NaN
my $nan_result = $js->eval('NaN');
my $nan_json = $json->encode({ value => $nan_result });
print "NaN test: $nan_json\n";  # Should print: {"value":null}

# Test Infinity
my $inf_result = $js->eval('Infinity');
my $inf_json = $json->encode({ value => $inf_result });
print "Infinity test: $inf_json\n";  # Should print: {"value":null}

# Test mixed object
my $mixed = $js->eval('({ a: 1, b: NaN, c: "test", d: Infinity })');
my $mixed_json = $json->encode($mixed);
print "Mixed test: $mixed_json\n";
# Should print: {"a":1,"b":null,"c":"test","d":null}
```

If you see `nan`, `inf`, or `-inf` in the JSON output (without quotes), the old version is still loaded. Restart your application.

### Who is Affected?

You are affected if:
- You use JavaScript::QuickJS with JSON::XS (or other JSON serializers)
- Your JavaScript code produces or manipulates NaN or Infinity values
- You're sending JSON data to GraphQL endpoints or other strict JSON parsers
- You migrated from Duktape or other JavaScript engines and started seeing JSON errors

### Background

This is a critical fix for production environments where JavaScript values must be serialized to JSON. The previous behavior produced invalid JSON that could not be parsed by standards-compliant JSON parsers.

The test suite now includes comprehensive tests (`t/nan_infinity_json.t`) to prevent regression of this issue.
