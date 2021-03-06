###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2003-2019 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::ThemeEngine;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();
use Foswiki::Plugins::JQueryPlugin ();

use constant TRACE => 0;    # toggle me

###############################################################################
# static
sub writeDebug {
  return unless TRACE;
  print STDERR "- NatSkinPlugin::ThemeEngine - " . $_[0] . "\n";
}

###############################################################################
sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  #writeDebug("new themegine");

  my $this = {
    session => $session,    
    defaultStyle => $Foswiki::cfg{NatSkin}{Style} || 'matter',
    defaultVariation => $Foswiki::cfg{NatSkin}{Variation} || 'off',
    defaultLayout => $Foswiki::cfg{NatSkin}{Layout} || 'fixed',
    defaultMenu => Foswiki::Func::isTrue($Foswiki::cfg{NatSkin}{Menu}, 1),
    defaultStyleSideBar => $Foswiki::cfg{NatSkin}{SideBar} || 'right',
    displayCookieInfo => $Foswiki::cfg{NatSkin}{DisplayCookieInfo} || 'on',
    @_
  };
  bless($this, $class);

  my $noSideBarActions = $Foswiki::cfg{NatSkin}{NoSideBarActions}
    || 'edit, manage, login, logon, oops, register, compare, rdiff';
  %{$this->{noSideBarActions}} = map { $_ => 1 } split(/\s*,\s*/, $noSideBarActions);

  # make sure there's a default record
  unless (defined $Foswiki::cfg{NatSkin}{Themes}) {
    $Foswiki::cfg{NatSkin}{Themes} = {
      Matter => {
        baseUrl => '%PUBURLPATH%/%SYSTEMWEB%/MatterTheme',
        logoUrl => '%PUBURLPATH%/%SYSTEMWEB%/MatterTheme/foswiki-logo.png',
        styles => {
          matter => 'matter.css',
        }
      }
    };
  }

  # index which style is part of which theme
  $this->{knownStyles} = ();
  while (my ($themeId, $themeRecord) = each %{$Foswiki::cfg{NatSkin}{Themes}}) {
    foreach my $style (keys %{$themeRecord->{styles}}) {
      $this->{knownStyles}{lc($style)} = $themeId;
    }
  }

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  foreach my $key (keys %$this) {
    undef $this->{$key};
  }
}

###############################################################################
sub getThemeRecord {
  my ($this, $theStyle) = @_;

  unless (defined $theStyle) {
    $theStyle = lc($this->{skinState}{style});
  }

  my $themeId = $this->{knownStyles}{lc($theStyle)};
  return unless defined $themeId;

  my $themeRecord = $Foswiki::cfg{NatSkin}{Themes}{$themeId};
  return unless defined $themeRecord;

  return $themeRecord;
}

###############################################################################
sub init {
  my $this = shift;
  writeDebug("init skin state");

  my $theStyle;
  my $theLayout;
  my $theMenu;
  my $theStyleSideBar;
  my $theStyleVariation;
  my $theToggleSideBar;

  my $doStickyStyle = 0;
  my $doStickyLayout = 0;
  my $doStickyMenu = 0;
  my $doStickySideBar = 0;
  my $doStickyTopicActions = 0;
  my $doStickyVariation = 0;
  my $found = 0;

  # from request
  my $request = Foswiki::Func::getCgiQuery();

  if ($request) {
    $theStyle = $request->param('style') || $request->param('skinstyle') || '';

    if ($theStyle eq 'reset') {

      #writeDebug("clearing session values");

      $theStyle = '';
      Foswiki::Func::clearSessionValue('NATSKIN_STYLE');
      Foswiki::Func::clearSessionValue('NATSKIN_LAYOUT');
      Foswiki::Func::clearSessionValue('NATSKIN_MENU');
      Foswiki::Func::clearSessionValue('NATSKIN_SIDEBAR');
      Foswiki::Func::clearSessionValue('NATSKIN_VARIATION');
      my $redirectUrl = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view');
      Foswiki::Func::redirectCgiQuery($request, $redirectUrl);

      # we need to force a new request because the session value preferences
      # are still loaded in the preferences cache; only clearing them in
      # the session object is not enough right now but will be during the next
      # request; so we redirect to the current url
      return 0;
    } else {
      $theLayout = $request->param('skinlayout');
      $theMenu = $request->param('skinmenu');
      $theStyleSideBar = $request->param('skinsidebar');
      $theStyleVariation = $request->param('skinvariation');
      $theToggleSideBar = $request->param('togglesidebar');
    }
  }

  # handle style
  my $prefStyle =
       Foswiki::Func::getSessionValue('NATSKIN_STYLE')
    || Foswiki::Func::getPreferencesValue('NATSKIN_STYLE')
    || Foswiki::Func::getPreferencesValue('SKINSTYLE')    # backwards compatibility
    || $this->{defaultStyle};

  $prefStyle =~ s/^\s+//;
  $prefStyle =~ s/\s+$//;
  if ($theStyle) {
    $theStyle =~ s/^\s+//;
    $theStyle =~ s/\s+$//;
    $doStickyStyle = 1 if lc($theStyle) ne lc($prefStyle);
  } else {
    $theStyle = $prefStyle;
  }
  if ($theStyle =~ /^(off|none)$/o) {
    $theStyle = 'off';
  } else {
    $found = 0;
    foreach my $style (keys %{$this->{knownStyles}}) {
      if ($style eq $theStyle || lc($style) eq lc($theStyle)) {
        $found = 1;
        $theStyle = $style;
        last;
      }
    }
    $theStyle = $this->{defaultStyle} unless $found;
  }
  $theStyle = $this->{defaultStyle} unless $this->{knownStyles}{$theStyle};

  $this->{skinState}{'style'} = $theStyle;
  my $themeRecord = $this->getThemeRecord($theStyle);

  #writeDebug("theStyle=$theStyle");

  # handle layout
  # TODO: provide backcompatibilty
  my $prefLayout =
       Foswiki::Func::getSessionValue('NATSKIN_LAYOUT')
    || Foswiki::Func::getPreferencesValue('NATSKIN_LAYOUT')
    || $this->{defaultLayout};

  $prefLayout =~ s/^\s+//;
  $prefLayout =~ s/\s+$//;
  if ($theLayout) {
    $theLayout =~ s/^\s+//;
    $theLayout =~ s/\s+$//;
    $doStickyLayout = 1 if $theLayout ne $prefLayout;
  } else {
    $theLayout = $prefLayout;
  }
  $theLayout = $this->{defaultLayout} if $theLayout !~ /^(fixed|fluid|bordered)$/;
  $this->{skinState}{'layout'} = $theLayout;

  # handle menu
  my $prefMenu =
    Foswiki::Func::isTrue(Foswiki::Func::getSessionValue('NATSKIN_MENU') || Foswiki::Func::getPreferencesValue('NATSKIN_MENU') || Foswiki::Func::getPreferencesValue('STYLEBUTTONS'), $this->{defaultMenu});
  $theMenu = Foswiki::Func::isTrue($theMenu, $prefMenu);
  $doStickyMenu = 1 if $theMenu ne $prefMenu;
  $this->{skinState}{'menu'} = $theMenu;

  # handle sidebar
  my $prefStyleSideBar =
       Foswiki::Func::getSessionValue('NATSKIN_SIDEBAR')
    || Foswiki::Func::getPreferencesValue('NATSKIN_SIDEBAR')
    || Foswiki::Func::getPreferencesValue('STYLESIDEBAR')    # backwards compatibility
    || $this->{defaultStyleSideBar};

  $prefStyleSideBar =~ s/^\s+//;
  $prefStyleSideBar =~ s/\s+$//;
  if ($theStyleSideBar) {
    $theStyleSideBar =~ s/^\s+//;
    $theStyleSideBar =~ s/\s+$//;
    $doStickySideBar = 1 if $theStyleSideBar ne $prefStyleSideBar;
  } else {
    $theStyleSideBar = $prefStyleSideBar;
  }
  $theStyleSideBar = $this->{defaultStyleSideBar} if $theStyleSideBar !~ /^(left|right|both|off)$/;
  $this->{skinState}{'sidebar'} = $theStyleSideBar;
  $theToggleSideBar = undef if $theToggleSideBar && $theToggleSideBar !~ /^(left|right|both|off)$/;

  # handle variation
  my $prefStyleVariation =
       Foswiki::Func::getSessionValue('NATSKIN_VARIATION')
    || Foswiki::Func::getPreferencesValue('NATSKIN_VARIATION')
    || Foswiki::Func::getPreferencesValue('STYLEVARIATION')    # backwards compatibility
    || $this->{defaultVariation};

  $prefStyleVariation =~ s/^\s+//;
  $prefStyleVariation =~ s/\s+$//;
  if ($theStyleVariation) {
    $theStyleVariation =~ s/^\s+//;
    $theStyleVariation =~ s/\s+$//;
    $doStickyVariation = 1 if lc($theStyleVariation) ne lc($prefStyleVariation);
  } else {
    $theStyleVariation = $prefStyleVariation;
  }
  $found = 0;
  foreach my $variation (keys %{$themeRecord->{variations}}) {
    if ($variation eq $theStyleVariation || lc($variation) eq lc($theStyleVariation)) {
      $found = 1;
      $theStyleVariation = $variation;
      last;
    }
  }
  $theStyleVariation = $this->{defaultVariation} unless $found;
  $this->{skinState}{'variation'} = $theStyleVariation;

  # store sticky state into session
  Foswiki::Func::setSessionValue('NATSKIN_STYLE', $this->{skinState}{'style'})
    if $doStickyStyle;
  Foswiki::Func::setSessionValue('NATSKIN_LAYOUT', $this->{skinState}{'layout'})
    if $doStickyLayout;
  Foswiki::Func::setSessionValue('NATSKIN_MENU', $this->{skinState}{'menu'})
    if $doStickyMenu;
  Foswiki::Func::setSessionValue('NATSKIN_SIDEBAR', $this->{skinState}{'sidebar'})
    if $doStickySideBar;
  Foswiki::Func::setSessionValue('NATSKIN_VARIATION', $this->{skinState}{'variation'})
    if $doStickyVariation;

  # misc
  $this->{skinState}{'action'} = getRequestAction();

  # switch on history context
  my $curRev = ($request) ? $request->param('rev') : '';
  if ($curRev || $this->{skinState}{"action"} =~ /r?diff|compare/) {
    $this->{skinState}{"history"} = 1;
  } else {
    $this->{skinState}{"history"} = 0;
  }

  # temporary toggles
  $theToggleSideBar = 'off' if $this->{noSideBarActions}{$this->{skinState}{'action'}};

  # switch the sidebar off if we need to authenticate
  if ($this->{noSideBarActions}{login}) {
    my $authScripts = $Foswiki::cfg{AuthScripts};
    if (
      $this->{skinState}{'action'} ne 'publish' &&    # SMELL to please PublishContrib
      $authScripts =~ /\b$this->{skinState}{'action'}\b/ && !Foswiki::Func::getContext()->{authenticated}
      )
    {
      $theToggleSideBar = 'off';
    }
  }

  $this->{skinState}{'sidebar'} = $theToggleSideBar
    if $theToggleSideBar && $theToggleSideBar ne '';

  # prepend style to template search path

  my $skin =
       $request->param('skin')
    || Foswiki::Func::getPreferencesValue('SKIN')
    || 'nat';

  # not using Foswiki::Func::getSkin() to prevent
  # getting the cover as well

  if ($skin =~ /\bnat\b/) {
    my @skin = map {$_ =~ /([[:alnum:].,\s]+)/} split(/\s*,\s*/, $skin); # clean skin setting
    my %skin = map { $_ => 1 } @skin;
    my @skinAddOns = ();
    my $prefix;

    # add variation
    if ($this->{skinState}{'variation'} ne 'off') {
      $prefix = lc($this->{skinState}{'variation'} . '.' . $this->{skinState}{'style'}) . '.nat';
      push @skinAddOns, $prefix unless $skin{$prefix};
    }

    # add style
    $prefix = lc($this->{skinState}{'style'}) . '.nat';
    push @skinAddOns, $prefix unless $skin{$prefix};

    # auto-add natedit
    push(@skinAddOns, "natedit") unless $skin{"natedit"};

    # compile new path
    my @newSkin = ();
    foreach my $item (@skin) {
      if ($item eq 'nat') {
        push @newSkin, @skinAddOns;
      }
      push @newSkin, $item;
    }

    # store session prefs
    my $newSkin = join(', ', @newSkin);
    writeDebug("setting SKIN to '$newSkin'");
    Foswiki::Func::setPreferencesValue('SKIN', $newSkin);

    if ($this->{skinState}{"action"} eq 'view') {
      Foswiki::Func::loadTemplate('sidebar');
      my $viewTemplate = $request->param('template')
        || Foswiki::Func::getPreferencesValue('VIEW_TEMPLATE');

      if (!$viewTemplate && $Foswiki::cfg{Plugins}{AutoTemplatePlugin}{Enabled}) {
        require Foswiki::Plugins::AutoTemplatePlugin;
        $viewTemplate = Foswiki::Plugins::AutoTemplatePlugin::getTemplateName($this->{session}{webName}, $this->{session}{topicName});
      }

      Foswiki::Func::loadTemplate($viewTemplate)
        if $viewTemplate;

      # check if 'sidebar' is empty. if so then switch it off in the skinState
      my $sidebar = Foswiki::Func::expandTemplate('sidebar');

      $this->{skinState}{'sidebar'} = 'off' unless $sidebar;
    }
  }

  # set context
  my $context = Foswiki::Func::getContext();
  foreach my $key (keys %{$this->{skinState}}) {
    my $val = $this->{skinState}{$key};
    next unless defined($val);

    $val = $val ? 'on' : 'off' if $key eq 'menu';

    my $var = lc('natskin_' . $key . '_' . $val);
    writeDebug("setting context $var");
    $context->{$var} = 1;
  }

  # SMELL: these misc helper contexts should be core
  $context->{allow_loginname} = 1 if $Foswiki::cfg{Register}{AllowLoginName};

  # check for "view printable version" and enter static content in case
  my $cover = $request->param("cover") || '';
  if ($cover =~ /\bprint\b/) {
    $context->{static} = 1;
  }

  # set cookie info 
  my $displayCookieInfo = 
    Foswiki::Func::getSessionValue('NATSKIN_COOKIEINFO') ||
    Foswiki::Func::getPreferencesValue('NATSKIN_COOKIEINFO') ||
    $this->{displayCookieInfo};

  if ($displayCookieInfo eq "on" || ($displayCookieInfo eq "guest" && !$context->{authenticated})) {
    $context->{cookie_info} = 1;
  }

  $skin = Foswiki::Func::getSkin();
  if ($skin =~ /\bnat\b/) {
    Foswiki::Func::setPreferencesValue('FOSWIKI_STYLE_URL', '%PUBURLPATH%/%SYSTEMWEB%/NatSkin/BaseStyle.css');
    Foswiki::Func::setPreferencesValue('FOSWIKI_COLORS_URL', '%NATSTYLEURL%');

    Foswiki::Func::addToZone('script', 'NATSKIN::POLYFILLS', <<'HERE');
<script type='text/javascript' src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/polyfills.js"></script>
HERE

    Foswiki::Func::addToZone('skinjs', 'NATSKIN::JS', <<'HERE', 'NATSKIN, NATSKIN::PREFERENCES, JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::SUPERFISH, JQUERYPLUGIN::UI');
<script type='text/javascript' src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/natskin.js"></script>
HERE

    Foswiki::Func::addToZone("skincss", 'NATSKIN', $this->renderSkinStyle(), 'TABLEPLUGIN_default, JQUERYPLUGIN::UI, JQUERYPLUGIN::THEME');
  }

  return 1;
}

###############################################################################
sub renderSkinState {
  my ($this, undef, $params) = @_;

  my $theFormat = $params->{_DEFAULT} || $params->{format}
    || '$style, $variation, $sidebar, $layout, $menu';

  my $theLowerCase = $params->{lowercase} || 0;
  $theLowerCase = ($theLowerCase eq 'on') ? 1 : 0;

  $theFormat =~ s/\$style/$this->{skinState}{'style'}/g;
  $theFormat =~ s/\$variation/$this->{skinState}{'variation'}/g;
  $theFormat =~ s/\$layout/$this->{skinState}{'layout'}/g;
  $theFormat =~ s/\$menu/$this->{skinState}{'menu'}/g;
  $theFormat =~ s/\$sidebar/$this->{skinState}{'sidebar'}/g;
  $theFormat = lc($theFormat);

  return Foswiki::Func::decodeFormatTokens($theFormat);
}

###############################################################################
sub renderSkinStyle {
  my $this = shift;

  my $theStyle;
  $theStyle = $this->{skinState}{'style'} || 'off';

  return '' if $theStyle eq 'off';

  my $theVariation;
  $theVariation = $this->{skinState}{'variation'} unless $this->{skinState}{'variation'} =~ /^(off|none)$/;
  $theVariation ||= '';

  $theStyle = lc $theStyle;
  $theVariation = lc $theVariation;

  my $themeRecord = $this->getThemeRecord($theStyle);
  return '' unless $themeRecord;

  #writeDebug("theStyle=$theStyle");
  #writeDebug("knownStyle=".join(',', sort keys %knownStyles));

  #my $media = (Foswiki::Func::getContext()->{static}) ? "all" : "print";
  my $media = "print";

  my $text = <<"HERE";
<link rel='stylesheet' href='%PUBURLPATH%/%SYSTEMWEB%/NatSkin/print.css' type='text/css' media='$media' />
<link rel='stylesheet' href='$themeRecord->{baseUrl}/$themeRecord->{styles}{$theStyle}' type='text/css' media='all' />
HERE

  if ($theVariation && $themeRecord->{variations}{$theVariation}) {
    $text .= <<"HERE";
<link rel='stylesheet' href='$themeRecord->{baseUrl}/$themeRecord->{variations}{$theVariation}' type='text/css' media='all' />
HERE
  }

  $text =~ s/^\s+|\s+$//g;

  return $text;
}

###############################################################################
sub renderVariations {
  my ($this, undef, $params) = @_;

  my $theStyle = $params->{style} || '.*';
  my $theFormat = $params->{format} || '$style: $variations';
  my $theSep = $params->{separator};
  my $theVarSep = $params->{varseparator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  $theSep = ', ' unless defined $theSep;
  $theVarSep = ', ' unless defined $theVarSep;

  my @result;
  foreach my $style (keys %{$this->{knownStyles}}) {
    next if $theStyle && $style !~ /^($theStyle)$/i;

    my $themeRecord = $this->getThemeRecord($style);
    next unless $themeRecord;

    my $vars = join($theVarSep, keys %{$themeRecord->{variations}});
    next unless $vars;

    my $line = $theFormat;
    $line =~ s/\$variations\b/$vars/g;
    $line =~ s/\$style\b/$style/g;
    push @result, $line;
  }

  return '' unless @result;
  return Foswiki::Func::decodeFormatTokens($theHeader . join($theSep, @result) . $theFooter);
}

###############################################################################
sub renderStyles {
  my ($this, undef, $params) = @_;

  # TODO: make it formatish

  return Foswiki::Func::decodeFormatTokens(join(', ', sort { $a cmp $b } keys %{$this->{knownStyles}}));
}

###############################################################################
sub getStyleUrl {
  my $this = shift;

  my $theStyle = lc($this->{skinState}{'style'});
  my $themeRecord = $this->getThemeRecord($theStyle);
  return $themeRecord->{baseUrl} . '/' . $themeRecord->{styles}{$theStyle};
}

###############################################################################
sub getRequestAction {

  my $theAction;

  my $request = Foswiki::Func::getCgiQuery();
  unless (defined($request->VERSION)) {    # Foswiki::Request
    $theAction = $request->action();
  }

  unless ($theAction) {                    # fallback
    my $context = Foswiki::Func::getContext();

    # not all cgi actions we want to distinguish set their context
    # to a known value. so only use those we are sure of
    return 'attach' if $context->{'attach'};
    return 'changes' if $context->{'changes'};
    return 'edit' if $context->{'edit'};
    return 'login' if $context->{'login'};
    return 'manage' if $context->{'manage'};
    return 'oops' if $context->{'oops'};
    return 'preview' if $context->{'preview'};
    return 'diff' if $context->{'diff'};
    return 'compare' if $context->{'compare'};
    return 'register' if $context->{'register'};
    return 'rename' if $context->{'rename'};
    return 'resetpasswd' if $context->{'resetpasswd'};
    return 'rest' if $context->{'rest'};
    return 'save' if $context->{'save'};
    return 'search' if $context->{'search'};
    return 'statistics' if $context->{'statistics'};
    return 'upload' if $context->{'upload'};
    return 'view' if $context->{'view'};
    return 'view' if $context->{'viewauth'};
    return 'viewfile' if $context->{'viewfile'};

    # fall back to analyzing the path info
    my $pathInfo = $ENV{'PATH_INFO'} || '';
    $theAction = $ENV{'REQUEST_URI'} || '';
    if ($theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
      $theAction = $1;
    } else {
      $theAction = 'view';
    }

  }

  #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
  #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
  #writeDebug("theAction=$theAction");

  return $theAction;
}

1;
