package JavaScript::QuickJS::JSObject;

use strict;
use warnings;
use Scalar::Util qw(blessed);

=encoding utf-8

=head1 NAME

JavaScript::QuickJS::JSObject - JavaScript object in Perl

=head1 SYNOPSIS

    my $obj = $js->eval('({ x: 42, getX() { return this.x; } })');

    # Access properties
    my $val = $obj->get_property('x');  # 42

    # Call methods with automatic 'this' binding
    my $result = $obj->getX();  # 42 - AUTOLOAD calls the method

=head1 DESCRIPTION

This class represents a JavaScript object instance in Perl.

This class is not instantiated directly.

=head1 AUTOLOAD SUPPORT

For convenience, method calls on JSObject instances automatically:

1. Get the property with the method name from the JavaScript object
2. If the property is a function, call it with the object as C<this>
3. Otherwise, return the property value

This allows natural method-style calls:

    my $obj = $js->eval('({ name: "test", getName() { return this.name; } })');
    $obj->getName();  # Returns "test" with proper 'this' binding

=head1 METHODS

=head2 $value = I<OBJ>->get_property( $name )

Gets a property from the JavaScript object by name.

=cut

#----------------------------------------------------------------------

our $AUTOLOAD;

sub AUTOLOAD {
    my ($self, @args) = @_;

    # Extract method name from fully qualified name
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;

    # Don't handle DESTROY
    return if $method eq 'DESTROY';

    # Get the property from the JavaScript object
    my $prop = $self->get_property($method);

    # If it's a Function, call it with $self as 'this'
    if (blessed($prop) && $prop->isa('JavaScript::QuickJS::Function')) {
        return $prop->call($self, @args);
    }

    # Otherwise just return the property value
    return $prop;
}

sub DESTROY { }

1;
