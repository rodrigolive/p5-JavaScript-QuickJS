package JavaScript::QuickJS::Function;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

JavaScript::QuickJS::Function - JavaScript `Function` in Perl

=head1 SYNOPSIS

    my $func = JavaScript::QuickJS->new()->eval("() => 123");

    print $func->();    # prints “123”; note overloading :)

=head1 DESCRIPTION

This class represents a JavaScript
L<Function|https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function>
instance in Perl.

This class is not instantiated directly.

=head1 OVERLOADING

For convenience, instances of this class are callable as Perl code references.
This is equivalent to a C<call()> with $this_sv (see below) set to undef.

See the L</SYNOPSIS> above for an example.

=head1 INVOCATION METHODS

=head2 $ret = I<OBJ>->call( $this_sv, @arguments )

Like JavaScript's method of the same name.

=head2 $ret = I<OBJ>->apply( $this_sv, \@arguments )

Like JavaScript's C<apply()> method. Similar to C<call()> but takes arguments
as an array reference instead of a list. If C<$arguments> is undef or omitted,
calls the function with no arguments.

=head2 $bound_func = I<OBJ>->bind( $this_sv, @partial_args )

Creates a new function with C<$this_sv> bound as the C<this> value.
Any C<@partial_args> are prepended to the arguments when the bound
function is called.

Returns a plain Perl CODE reference (not a JavaScript::QuickJS::Function object).
The returned function will call the original JavaScript function with the
bound C<this> value and partial arguments.

Note: This is a Perl-side implementation. The returned CODE ref can be
called from Perl but cannot be passed back to JavaScript as a function.

=head2 $coderef = I<OBJ>->as_coderef()

Returns a plain Perl CODE reference that calls this JavaScript function.
This is useful when you need to pass the function to code that strictly
checks C<ref($cb) eq 'CODE'>.

The returned CODE ref is independent - calling it will still invoke the
JavaScript function, but it's a separate Perl reference.

=head1 ACCESSOR METHODS

The following methods return their corresponding JS property:

=over

=item * C<length()>

=item * C<name()>

=back

=cut

#----------------------------------------------------------------------

sub _as_coderef;

use overload (
    '&{}' => \&_as_coderef,
    nomethod => \&_give_self,   # xsub
);

sub _as_coderef {
    my ($self) = @_;

    return sub { $self->call(undef, @_) };
}

sub apply {
    my ($self, $this_sv, $arguments) = @_;

    # Handle undef or missing arguments
    if (!defined $arguments) {
        return $self->call($this_sv);
    }

    # Ensure it's an array ref
    if (ref($arguments) ne 'ARRAY') {
        require Carp;
        Carp::croak("apply() expects an array reference for arguments");
    }

    return $self->call($this_sv, @$arguments);
}

sub bind {
    my ($self, $this_sv, @partial_args) = @_;

    # Create a wrapper that binds this and partial arguments
    # Note: This returns a plain CODE ref, not a JavaScript::QuickJS::Function object
    # This is a Perl-side implementation of bind()
    return sub {
        return $self->call($this_sv, @partial_args, @_);
    };
}

sub as_coderef {
    my ($self) = @_;

    # Return a plain CODE ref (not blessed)
    return sub { $self->call(undef, @_) };
}

1;
