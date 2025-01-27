# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2023-2025 MichaelDaum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::NatSkinPlugin::Restore;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::Restore

JSON-RPC handler for the restore method

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Meta ();
use Error qw (:try);

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

=begin TML

---++ jsonRpcRestore($request) -> $result

entry point for the restore method

=cut

sub jsonRpcRestore {
  my ($this, $request) = @_;

  my $rev = $request->param("rev");
  my $web = $this->{session}{webName};
  my $topic = $this->{session}{topicName};

  my $error;
  my $note;

  throw Error::Simple($this->{session}->i18n->maketext("No revision parameter")) 
    unless defined $rev;

  throw Error::Simple($this->{session}->i18n->maketext("Topic does not exist")) 
    unless Foswiki::Func::topicExists($web, $topic);

  throw Error::Simple($this->{session}->i18n->maketext("Access denied")) 
    unless Foswiki::Func::checkAccessPermission("CHANGE", $this->{session}{user}, undef, $topic, $web);

  my $meta = Foswiki::Meta->load($this->{session}, $web, $topic, $rev);

  throw Error::Simple($this->{session}->i18n->maketext("Invalid revision [_1]", $rev))
    if  !defined $meta->getLoadedRev() || $meta->getLoadedRev() != $rev;

  my $lease = $meta->getLease();

  if ($lease) {
    throw Error::Simple($this->{session}->i18n->maketext("Topic is locked")) 
      if $lease->{user} ne $this->{session}{user};
    $meta->clearLease();
  }

  $meta->save(forcenewrevision => 1);

  return {
    redirect => Foswiki::Func::getViewUrl($web, $topic)
  };
}

1;
