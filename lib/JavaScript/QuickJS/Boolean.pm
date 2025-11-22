package JavaScript::QuickJS::Boolean;
use strict;
use warnings;

our $VERSION = '0.22';

use overload (
    '""'   => sub { $_[0]->{value} ? 'true' : 'false' },
    '0+'   => sub { $_[0]->{value} ? 1 : 0 },
    'bool' => sub { $_[0]->{value} },
    '!'    => sub { !$_[0]->{value} },
    '=='   => sub {
        my ($self, $other, $swap) = @_;
        my $val = $self->{value} ? 1 : 0;
        return $swap ? ($other == $val) : ($val == $other);
    },
    '!='   => sub {
        my ($self, $other, $swap) = @_;
        my $val = $self->{value} ? 1 : 0;
        return $swap ? ($other != $val) : ($val != $other);
    },
    fallback => 1,
);

sub new {
    my ($class, $value) = @_;
    bless { value => !!$value }, $class;
}

sub true  { __PACKAGE__->new(1) }
sub false { __PACKAGE__->new(0) }

sub TO_JSON {
    my $self = shift;
    return $self->{value} ? \1 : \0;
}

1;

__END__

=head1 NAME

JavaScript::QuickJS::Boolean - Boolean type for JavaScript::QuickJS

=head1 SYNOPSIS

    use JavaScript::QuickJS;

    my $js = JavaScript::QuickJS->new(preserve_types => 1);
    my $result = $js->eval('true');

    if (ref($result) eq 'JavaScript::QuickJS::Boolean') {
        print "Got boolean: ", $result->{value} ? "true" : "false", "\n";
    }

    # Behaves like a boolean
    if ($result) {
        print "Truthy!\n";
    }

    # Stringifies correctly
    print "$result\n";  # Prints: true

=head1 DESCRIPTION

This class represents JavaScript boolean values (true/false) when type
preservation is enabled via C<preserve_types =E<gt> 1>. It provides overloaded
operators so it behaves like a Perl boolean in most contexts while maintaining
inspectable type information.

=head2 OVERLOADS

=over 4

=item Stringification ("")

Returns "true" or "false"

=item Numeric (0+)

Returns 1 for true, 0 for false

=item Boolean (bool)

Returns the actual boolean value

=item Negation (!)

Returns the negated boolean value

=item Equality (==, !=)

Compares numeric values

=back

=head2 METHODS

=over 4

=item new($value)

Constructor. Pass a truthy/falsy value.

=item true()

Returns a Boolean object representing true

=item false()

Returns a Boolean object representing false

=item TO_JSON()

Returns scalar ref suitable for JSON encoding (\\1 or \\0)

=back

=head1 SEE ALSO

L<JavaScript::QuickJS>, L<boolean>

=cut
