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

our $START = '(?:^|(?<=[\w\b\s]))';
our $STOP = '(?:$|(?=[\w\b\s\,\.\;\:\!\?\)\(]))';

BEGIN {
  #print STDERR "Perl Version $]\n";
}


###############################################################################
our $baseWeb;
our $baseTopic;

our $VERSION = '3.99_011';
our $RELEASE = '3.99_011';
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
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );
  Foswiki::Func::registerRESTHandler(
    'unsubscribe',
    sub {
      require Foswiki::Plugins::NatSkinPlugin::Subscribe;
      return Foswiki::Plugins::NatSkinPlugin::Subscribe::restSubscribe(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
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
sub endRenderingHandler {

  if ($Foswiki::cfg{NatSkin}{DetectExternalLinks}) {
    require Foswiki::Plugins::NatSkinPlugin::ExternalLink;
    $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.Foswiki::Plugins::NatSkinPlugin::ExternalLink::render($1,$2)/geoi;
  }

  if ($Foswiki::cfg{NatSkin}{FixTypograpghy}) {
    $_[0] =~ s((?<=[^\w\-])\-\-\-(?=[^\w\-\+]))(&#8212;)go;         # emdash
    $_[0] =~ s/$START``$STOP/&#8220/go;
    $_[0] =~ s/$START''$STOP/&#8221/go;
    $_[0] =~ s/$START,,$STOP/&#8222/go;
    $_[0] =~ s/$START\(c\)$STOP/&#169/go;
    $_[0] =~ s/$START\(r\)$STOP/&#174/go;
    $_[0] =~ s/$START\(tm\)$STOP/&#8482/go;
    $_[0] =~ s/$START\.\.\.$STOP/&#8230/go;
    $_[0] =~ s/\-&gt;/&#8594;/go;
    $_[0] =~ s/&lt;\-/&#8592;/go;
  }

}

###############################################################################
sub modifyHeaderHandler {
  my ($headers, $query) = @_;

  # force IE to the latest version; use chrome frame if available
  my $xuaCompatible = $Foswiki::cfg{NatSkin}{XuaCompatible};
  $xuaCompatible = 'ie=edge,chrome=1' unless defined $xuaCompatible;
  $headers->{"X-UA-Compatible"} = $xuaCompatible if $xuaCompatible;

  # enable security headers
  $headers->{"X-Frame-Options"} = "DENY" if $Foswiki::cfg{NatSkin}{DenyFrameOptions};
  $headers->{"Strict-Transport-Security"} = $Foswiki::cfg{NatSkin}{StrictTransportSecurity} if $Foswiki::cfg{NatSkin}{StrictTransportSecurity};
  $headers->{"X-Content-Type-Options"} = $Foswiki::cfg{NatSkin}{ContentTypeOptions} if $Foswiki::cfg{NatSkin}{ContentTypeOptions}; 
  $headers->{"X-Download-Options"} = $Foswiki::cfg{NatSkin}{DownloadOptions} if $Foswiki::cfg{NatSkin}{DownloadOptions};
  $headers->{"X-XSS-Protection"} = $Foswiki::cfg{NatSkin}{XSSProtection} if $Foswiki::cfg{NatSkin}{XSSProtection};

  if ($Foswiki::cfg{NatSkin}{ContentSecurityPolicy}) {
    $headers->{"Content-Security-Policy"} = $Foswiki::cfg{NatSkin}{ContentSecurityPolicy};

    # deprecated header
    # $headers->{"X-Content-Security-Policy"} = $Foswiki::cfg{NatSkin}{ContentSecurityPolicy};
    # $headers->{"X-Webkit-Csp"} = $Foswiki::cfg{NatSkin}{ContentSecurityPolicy};
  }

}

1;

