package JavaScript::QuickJS::Null;
use strict;
use warnings;

our $VERSION = '0.22';

use overload (
    '""'   => sub { '' },
    '0+'   => sub { 0 },
    'bool' => sub { 0 },
    '!'    => sub { 1 },
    '=='   => sub {
        my ($self, $other) = @_;
        return !defined($other) || ref($other) eq __PACKAGE__;
    },
    'eq'   => sub {
        my ($self, $other) = @_;
        return !defined($other) || ref($other) eq __PACKAGE__;
    },
    fallback => 1,
);

sub new {
    my $class = shift;
    bless \(my $o = undef), $class;
}

sub TO_JSON {
    return undef;
}

1;

__END__

=head1 NAME

JavaScript::QuickJS::Null - Null type for JavaScript::QuickJS

=head1 SYNOPSIS

    use JavaScript::QuickJS;

    my $js = JavaScript::QuickJS->new(preserve_types => 1);
    my $result = $js->eval('null');

    if (ref($result) eq 'JavaScript::QuickJS::Null') {
        print "Got JavaScript null (not undefined!)\n";
    }

    # Behaves like undef
    if (!$result) {
        print "Falsy!\n";
    }

=head1 DESCRIPTION

This class represents JavaScript null values when type preservation is enabled.
It allows distinguishing between null and undefined, which both become C<undef>
in Perl when C<preserve_types> is disabled.

=head2 OVERLOADS

=over 4

=item Stringification ("")

Returns empty string

=item Numeric (0+)

Returns 0

=item Boolean (bool)

Returns false

=item Negation (!)

Returns true

=item Equality (==, eq)

Compares as equal to undef or another Null object

=back

=head2 METHODS

=over 4

=item new()

Constructor. Takes no arguments.

=item TO_JSON()

Returns undef (null in JSON)

=back

=head1 SEE ALSO

L<JavaScript::QuickJS>, L<JavaScript::QuickJS::Undefined>

=cut
