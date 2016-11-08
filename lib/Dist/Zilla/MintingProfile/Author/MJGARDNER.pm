use strict;
use warnings;

package Dist::Zilla::MintingProfile::Author::MJGARDNER;

# ABSTRACT: Mint a new dist for MJGARDNER

use Moose;
with 'Dist::Zilla::Role::MintingProfile::ShareDir';

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 SYNOPSIS

  dzil new -P Author::MJGARDNER

=head1 DESCRIPTION

Profile for minting a new dist with L<Dist::Zilla>.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::App::Command::new>
* L<Dist::Zilla::Role::MintingProfile>

=cut
