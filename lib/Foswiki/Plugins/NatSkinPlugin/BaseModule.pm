# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2025 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::BaseModule;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::BaseModule

base class for all NatSkin modules

=cut

use strict;
use warnings;

=begin TML

---++ new($session, ...) -> $module

constructor for this module

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = {
    session => $session,
    @_
  };

  bless($this, $class);


  return $this;
}

=begin TML

---++ finish()

destructor

=cut

sub finish {
  my $this = shift;

  foreach my $key (keys %$this) {
    undef $this->{$key};
  }
}

=begin TML

---++ render($params, topic, $web) -> $html

render endpoint of this module

=cut

sub render {
  my ($this, $params, $topic, $web) = @_;

  die "not implemented"
}

1;
