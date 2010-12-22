###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2010 MichaelDaum http://michaeldaumconsulting.com
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
#
###############################################################################

package Foswiki::Plugins::NatSkinPlugin::ContentType;
use strict;

use Foswiki::Func ();

sub render {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $request = Foswiki::Func::getCgiQuery();

  my $contentType = $request->param('contenttype');
  my $skin = Foswiki::Func::getSkin();
  my $raw = $request->param('raw') || '';

  unless ($contentType) {
    if ($skin =~ /\b(rss|atom|xml)/ ) {
      $contentType = 'text/xml';
    } elsif ($raw eq 'text' || $raw eq 'all') {
      $contentType = 'text/plain';
    } else {
      $contentType = 'text/html';
    }
  }

  return $contentType;
}

1;
