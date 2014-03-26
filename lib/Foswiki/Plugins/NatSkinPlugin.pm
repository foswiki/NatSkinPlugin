###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2014 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();
use Foswiki::Plugins::NatSkinPlugin::WebComponent ();

###############################################################################
our $baseWeb;
our $baseTopic;

our $VERSION = '3.99_008';
our $RELEASE = '3.99_008';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Support plugin for <nop>NatSkin';
our $themeEngine;

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # theme engine macros
  Foswiki::Func::registerTagHandler(
    'SKINSTATE',
    sub {
      return getThemeEngine()->renderSkinState(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNSTYLES',
    sub {
      return getThemeEngine()->renderStyles(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'KNOWNVARIATIONS',
    sub {
      return getThemeEngine()->renderVariations(@_);
    }
  );

  # REVISIONS, MAXREV, CURREV replacements
  Foswiki::Func::registerTagHandler(
    'PREVREV',
    sub {
      return Foswiki::Plugins::NatSkinPlugin::Utils::getPrevRevision($baseWeb, $baseTopic, 1);
    }
  );

  Foswiki::Func::registerTagHandler(
    'CURREV',
    sub {
      return Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision($baseWeb, $baseTopic);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATMAXREV',
    sub {
      return Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision($baseWeb, $baseTopic);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATREVISIONS',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Revisions;
      return Foswiki::Plugins::NatSkinPlugin::Revisions::render(@_);
    }
  );

  # skin macros
  Foswiki::Func::registerTagHandler(
    'USERACTIONS',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::UserActions;
      return Foswiki::Plugins::NatSkinPlugin::UserActions::render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATWEBLOGO',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::WebLogo;
      return Foswiki::Plugins::NatSkinPlugin::WebLogo::render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'NATSTYLEURL',
    sub {
      return getThemeEngine()->getStyleUrl();
    }
  );

  Foswiki::Func::registerTagHandler(
    'HTMLTITLE',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::HtmlTitle;
      return Foswiki::Plugins::NatSkinPlugin::HtmlTitle::render(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'IFSUBSCRIBED',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::render(@_);
    }
  );

  Foswiki::Func::registerRESTHandler(
    'subscribe',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::restSubscribe(@_);
    }
  );
  Foswiki::Func::registerRESTHandler(
    'unsubscribe',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::restSubscribe(@_);
    }
  );

  Foswiki::Func::registerTagHandler(
    'WEBCOMPONENT',
    sub {
      return Foswiki::Plugins::NatSkinPlugin::WebComponent::render(@_);
    }
  );

  # init modules
  $themeEngine = undef;
  getThemeEngine()->init();

  Foswiki::Plugins::NatSkinPlugin::Utils::init();
  Foswiki::Plugins::NatSkinPlugin::WebComponent::init();

  #print STDERR "Perl Version $]\n";

  return 1;
}

###############################################################################
sub getThemeEngine {
  unless (defined $themeEngine) {
    $themeEngine = new Foswiki::Plugins::NatSkinPlugin::ThemeEngine();
  }

  return $themeEngine;
}

###############################################################################
sub postRenderingHandler {

  # detect external links
  return unless $Foswiki::cfg{NatSkin}{DetectExternalLinks};

  require Foswiki::Plugins::NatSkinPlugin::ExternalLink;

  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.Foswiki::Plugins::NatSkinPlugin::ExternalLink::render($1,$2)/geoi;
}

###############################################################################
sub modifyHeaderHandler {
  my ($headers, $query) = @_;

  # force IE to the latest version; use chrome frame if available
  my $xuaCompatible = $Foswiki::cfg{NatSkin}{XuaCompatible};
  $xuaCompatible = 'ie=edge,chrome=1' unless defined $xuaCompatible;

  $headers->{"X-UA-Compatible"} = $xuaCompatible if $xuaCompatible;
}

1;

