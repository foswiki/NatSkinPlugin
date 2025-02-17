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
#

package Foswiki::Plugins::NatSkinPlugin::WebComponent;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::WebComponent

service class to render the %WEBCOMPONENT macro

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

=begin TML

---++ render($params) -> $html

=cut

sub render {
  my ($this, $params) = @_;

  my $theComponent = $params->{_DEFAULT};
  my $theLinePrefix = $params->{lineprefix};
  my $theWeb = $params->{web};
  my $theMultiple = $params->{multiple};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  my $name = lc $theComponent;

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getModule("ThemeEngine");
  return '' if $themeEngine->{skinState}{$name} && $themeEngine->{skinState}{$name} eq 'off';

  my $text;

  ($text, $theWeb, $theComponent) = $this->getWebComponent($theWeb, $theComponent, $theMultiple);

  return '' unless defined $theWeb && defined $theComponent;

  #SL: As opposed to INCLUDE WEBCOMPONENT should render as if they were in the web they provide links to.
  #    This behavior allows for web component to be consistently rendered in foreign web using the =web= parameter.
  #    It makes sure %WEB% is expanded to the appropriate value.
  #    Although possible, usage of %BASEWEB% in web component topics might have undesired effect when web component is rendered from a foreign web.
  #$text = Foswiki::Func::expandCommonVariables($text, $theComponent, $theWeb);

  # ignore permission warnings here ;)
  #$text =~ s/No permission to read.*//g;
  $text =~ s/[\n\r]+/\n$theLinePrefix/gs if defined $theLinePrefix;

  return $theHeader . $text . $theFooter;
}

=begin TML

---++ getWebComponent($web, $component, $multiple) -> $html

search path

   1. search WebTheComponent in current web
   2. search SiteTheComponent in %USERWEB%
   3. search SiteTheComponent in %SYSTEMWEB%
   4. search WebTheComponent in %SYSTEMWEB% web

(like: TheComponent = SideBar)

=cut

sub getWebComponent {
  my ($this, $web, $component, $multiple) = @_;

  $web ||= $this->{session}{webName};    # Default to baseWeb
  $multiple || 0;
  $component =~ s/^(Web)//;        #compatibility

  ($web, $component) = Foswiki::Func::normalizeWebTopicName($web, $component);

  #print STDERR "called getWebComponent($component)\n";

  # SMELL: why does preview call for components twice ???
  my $seenWebComponent = $this->{seenWebComponent}{$component}; # SMELL
  if ($seenWebComponent && $seenWebComponent > 2 && !$multiple) {
    return ('<span class="foswikiAlert">' . "ERROR: component '$component' already included" . '</span>', $web, $component);
  }
  $this->{seenWebComponent}{$component}++;

  # get component for web
  my $text = '';
  my $meta = '';
  my ($configWeb) = Foswiki::Func::normalizeWebTopicName(undef, $Foswiki::cfg{LocalSitePreferences});
  my $systemWeb = $Foswiki::cfg{SystemWebName};

  my $theWeb = $web;
  my $targetWeb = $web;
  my $theComponent = 'Web' . $component;

  my $userName = Foswiki::Func::getWikiName();

  if ( Foswiki::Func::topicExists($theWeb, $theComponent)
    && Foswiki::Func::checkAccessPermission('VIEW', $userName, undef, $theComponent, $theWeb))
  {
    # current
    ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $configWeb;
    $theComponent = 'Site' . $component;

    if ( Foswiki::Func::topicExists($theWeb, $theComponent)
      && Foswiki::Func::checkAccessPermission('VIEW', $userName, undef, $theComponent, $theWeb))
    {
      # %USERWEB%
      ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $systemWeb;

      if ( Foswiki::Func::topicExists($theWeb, $theComponent)
        && Foswiki::Func::checkAccessPermission('VIEW', $userName, undef, $theComponent, $theWeb))
      {
        # %SYSTEMWEB%
        ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
      } else {
        $theWeb = $systemWeb;
        $theComponent = 'Web' . $component;
        if ( Foswiki::Func::topicExists($theWeb, $theComponent)
          && Foswiki::Func::checkAccessPermission('VIEW', $userName, undef, $theComponent, $theWeb))
        {
          ($meta, $text) = Foswiki::Func::readTopic($theWeb, $theComponent);
        } else {
          return ('', undef, undef);    # not found
        }
      }
    }
  }

  # extract INCLUDE area
  $text =~ s/.*?%STARTINCLUDE%//gs;
  $text =~ s/%STOPINCLUDE%.*//gs;

  return ($text, $theWeb, $theComponent);
}

1;
