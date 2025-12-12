#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

use JavaScript::QuickJS;

# Test 1: Function persists after VM object destroyed (via refcounting)
subtest 'Function persists after VM object destroyed' => sub {
    my $func;
    {
        my $js = JavaScript::QuickJS->new();
        $func = $js->eval('(function(x) { return x * 2; })');

        # Function works while VM object is alive
        is $func->(21), 42, 'Function works while VM object in scope';
    }
    # VM object destroyed here, BUT context is kept alive by $func

    # Function should STILL work because it holds a reference to the context
    is $func->(21), 42, 'Function still works after VM object destroyed (refcounting)';
};

# Test 2: Function from one VM works independently of other VMs
subtest 'Function independent across different VMs' => sub {
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(function(x) { return x * 2; })');

    # Function works in original VM
    is $func->(21), 42, 'Function works in original VM';

    # Create a new VM
    my $js2 = JavaScript::QuickJS->new();

    # Function from VM1 should still work (it has its own context)
    is $func->(21), 42, 'Function from VM1 still works when VM2 exists';

    # Each VM is independent
    my $func2 = $js2->eval('(function(x) { return x * 3; })');
    is $func2->(21), 63, 'Function from VM2 works independently';
};

# Test 3: Function stored and retrieved continues to work
subtest 'Stored function continues to work' => sub {
    my $storage = {};

    {
        my $js = JavaScript::QuickJS->new();
        my $func = $js->eval('(function(x) { return x * 2; })');

        # Store function
        $storage->{func} = $func;

        # Works while VM object alive
        is $storage->{func}->(21), 42, 'Stored function works while VM object in scope';
    }
    # VM object destroyed, but context kept alive by stored function

    # Retrieve and use - should still work
    my $func = $storage->{func};
    is $func->(21), 42, 'Retrieved function still works after VM object destroyed';
};

# Test 4: Function captured in closure continues to work
subtest 'Function captured in closure persists' => sub {
    my $closure;

    {
        my $js = JavaScript::QuickJS->new();
        my $func = $js->eval('(function(x) { return x * 2; })');

        # Capture function in a Perl closure
        $closure = sub {
            my ($x) = @_;
            return $func->($x);
        };

        # Closure works while VM object alive
        is $closure->(21), 42, 'Closure works while VM object in scope';
    }
    # VM object destroyed, but context kept alive by $func in closure

    # Closure should still work
    is $closure->(21), 42, 'Closure still works after VM object destroyed';
};

# Test 5: Function as object property continues to work
subtest 'Function property in hash persists' => sub {
    my $obj;

    {
        my $js = JavaScript::QuickJS->new();
        my $func = $js->eval('(function(x) { return x * 2; })');

        # Store in hash (like Moose attributes or registry)
        $obj = {
            name => 'doubler',
            handler => $func,
        };

        # Works while VM object alive
        is $obj->{handler}->(21), 42, 'Hash property works while VM object in scope';
    }
    # VM object destroyed, but context kept alive by function in hash

    # Should still work
    is $obj->{handler}->(21), 42, 'Hash property still works after VM object destroyed';
};

# Test 6: Real-world use case - service registry pattern
subtest 'Real-world: service registry pattern' => sub {
    my %registry;

    # Simulate registering a service
    {
        my $js = JavaScript::QuickJS->new();
        my $handler = $js->eval(q{
            (function(config) {
                return 'Handled: ' + config.name;
            })
        });

        $registry{'service.foo'} = {
            name => 'My Service',
            handler => $handler,
        };

        # Test it works immediately
        is $registry{'service.foo'}->{handler}->({name => 'test'}),
            'Handled: test',
            'Service handler works immediately';
    }
    # VM object destroyed (service registration in one scope, call in another)

    # Later, call the service - should still work due to refcounting
    my $service = $registry{'service.foo'};
    is $service->{handler}->({name => 'later'}),
        'Handled: later',
        'Service handler works when called later (context kept alive)';
};

# Test 7: Context cleanup only happens when all refs are gone
subtest 'Context cleanup with multiple function refs' => sub {
    my ($func1, $func2, $func3);

    {
        my $js = JavaScript::QuickJS->new();
        $func1 = $js->eval('(function() { return "one"; })');
        $func2 = $js->eval('(function() { return "two"; })');
        $func3 = $js->eval('(function() { return "three"; })');

        is $func1->(), 'one', 'First function works';
        is $func2->(), 'two', 'Second function works';
        is $func3->(), 'three', 'Third function works';
    }
    # VM object destroyed, but context alive (3 function refs)

    # All functions should still work
    is $func1->(), 'one', 'First function works after VM object destroyed';
    is $func2->(), 'two', 'Second function works after VM object destroyed';
    is $func3->(), 'three', 'Third function works after VM object destroyed';

    # Even if we drop some refs, others should still work
    undef $func1;
    is $func2->(), 'two', 'Second function works after first dropped';
    is $func3->(), 'three', 'Third function works after first dropped';

    undef $func2;
    is $func3->(), 'three', 'Third function works after first two dropped';
    # When $func3 goes out of scope, refcount hits 0 and context is freed
};

done_testing;

__END__

=head1 NAME

t/function_persistence.t - Test JavaScript function persistence via reference counting

=head1 DESCRIPTION

This test suite verifies that JavaScript::QuickJS::Function objects correctly
persist after the main VM object is destroyed, thanks to reference counting.

=head2 Reference Counting Behavior

JavaScript::QuickJS uses reference counting to manage the lifecycle of JS contexts:

1. When a Function object is created, it increments the context's refcount
2. When a Function object is destroyed, it decrements the refcount
3. The context is only freed when refcount reaches 0
4. This means functions continue to work even after the VM object goes out of scope

This is the CORRECT behavior because:
- It prevents use-after-free bugs
- Functions stored in registries, closures, or data structures remain valid
- Memory is automatically cleaned up when no references remain

=head2 Patterns Tested

=over 4

=item * Functions persisting after VM object destroyed

=item * Functions stored in data structures (hashes, arrays)

=item * Functions captured in Perl closures

=item * Multiple functions from the same VM

=item * Service registry pattern (store function, call later)

=item * Gradual cleanup as function references are dropped

=back

=head2 Comparison to Other Implementations

B<JavaScript::Duktape> used bytecode serialization for persistence, which allowed:
- Cross-VM transfer of functions
- Cross-fork persistence
- Long-term storage and serialization

B<JavaScript::QuickJS> uses reference counting, which:
- Keeps functions alive as long as they're referenced
- Simpler memory management (no manual serialization needed)
- Functions tied to their original context
- For cross-VM transfer, use C<to_bytecode()> and C<from_bytecode()>

=head2 Best Practices

For long-term storage or cross-VM transfer, use bytecode serialization:

    # Serialize a function
    my $func = $js->eval('(x) => x * 2');
    my $bytecode = $func->to_bytecode();

    # Later, in a new VM:
    my $new_js = JavaScript::QuickJS->new();
    my $restored = $new_js->from_bytecode($bytecode);

=cut
