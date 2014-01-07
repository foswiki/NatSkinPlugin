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

package Foswiki::Plugins::NatSkinPlugin::UserActions;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Meta ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();

###############################################################################
sub render {
  my ($session, $params, $topic, $web) = @_;

  my $baseTopic = $session->{topicName};
  my $baseWeb = $session->{webName};

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  
  my $text = $params->{_DEFAULT} || $params->{format};
  $text = '$edit$sep$attach$sep$new$sep$raw$sep$delete$sep$history$sepprint$sep$more'
    unless defined $text;

  my $context = Foswiki::Func::getContext();

  my $guestText = $params->{guest};
  $guestText = '$login$sep$register' 
    unless defined $guestText;

  $text = $guestText unless $context->{authenticated};

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();
  if ($themeEngine->{skinState}{"history"}) {
    my $historyText = $params->{history};
    $text = $historyText if defined $historyText;
  }

  return '' unless $text;

  if ($context->{GenPDFPrincePluginEnabled} || 
      $context->{GenPDFWebkitPluginEnabled} ||
      $context->{PdfPluginEnabled}) {
    # SMELL: how do we detect GenPDFAddOn...see also getPdfUrl
    $context->{can_generate_pdf} = 1;
  }

  # params used by all actions
  my $actionParams = ();

  $actionParams->{topic} = $topic;
  $actionParams->{web} = $web;
  $actionParams->{baseTopic} = $baseTopic;
  $actionParams->{baseWeb} = $baseWeb;
  $actionParams->{menu} = $params->{menu};
  $actionParams->{menu_header} = $params->{menu_header};
  $actionParams->{menu_footer} = $params->{menu_footer};
  $actionParams->{hiderestricted} = Foswiki::Func::isTrue($params->{hiderestricted}, 0);
  $actionParams->{mode} = $params->{mode} || 'short';
  $actionParams->{sep} = $params->{sep} || $params->{separator} || '<span class="natSep"> | </span>';

  # get restrictions
  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'edit, attach, move, delete, diff, more, raw'
    unless defined $restrictedActions;
  %{$actionParams->{isRestrictedAction}} = map { $_ => 1 } split(/\s*,\s*/, $restrictedActions);

  # a guest can't subscribe to changes
  if (Foswiki::Func::isGuest()) {
    $actionParams->{isRestrictedAction}{'subscribe'} = 1;
  }

  # list all actions that need edit rights
  if ($actionParams->{isRestrictedAction}{'edit'}) {
    $actionParams->{isRestrictedAction}{'attach'} = 1;
    $actionParams->{isRestrictedAction}{'delete'} = 1;
    $actionParams->{isRestrictedAction}{'editform'} = 1;
    $actionParams->{isRestrictedAction}{'editsettings'} = 1;
    $actionParams->{isRestrictedAction}{'editraw'} = 1;
    $actionParams->{isRestrictedAction}{'editformsettings'} = 1;
    $actionParams->{isRestrictedAction}{'edittext'} = 1;
    $actionParams->{isRestrictedAction}{'harvest'} = 1;
    $actionParams->{isRestrictedAction}{'webdavdir'} = 1;
    $actionParams->{isRestrictedAction}{'move'} = 1;
    $actionParams->{isRestrictedAction}{'restore'} = 1;
  }

  # if you've got access to this topic then all actions are allowed
  my $wikiName = Foswiki::Func::getWikiName();
  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $baseTopic, $baseWeb);
  $actionParams->{isRestrictedAction} = () if $gotAccess;

  # disable registration
  unless ($context->{registration_enabled}) {
    $actionParams->{isRestrictedAction}{'register'} = 1;
  }

  my $request = Foswiki::Func::getCgiQuery();
  $actionParams->{isRaw} = ($request) ? $request->param('raw') : '';

  my $isCompare = ($themeEngine->{skinState}{'action'} eq 'compare')?1:0;
  my $isRdiff = ($themeEngine->{skinState}{'action'} eq 'rdiff')?1:0;
  $actionParams->{action} = 'view';
  $actionParams->{action} = 'compare' if $isCompare;
  $actionParams->{action} = 'rdiff' if $isRdiff;

  $text = formatResult($text, $actionParams);

  return '' unless $text;

  return Foswiki::Func::decodeFormatTokens($header . $text . $footer);
}

###############################################################################
sub formatResult {
  my ($text, $params, $mode) = @_;

  $mode ||= $params->{mode} || 'short';

  # menu can contain actions. so it goes first
  $text =~ s/\$menu/renderMenu($params, $mode)/ge;

  # special actions
  $text =~ s/\$(?:editform\b|action\(editform(?:,\s*(.*?))?\))/renderEditForm($params, $1, $mode)/ge;
  $text =~ s/\$(?:account\b|action\(account(?:,\s*(.*?))?\))/renderAccount($params, $1, $mode)/ge;
  $text =~ s/\$(?:diff\b|action\(diff(?:,\s*(.*?))?\))/renderDiff($params, $1, $mode)/ge;
  $text =~ s/\$(?:edit\b|action\(edit(?:,\s*(.*?))?\))/renderEdit($params, $1, $mode)/ge;
  $text =~ s/\$(?:view\b|action\(view(?:,\s*(.*?))?\))/renderView($params, $1, $mode)/ge;
  $text =~ s/\$(?:first\b|action\(first(?:,\s*(.*?))?\))/renderFirst($params, $1, $mode)/ge;
  $text =~ s/\$(?:last\b|action\(last(?:,\s*(.*?))?\))/renderLast($params, $1, $mode)/ge;
  $text =~ s/\$(?:login\b|action\(login(?:,\s*(.*?))?\))/renderLogin($params, $1, $mode)/ge;
  $text =~ s/\$(?:next\b|action\(next(?:,\s*(.*?))?\))/renderNext($params, $1, $mode)/ge;
  $text =~ s/\$(?:prev\b|action\(prev(?:,\s*(.*?))?\))/renderPrev($params, $1, $mode)/ge;
  $text =~ s/\$(?:raw\b|action\(raw(?:,\s*(.*?))?\))/renderRaw($params, $1, $mode)/ge;
  $text =~ s/(\$sep)?\$(?:logout\b|action\(logout(?:,\s*(.*?))?\))/renderLogout($params, $1, $2, $mode)/ge;

  # normal actions / backwards compatibility
  $text =~ s/\$(attach|copytopic|delete|editsettings|edittext|help|history|more|move|new|pdf|print|register|restore|users)\b/renderAction($1, $params, undef, undef, undef, $mode)/ge;

  # generic actions
  $text =~ s/\$action\((.*?)(?:,\s*(.*?))?\)/renderAction($1, $params, undef, undef, $2, $mode)/ge;

  # action urls
  $text =~ s/\$diffurl\b/getDiffUrl($params)/ge;
  $text =~ s/\$editurl\b/getEditUrl($params)/ge;
  $text =~ s/\$restoreurl\b/getRestoreUrl($params)/ge;
  $text =~ s/\$firsturl\b/getFirstUrl($params)/ge;
  $text =~ s/\$prevurl\b/getPrevUrl($params)/ge;
  $text =~ s/\$nexturl\b/getNextUrl($params)/ge;
  $text =~ s/\$lasturl\b/getLastUrl($params)/ge;
  $text =~ s/\$helpurl\b/getHelpUrl($params)/ge;
  $text =~ s/\$loginurl\b/getLoginUrl($params)/ge;
  $text =~ s/\$logouturl/getLogoutUrl($params)/ge;
  $text =~ s/\$registerurl/getRegisterUrl($params)/ge;
  $text =~ s/\$pdfurl\b/getPdfUrl($params)/ge;

  $text =~ s/\$sep\b/$params->{sep}/g;
  $text =~ s/\$restorerev\b/getRestoreRev($params)/ge;
  $text =~ s/\$rev\b/getRev($params)/ge;

  return $text;
}

###############################################################################
sub renderAction {
  my ($action, $params, $template, $restrictedTemplate, $context, $mode) = @_;

  #print STDERR "called renderAction($action,".($context?"'".$context."'":'').")\n";

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  $template = uc($action)."_ACTION" unless defined $template;
  $restrictedTemplate = uc($action)."_ACTION_RESTRICTED" unless defined $restrictedTemplate;

  my $result = '';
  if ($params->{isRestrictedAction}{$action}) {
    return '' if $params->{hiderestricted};
    $result = Foswiki::Func::expandTemplate($restrictedTemplate);
  } else {
    $result = Foswiki::Func::expandTemplate($template);
  }

  my $label = getLabelForAction(uc($action), $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderEdit {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $label;
  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();

  if ($params->{isRestrictedAction}{'edit'}) {
    return '' if $params->{hiderestricted};
    if($themeEngine->{skinState}{"history"}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED');
      $label = getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION_RESTRICTED');
      $label = getLabelForAction("EDIT", $mode);
    }
  } else {
    if($themeEngine->{skinState}{"history"}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION');
      $label = getLabelForAction("RESTORE", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION');
      $label = getLabelForAction("EDIT", $mode);
    }
  }

  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderView {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::getThemeEngine();

  if ($params->{isRestrictedAction}{'view'}) {
    return '' if $params->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
  } else {
    if ($themeEngine->{skinState}{"action"} eq 'view' ) {
      return '';
    } else {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
    }
  }
  
  my $label = getLabelForAction("VIEW", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getEditUrl {
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef, 't' => time(),);
}

###############################################################################
sub getRestoreRev {
  my $params = shift;

  my $rev = getCurRev($params) - 1;
  $rev = 1 if $rev < 1;

  return $rev;
}

###############################################################################
sub getRestoreUrl {
  my $params = shift;

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    "edit", undef, undef,
    't' => time(),
    'rev' => getRestoreRev($params)
  );
}

###############################################################################
sub renderRaw {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $label;

  if ($params->{isRestrictedAction}{'raw'}) {
    return '' if $params->{hiderestricted};
    if ($params->{isRaw}) {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
      $label = getLabelForAction("VIEW", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('RAW_ACTION_RESTRICTED');
      $label = getLabelForAction("RAW", $mode);
    }
  } else {
    if($params->{isRaw}) {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
      $label = getLabelForAction("VIEW", $mode);
    } else {
      $result = Foswiki::Func::expandTemplate('RAW_ACTION');
      $label = getLabelForAction("RAW", $mode);
    }
  }

  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderMenu {
  my ($params, $mode) = @_;

  my $result = '';

  if ($params->{isRestrictedAction}{'menu'}) {
    return '' if $params->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('MENU_RESTRICTED');
  } else {
    my $menu = $params->{menu};
    my $header = $params->{menu_header};
    my $footer = $params->{menu_footer};
    $menu = Foswiki::Func::expandTemplate('MENU_FORMAT') unless defined $menu;
    $header = Foswiki::Func::expandTemplate('MENU_HEADER') unless defined $header;
    $footer = Foswiki::Func::expandTemplate('MENU_FOOTER') unless defined $footer;
    $result = $header.$menu.$footer;
  }

  my $label = getLabelForAction("MENU", $mode);
  $result =~ s/\$label/$label/g;

  return formatResult($result, $params, "long");
}

###############################################################################
sub getPdfUrl {

  my $url;
  my $context = Foswiki::Func::getContext();
  if ($context->{GenPDFPrincePluginEnabled} || $context->{GenPDFWebkitPluginEnabled}) {
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      'view',
      undef, undef,
      'contenttype' => 'application/pdf',
      'cover' => 'print',
    );
  } else {

    # SMELL: can't check for GenPDFAddOn reliably; we'd like to
    # default to normal printing if no other print helper is installed
    $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('genpdf', undef, undef, 'cover' => 'print',);
  }
  my $extraParams = Foswiki::Plugins::NatSkinPlugin::Utils::makeParams();
  $url .= ';' . $extraParams if $extraParams;

  return $url;
}

###############################################################################
sub getLabelForAction {
  my ($action, $mode) = @_;

  my $label = Foswiki::Func::expandTemplate($action."_".uc($mode));
  $label = Foswiki::Func::expandTemplate($action) unless $label;

  return $label;
}

###############################################################################
sub renderEditForm {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  my $session = $Foswiki::Plugins::SESSION;
  my ($topicObj) = Foswiki::Func::readTopic($params->{baseWeb}, $params->{baseTopic});
  if ($topicObj && $topicObj->getFormName) {
    if ($params->{isRestrictedAction}{'editform'}) {
      return '' if $params->{hiderestricted};
      $result = Foswiki::Func::expandTemplate("EDITFORM_ACTION_RESTRICTED");
    }
    $result = Foswiki::Func::expandTemplate("EDITFORM_ACTION");

  }

  my $label = getLabelForAction("EDITFORM", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub renderAccount {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $wikiName = Foswiki::Func::getWikiName();

  if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
  } else {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
  }

  my $label = getLabelForAction("ACCOUNT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getHelpUrl {
  my $params = shift;

  my $helpTopic = $params->{help} || "UsersGuide";
  my $helpWeb = $Foswiki::cfg{SystemWebName};

  ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($helpWeb, $helpTopic);

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $helpWeb, $helpTopic);
}

###############################################################################
sub renderFirst {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  if ($params->{isRestrictedAction}{'first'} || getCurRev($params) == getNrRev($params)+1) {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
  } else {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION');
  }

  my $label = getLabelForAction("FIRST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getFirstUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 'rev'=>1);
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath($params->{action}, undef, undef,
      'rev1'=>(1+getNrRev($params)),
      'rev2'=>1
    );
  }
}

###############################################################################
sub renderLogin {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';

  my $loginUrl = getLoginUrl();
  if ($loginUrl) {
    if ($params->{isRestrictedAction}{'login'}) {
      return '' if $params->{hiderestricted};
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION');
    }
  }

  my $label = getLabelForAction("LOG_IN", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLoginUrl {
  my $session = $Foswiki::Plugins::SESSION;

  return '' unless $session;

  my $loginManager = $session->{loginManager} || # TMwiki-4.2
    $session->{users}->{loginManager} || # TMwiki-4.???
    $session->{client} || # TMwiki-4.0
    $session->{users}->{loginManager}; # Foswiki

  return $loginManager->loginUrl();
}


###############################################################################
sub renderLogout {
  my ($params, $sep, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});


  my $result = '';
  $sep ||= '';

  my $logoutUrl = getLogoutUrl();
  if ($logoutUrl) {
    if ($params->{isRestrictedAction}{'logout'}) {
      return '' if $params->{hiderestricted};
      $result = $sep.Foswiki::Func::expandTemplate('LOG_OUT_ACTION_RESTRICTED');
    } else {
      $result = $sep.Foswiki::Func::expandTemplate('LOG_OUT_ACTION');
    }
  }

  my $label = getLabelForAction("LOG_OUT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLogoutUrl {

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->logoutUrl();
  #
  # but for now the "best" we can do is this:
  my $loginManager = $Foswiki::cfg{LoginManager};
  if ($loginManager =~ /ApacheLogin/) {
    return '';
  } 
  
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, logout=>1);
}


###############################################################################
sub getRegisterUrl {

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->registerUrl();
  #
  # but for now the "best" we can do is this:
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $Foswiki::cfg{SystemWebName}, 'UserRegistration');
}


###############################################################################
sub renderLast {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = ($params->{isRestrictedAction}{'last'} || getCurRev($params) == getMaxRev($params))?
    Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('LAST_ACTION');

  my $label = getLabelForAction("LAST", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getLastUrl {
  my $params = shift;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev' => getMaxRev($params));
  } else {
    my $rev2 = getMaxRev($params) - getNrRev($params);
    $rev2 = 1 if $rev2 < 1;

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getMaxRev($params),
      'rev2' => $rev2
    );
  }
}

###############################################################################
sub renderNext {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = ($params->{isRestrictedAction}{'next'} || getNextRev($params) > getMaxRev($params))?
    Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('NEXT_ACTION');

  my $label = getLabelForAction("NEXT", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getNextUrl {
  my $params = shift;

  my $request = Foswiki::Func::getCgiQuery();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($params->{action} eq 'view') {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev'=>getRev($params) + getNrRev($params)
    );
  } else {
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getNextRev($params),
      'rev2' => getCurRev($params),
      'context' => $context,
    );
  }
}

###############################################################################
sub renderPrev {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = ($params->{isRestrictedAction}{'prev'} || getPrevRev($params) <= 1)?
    Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED'):
    Foswiki::Func::expandTemplate('PREV_ACTION');

  my $label = getLabelForAction("PREV", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getPrevUrl {
  my $params = shift;

  my $request = Foswiki::Func::getCgiQuery();
  my $context = $request->param("context");
  $context = 1 unless defined $context;

  if ($params->{action} eq 'view') {
    my $rev = getRev($params) - getNrRev($params);
    $rev = 1 if $rev < 1;
    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'rev'=>$rev
    );
  } else {

    my $rev2 = getPrevRev($params) - getNrRev($params);
    $rev2 = 1 if $rev2 < 1;

    return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{action}, undef, undef,
      'rev1' => getPrevRev($params),
      'rev2' => $rev2,
      'context' => $context,
    );
  }
}

###############################################################################
sub renderDiff {
  my ($params, $context, $mode) = @_;

  return '' if (defined($context) && !Foswiki::Func::getContext()->{$context});

  my $result = '';
  if ($params->{isRestrictedAction}{'diff'}) {
    return '' if $params->{hiderestricted};
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
  } else {
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION');
  }

  my $label = getLabelForAction("DIFF", $mode);
  $result =~ s/\$label/$label/g;

  return $result;
}

###############################################################################
sub getDiffUrl {
  my $params = shift;

  my $rev2 = getCurRev($params) - getNrRev($params);
  $rev2 = 1 if $rev2 < 1;

  my $action = $params->{action};
  if ($action !~ /^(compare|rdiff)$/) {
    my $context = Foswiki::Func::getContext();
    $action = $context->{CompareRevisionsAddonPluginEnabled} ? "compare" : "rdiff";
  }
  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    $action, undef, undef,
    'rev1' => getCurRev($params),
    'rev2' => $rev2
  );

}

###############################################################################
sub getMaxRev {
  my $params = shift;

  unless (defined $params->{maxRev}) {
    $params->{maxRev} = Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision();
  }

  return $params->{maxRev};
}

###############################################################################
sub getCurRev {
  my $params = shift;

  unless (defined $params->{curRev}) {
    $params->{curRev} =
         Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision()
      || getMaxRev($params)
      || 1;
  }

  return $params->{curRev};
}

###############################################################################
sub getRev {
  my $params = shift;

  unless (defined $params->{rev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev = $request->param('rev');
      my $rev1 = $request->param('rev1');
      my $rev2 = $request->param('rev2');

      if (defined($rev)) {
        $params->{rev} = $rev;
      } elsif (!defined($rev1) && !defined($rev2)) {
        $params->{rev} = getCurRev($params);
      } else {
        $rev1 ||= 1;
        $rev2 ||= 1;
        $params->{rev} = $rev1 > $rev2 ? $rev1 : $rev2;
      }
    }
  }

  return $params->{rev};
}

###############################################################################
sub getNrRev {
  my $params = shift;

  unless (defined $params->{nrRev}) {
    my $request = Foswiki::Func::getCgiQuery();
    if ($request) {
      my $rev1 = $request->param('rev1') || 1;
      my $rev2 = $request->param('rev2') || 1;
      $params->{nrRev} = abs($rev1 - $rev2);
    }
    #$params->{nrRev} = $Foswiki::cfg{NumberOfRevisions} unless $params->{nrRev};
    $params->{nrRev} = 1 unless $params->{nrRev};
  }

  return $params->{nrRev};
}

###############################################################################
sub getPrevRev {
  my $params = shift;

  unless (defined $params->{prevRev}) {
    $params->{prevRev} = getCurRev($params) - getNrRev($params);
    $params->{prevRev} = 1 if $params->{prevRev} < 1;
  }

  return $params->{prevRev};
}

###############################################################################
sub getNextRev {
  my $params = shift;

  unless (defined $params->{nextRev}) {
    $params->{nextRev} = getCurRev($params) + getNrRev($params);
  }

  return $params->{nextRev};
}

1;
