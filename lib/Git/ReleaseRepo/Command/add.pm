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

around opt_spec => sub {
    my ( $orig, $self ) = @_;
    return (
        $self->$orig,
        [ 'reference_root=s' => 'Specify a directory containing an existing module to reference' ],
    );
};

augment execute => sub {
    my ( $self, $opt, $args ) = @_;
    my $git = $self->git;
    my $branch = $git->current_branch;
    my $repo = $args->[0];
    my $module = $args->[1] || $self->repo_name_from_url( $repo );
    if ( $opt->{reference_root} ) {
        my $reference = catdir( $opt->{reference_root}, $module );
        $git->run( submodule => add => '--reference' => $reference, '--', $repo, $module );
    }
    else {
        $git->run( submodule => add => '--', $repo, $module );
    }
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


