#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

use JavaScript::QuickJS;

# Test the &{} overload behavior
subtest '&{} overload with valid function' => sub {
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval('(function(x) { return x * 2; })');

    # Call directly
    is $func->(21), 42, 'Direct call works';

    # Get the coderef from overload
    my $coderef = \&$func;
    is ref($coderef), 'CODE', 'Overload returns CODE ref';
    is $coderef->(21), 42, 'Coderef call works';
};

# Test what happens with undefined or invalid function
subtest '&{} overload with undef' => sub {
    my $func = undef;

    my $error = exception {
        # Try to call undef as a function
        $func->(21);
    };

    like $error, qr/Can't use an undefined value as a subroutine reference|Can't call method/,
        'Undef throws appropriate error';
};

# Test function stored in data structure
subtest 'Function in hash with DIE handler' => sub {
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval('(function(x) { return x * 2; })');

    my $storage = {
        handler => $func,
    };

    # Set up DIE handler (like the failing test)
    local $SIG{__DIE__} = sub {
        my $err = shift;
        die $err;
    };

    # Try to call from storage
    is $storage->{handler}->(21), 42, 'Call from storage with DIE handler works';
};

# Test function as Moose-like default
subtest 'Function as attribute default' => sub {
    my $js = JavaScript::QuickJS->new();
    my $default_func = $js->eval('(function() { return [11, 22]; })');

    # Simulate Moose attribute with default
    my $attr = {
        name => 'value',
        default => $default_func,
    };

    # Later, call the default
    my $value = $attr->{default}->();
    is_deeply $value, [11, 22], 'Default function works';

    # Call it multiple times (like Moose would)
    my $value2 = $attr->{default}->();
    is_deeply $value2, [11, 22], 'Default function works on second call';
};

# Test function wrapped in closure
subtest 'Function wrapped in Perl closure' => sub {
    my $js = JavaScript::QuickJS->new();
    my $js_func = $js->eval('(function(x) { return x * 2; })');

    # Wrap in closure (like _serialize does)
    my $wrapper = sub {
        my @args = @_;
        return $js_func->(@args);
    };

    is $wrapper->(21), 42, 'Wrapped function works';

    # Try with DIE handler
    local $SIG{__DIE__} = sub { die shift };
    is $wrapper->(21), 42, 'Wrapped function works with DIE handler';
};

# Test the exact pattern from ci.pm
subtest 'Moose method pattern from ci.pm' => sub {
    my $js = JavaScript::QuickJS->new();

    # Create a JS method
    my $meth = $js->eval('(function(arg) { return this.attr + " " + arg; })');

    # Wrap it like ci.pm does
    require Scalar::Util;
    my $coderef;
    if (Scalar::Util::blessed($meth) && $meth->isa('JavaScript::QuickJS::Function')) {
        $coderef = sub {
            my ($self, @args) = @_;
            # Simulate _serialize
            my $this_arg = { attr => 'test' };
            return $meth->call($this_arg, @args);
        };
    }

    # Call it
    is $coderef->({attr => 'test'}, 'arg'), 'test arg', 'Wrapped method works';

    # Call with DIE handler
    local $SIG{__DIE__} = sub { die shift };
    is $coderef->({attr => 'test'}, 'arg'), 'test arg', 'Wrapped method works with DIE handler';
};

# Test accessing AUTOLOAD methods on Function objects
# Note: Plain JS objects become hashrefs, but Functions stay as blessed objects
subtest 'AUTOLOAD property access on Function' => sub {
    my $js = JavaScript::QuickJS->new();

    # Create a function with properties (functions can have properties in JS)
    my $func = $js->eval('Object.assign(function() { return 99; }, {
        meta: "test",
        getValue: function() { return 42; }
    })');

    # The function itself should work via &{} overload
    is $func->(), 99, 'Function call via overload works';

    # Access property via AUTOLOAD
    is $func->meta(), 'test', 'Property access via AUTOLOAD works';

    # Call method via AUTOLOAD (with 'this' binding)
    is $func->getValue(), 42, 'Method call via AUTOLOAD works';
};

# Test the error condition: calling a method that doesn't exist
subtest 'AUTOLOAD with non-existent property on Function' => sub {
    my $js = JavaScript::QuickJS->new();

    my $func = $js->eval('(function() { return 123; })');

    # Try to access a property that doesn't exist
    my $result = $func->nonExistent();

    # Should return undef
    ok !defined($result), 'Non-existent property returns undef';
};

done_testing;

__END__

=head1 DESCRIPTION

This test focuses on the &{} overload behavior and AUTOLOAD implementation
to identify the exact cause of the "Can't use an undefined value as a
subroutine reference" error.

The error occurs at Function.pm line 170:
    return sub { $self->call(undef, @_) };

This means $self is somehow undefined when _as_coderef is called.

=cut
