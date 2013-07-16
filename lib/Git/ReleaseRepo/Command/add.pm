package Git::ReleaseRepo::Command::add;
# ABSTRACT: Add a new module to the next release

use strict;
use warnings;
use Moose;
use Git::ReleaseRepo -command;
use File::Spec::Functions qw( catdir );

with 'Git::ReleaseRepo::WithVersionPrefix';

override usage_desc => sub {
    my ( $self ) = @_;
    return super() . " <module_name> <module_url>";
};

sub description {
    return 'Add a new module to the next release';
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    if ( scalar @$args > 2 ) {
        return $self->usage_error( "Too many arguments" );
    }
}

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $git = $self->git;
    my $branch = $git->current_branch;
    my $repo = $args->[1];
    my $module = $args->[0];
    $git->run(
        submodule => add => '--', $repo, $module,
    );
    $git->run( commit => ( '.gitmodules', $module ), -m => "Adding $module to release" );
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Git::ReleaseRepo::Command::add - Add a module to the next release

=head1 DESCRIPTION

Add a module to the next release.


