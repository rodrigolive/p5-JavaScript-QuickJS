#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 9;
use JavaScript::QuickJS;

# Note: JavaScript::QuickJS runs all eval() in strict mode by default
# (see QuickJS.xs line 1265: eval_flags |= JS_EVAL_FLAG_STRICT)

my $js = JavaScript::QuickJS->new();
$js->set_globals(perl_obj => sub { { prop => 'value' } });

# Test 1: Successful delete works without throwing
my $delete_ok = $js->eval(q{
    const obj = perl_obj();
    delete obj.prop;
    'prop' in obj
});

is($delete_ok, '', 'Delete works on configurable properties');

# Test 2: Delete SHOULD throw if property is non-configurable
eval {
    $js->eval(q{
        const obj2 = perl_obj();
        Object.defineProperty(obj2, 'prop', { configurable: false });
        delete obj2.prop;  // Should throw TypeError in strict mode
    });
};

like($@, qr/TypeError|could not delete/i, 'Throws when deleting non-configurable property');

# Test 3: Property remains after failed delete
my $remains = $js->eval(q{
    const obj3 = perl_obj();
    Object.defineProperty(obj3, 'prop', { configurable: false });
    try {
        delete obj3.prop;
    } catch(e) {
        // Expected to throw
    }
    'prop' in obj3
});

is($remains, 1, 'Non-configurable property remains after failed delete');

# Test 4: Successful delete returns true (via wrapper to catch the return value)
my $delete_success = $js->eval(q{
    const obj4 = perl_obj();
    const result = delete obj4.prop;
    result
});

is($delete_success, 1, 'delete returns true for successful deletion');

# Test 5: Deleting non-existent property succeeds
my $delete_nonexistent = $js->eval(q{
    const obj5 = perl_obj();
    const result5 = delete obj5.nonexistent;
    result5
});

is($delete_nonexistent, 1, 'Deleting non-existent property returns true');

# Test 6: Explicit 'use strict' directive also works
my $explicit_strict = $js->eval(q{
    'use strict';
    const obj6 = perl_obj();
    delete obj6.prop;
    'prop' in obj6
});

is($explicit_strict, '', 'Explicit strict mode delete works');

# Test 7: Multiple deletes in strict mode
my $multi = $js->eval(q{
    const obj7 = perl_obj();
    const result7a = delete obj7.prop;
    const result7b = delete obj7.prop;  // Delete same property again
    [result7a, result7b, 'prop' in obj7]
});

is($multi->[0], 1, 'First delete returns true');
is($multi->[1], 1, 'Second delete of same property also returns true');
is($multi->[2], '', 'Property is gone after deletes');
