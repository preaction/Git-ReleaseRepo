package Git::ReleaseRepo;
# ABSTRACT: Manage a release repository of Git submodules

use strict;
use warnings;
use App::Cmd::Setup -app;


1;
__END__

=head1 DESCRIPTION

This application manages a Git repository for releases. It also follows the
"Semantic Versioning" specification.

=head1 SUBMODULES

=head1 BRANCHES AND TAGS

Branches are for major and minor releases. Tags are for bugfix releases.

    v1.0 - Branch for the 1.0 release cycle
    v1.0.0 - Tag for the first release in the 1.0 release cycle
    v1.0.1 - Tag for a bugfix release
    v1.1 - Branch for the 1.1 release cycle
    v1.1.0 - Tag for the first release in the 1.1 release cycle

The tip of the release branch will always be the latest code for that release,
even if it is not yet part of a bugfix release.

Branches will only ever be m/^${PREFIX}\d+[.]\d+/.

=head1 SEMANTIC VERSIONING

See also: http://semver.org/

=head2 MAJOR/MINOR VERSIONS

New major and minor versions are created from HEAD. When a new major/minor release
is created, a new branch is created to allow for bugfix versions.

The same branches are created in submodules to allow for bugfix commits.

=head2 BUGFIX VERSIONS

New bugfix versions are created from the release branch.

