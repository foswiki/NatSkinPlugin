# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2022 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::WebLogo;
use strict;
use warnings;
use Foswiki::Func ();
use Foswiki::Plugins::NatSkinPlugin();

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

# returns the weblogo for the header bar.
# this will check for a couple of preferences:
#    * return %NATSKIN_LOGO% if defined
#    * return %WIKILOGOIMG% if defined
#    * return %WEBLOGOIMG% if defined
#    * return %WIKITOOLNAME% if defined
#    * or return 'Foswiki'
#
# the ...IMG% settings are urls to images where the following variables
# are substituted:
#    * $style: the lower case id of the current style
#    * $variation: the lower case id of the current variation
#
# this allows to switch the logo while switching the style and/or variation.
#
# the *IMG cases will return a full <img src /> tag
#
sub render {
  my ($this, $params) = @_;

  my $result = $params->{format};
  $result = '<a href="$url" title="$alt">$logo</a>' unless defined $result;
  my $height = $params->{height} || 60;

  $result =~ s/\$logo/$this->renderLogo($params)/ge;
  $result =~ s/\$src/$this->renderSrc($params)/ge;
  $result =~ s/\$url/$this->renderUrl($params)/ge;
  $result =~ s/\$path/$this->renderPath($params)/ge;
  $result =~ s/\$variation/$this->renderVariation($params)/ge;
  $result =~ s/\$style/$this->renderStyle($params)/ge;
  $result =~ s/\$alt/$this->renderAlt($params)/ge;
  $result =~ s/\$height/$height/g;
  $result =~ s/\$perce?nt/\%/g;
  $result =~ s/\$nop//g;
  $result =~ s/\$n/\n/g;
  $result =~ s/\$dollar/\$/g;

  return $result;

}

sub renderAlt {
  my ($this, $params) = @_;

  unless (defined $this->{_alt}) {
    $this->{_alt} =
       Foswiki::Func::getPreferencesValue('WEBLOGOALT')
    || Foswiki::Func::getPreferencesValue('WIKILOGOALT')
    || Foswiki::Func::getPreferencesValue('WIKITOOLNAME')
    || 'Logo';
  }

  return $this->{_alt};
}

sub renderStyle {
  my ($this, $params) = @_;

  unless (defined $this->{_style}) {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
    $this->{_style} = $themeEngine->{skinState}{style};
  }

  return $this->{_style};
}

sub renderVariation {
  my ($this, $params) = @_;

  unless (defined $this->{_variation}) {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
    my $result = lc $themeEngine->{skinState}{variation};
    $result = '' if $result eq 'off';

    $this->{_variation} = $result;
  }

  return $this->{_variation};
}

sub renderPath {
  my ($this, $params) = @_;

  unless (defined $this->{_path}) {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
    my $themeRecord = $themeEngine->getThemeRecord($themeEngine->{skinState}{'style'});
    $this->{_path} = $themeRecord ? $themeRecord->{baseUrl} : '';
  }

  return $this->{_path};
}

sub renderUrl {
  my ($this, $params) = @_;

  unless (defined $this->{_url}) {
    $this->{_url} =
         Foswiki::Func::getPreferencesValue('NATSKIN_LOGOURL')
      || Foswiki::Func::getPreferencesValue('WEBLOGOURL')
      || Foswiki::Func::getPreferencesValue('WIKILOGOURL')
      || Foswiki::Func::getPreferencesValue('%SCRIPTURLPATH{"view"}%/%USERSWEB%/%HOMETOPIC%');
  }

  return $this->{_url};
}

sub renderSrc {
  my ($this, $params) = @_;

  unless (defined $this->{_src}) {
    my $result = $params->{src};

    unless ($result) {
      my $wikiLogoImage = Foswiki::Func::getPreferencesValue('WIKILOGOIMG');

      $result =
           Foswiki::Func::getPreferencesValue('NATSKIN_LOGO')
        || Foswiki::Func::getPreferencesValue('WEBLOGOIMG')
        || $wikiLogoImage;

      $result =~ s/\%WIKILOGOIMG%/$wikiLogoImage/g;

      # HACK: override ProjectLogos with own version
      my $theme = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine")->getThemeRecord;
      my $logoUrl = $theme->{logoUrl};
      $result = $logoUrl if $logoUrl && $result =~ /ProjectLogos\/foswiki-logo/;
    }

    $result =~ s/^\s+|\s+$//g;
    $this->{_src} = $result;
  }

  return $this->{_src};
}

sub renderLogo {
  my ($this, $params) = @_;

  unless (defined $this->{_logo}) {
    my $src = $this->renderSrc($params);
    my $result;
    if ($src) {
      $result = '<img class="natWebLogo natWebLogoImage" src="$src" alt="$alt" height="$height" />';
    } else {
      $result = '<span class="natWebLogo natWebLogoName">%WIKITOOLNAME%</span>';
    }

    $this->{_logo} = $result;
  }

  return $this->{_logo};
}

1;
