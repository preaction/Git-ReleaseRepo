package Git::ReleaseRepo::Command::status;

use strict;
use warnings;
use Moose;
extends 'Git::ReleaseRepo::Command';

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my @outdated = $self->outdated;

    print map { sprintf "\%s is out of date\n", $_ } sort @outdated;
};

1;
__END__


