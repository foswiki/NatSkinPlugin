###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2012 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::WebLink;
use strict;

use Foswiki::Func ();

sub render {
  my ($session, $params, $topic, $web) = @_;

  # get params
  my $theWeb = $params->{_DEFAULT} || $params->{web} || $web;
  my $theName = $params->{name};
  my $theMarker = $params->{marker} || 'current';

  my $defaultFormat =
    '<a class="natWebLink $marker" href="$url" title="$tooltip">$name</a>';

  my $theFormat = $params->{format} || $defaultFormat;

  my $theTooltip = $params->{tooltip} ||
    Foswiki::Func::getPreferencesValue('SITEMAPUSETO', $theWeb) || '';

  my $homeTopic = Foswiki::Func::getPreferencesValue('HOMETOPIC') 
    || $Foswiki::cfg{HomeTopicName} 
    || 'WebHome';

  my $theUrl = $params->{url} ||
    $session->getScriptUrl(0, 'view', $theWeb, $homeTopic);

  # unset the marker if this is not the current web 
  my $baseWeb = $session->{webName};
  $theMarker = '' unless $theWeb eq $baseWeb;

  # normalize web name
  $theWeb =~ s/\//\./go;

  # get a good default name
  unless ($theName) {
    $theName = $theWeb;
    $theName = $2 if $theName =~ /^(.*)[\.](.*?)$/;
  }

  # escape some disturbing chars
  if ($theTooltip) {
    $theTooltip =~ s/"/&quot;/g;
    $theTooltip =~ s/<nop>/#nop#/g;
    $theTooltip =~ s/<[^>]*>//g;
    $theTooltip =~ s/#nop#/<nop>/g;
  }

  my $title = '';
  if ($theFormat =~ /\$title/) {
    require Foswiki::Plugins::DBCachePlugin;
    $title = Foswiki::Plugins::DBCachePlugin::getTopicTitle($theWeb, $homeTopic);
    if ($title eq $homeTopic) {
      $title = $theWeb;
      $title = $2 if $title =~ /^(.*)[\.](.*?)$/;
    }
  }

  my $result = $theFormat;
  $result =~ s/\$default/$defaultFormat/g;
  $result =~ s/\$marker/$theMarker/g;
  $result =~ s/\$url/$theUrl/g;
  $result =~ s/\$tooltip/$theTooltip/g;
  $result =~ s/\$name/$theName/g;
  $result =~ s/\$title/$title/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$homeTopic/g;

  return $result;
}

1;
