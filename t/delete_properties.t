#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 15;
use JavaScript::QuickJS;

my $js = JavaScript::QuickJS->new();

# Test 1: Delete from Perl-created hash
$js->set_globals(perl_obj => sub { { a => 1, b => 2, c => 3 } });

my $result = $js->eval(q{
    const obj = perl_obj();
    const before = 'b' in obj;
    delete obj.b;
    const after = 'b' in obj;
    [before, after, Object.keys(obj).sort()]
});

is($result->[0], 1, 'Property exists before delete');
is($result->[1], '', 'Property removed after delete');
is_deeply($result->[2], ['a', 'c'], 'Remaining keys correct');

# Test 2: Delete returns correct value
my $delete_result = $js->eval(q{
    const obj2 = perl_obj();
    const success = delete obj2.b;
    [success, 'b' in obj2]
});

is($delete_result->[0], 1, 'delete returns true');
is($delete_result->[1], '', 'Property is gone');

# Test 3: Delete non-existent property
my $missing = $js->eval(q{
    const obj3 = perl_obj();
    const deleteSuccess = delete obj3.nonexistent;
    [deleteSuccess, 'nonexistent' in obj3]
});

is($missing->[0], 1, 'Deleting non-existent property returns true');
is($missing->[1], '', 'Non-existent property not in object');

# Test 4: Delete all properties
$js->eval(q{
    const obj4 = perl_obj();
    delete obj4.a;
    delete obj4.b;
    delete obj4.c;
});

my $empty_keys = $js->eval(q{
    const obj5 = perl_obj();
    delete obj5.a;
    delete obj5.b;
    delete obj5.c;
    Object.keys(obj5)
});

is_deeply($empty_keys, [], 'Can delete all properties');

# Test 5: Multiple deletes
my $multi_delete = $js->eval(q{
    const obj6 = perl_obj();
    delete obj6.a;
    delete obj6.c;
    ['b' in obj6, 'a' in obj6, 'c' in obj6, Object.keys(obj6)]
});

is($multi_delete->[0], 1, 'Non-deleted property remains (b)');
is($multi_delete->[1], '', 'First deleted property gone (a)');
is($multi_delete->[2], '', 'Second deleted property gone (c)');
is_deeply($multi_delete->[3], ['b'], 'Only non-deleted property remains');

# Test 6: Delete with bracket notation
my $bracket_delete = $js->eval(q{
    const obj7 = perl_obj();
    delete obj7['b'];
    'b' in obj7
});

is($bracket_delete, '', 'Delete with bracket notation works');

# Test 7: Delete in function
$js->set_globals(test_func => sub {
    return sub { { x => 10, y => 20, z => 30 } }
});

my $func_delete = $js->eval(q{
    const obj8 = test_func()();
    delete obj8.y;
    ['y' in obj8, Object.keys(obj8).sort()]
});

is($func_delete->[0], '', 'Property deleted from function-returned object');
is_deeply($func_delete->[1], ['x', 'z'], 'Correct keys remain after delete from function-returned object');
