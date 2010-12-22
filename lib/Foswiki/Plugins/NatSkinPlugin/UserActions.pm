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

package Foswiki::Plugins::NatSkinPlugin::UserActions;
use strict;
use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::NatSkinPlugin::ThemeEngine ();
use Foswiki::Plugins::NatSkinPlugin::Utils ();

###############################################################################
sub render {
  my ($session, $params, $topic, $web) = @_;

  my $baseTopic = $session->{topicName};
  my $baseWeb = $session->{webName};
  my $sepString = $params->{sep} || $params->{separator} || '<span class="natSep"> | </span>';

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $text = $params->{_DEFAULT} || $params->{format};
  unless ($text) {
    $text = '<div class="natTopicActions">$edit$sep$attach$sep$new$sep$raw$sep$delete$sep$history$sep';
    $text .= '$subscribe$sep$' if Foswiki::Func::getContext()->{SubscribePluginEnabled};
    $text .= 'print$sep$more</div>';
  }

  unless (Foswiki::Func::getContext()->{authenticated}) {
    my $guestText = $params->{guest};
    $text = $guestText if defined $guestText;
  }

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
  if ($themeEngine->{skinState}{"history"}) {
    my $historyText = $params->{history};
    $text = $historyText if defined $historyText;
  }

  return '' unless $text;

  # params used by all actions
  my $actionParams = ();

  $actionParams->{topic} = $topic;
  $actionParams->{web} = $web;
  $actionParams->{baseTopic} = $baseTopic;
  $actionParams->{baseWeb} = $baseWeb;

  # get restrictions
  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'new, edit, attach, move, delete, diff, more, raw'
    unless defined $restrictedActions;
  %{$actionParams->{isRestrictedAction}} = map { $_ => 1 } split(/\s*,\s*/, $restrictedActions);
  $actionParams->{isRestrictedAction}{'subscribe'} = 1
    if Foswiki::Func::isGuest();

  my $wikiName = Foswiki::Func::getWikiName();
  my $gotAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, undef, $baseTopic, $baseWeb);
  $actionParams->{isRestrictedAction} = () if $gotAccess;

  # get change strings (edit, attach, move)
  $actionParams->{maxRev} = Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision();
  $actionParams->{curRev} =
       Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision()
    || $actionParams->{maxRev}
    || 1;

  my $request = Foswiki::Func::getCgiQuery();
  if ($request) {
    my $rev1 = $request->param('rev1') || 1;
    my $rev2 = $request->param('rev2') || 1;
    $actionParams->{nrRev} = abs($rev1 - $rev2);
  }

  my $isCompare = $themeEngine->{skinState}{'action'} eq 'compare';
  $actionParams->{nrRev} = 1 unless $actionParams->{nrRev};
  $actionParams->{prevRev} = $actionParams->{curRev} - $actionParams->{nrRev};
  $actionParams->{nextRev} = $actionParams->{curRev} + $actionParams->{nrRev};
  $actionParams->{isRaw} = ($request) ? $request->param('raw') : '';
  $actionParams->{diffCommand} = $isCompare ? 'compare' : 'rdiff';
  $actionParams->{renderMode} = ($request) ? $request->param('render') : '';
  $actionParams->{renderMode} = $isCompare ? 'interweave' : 'sequential' 
    unless $actionParams->{renderMode};

  $text =~ s/\$new/renderNew($actionParams)/ge;
  $text =~ s/\$editform/renderEditForm($actionParams)/ge;
  $text =~ s/\$edittext/renderEditText($actionParams)/ge;
  $text =~ s/\$edit/renderEdit($actionParams)/ge;
  $text =~ s/\$attach/renderAttach($actionParams)/ge;
  $text =~ s/\$move/renderMove($actionParams)/ge;
  $text =~ s/\$delete/renderDelete($actionParams)/ge;
  $text =~ s/\$raw/renderRaw($actionParams)/ge;
  $text =~ s/\$history/renderHistory($actionParams)/ge;
  $text =~ s/\$more/renderMore($actionParams)/ge;
  $text =~ s/\$print/renderPrint($actionParams)/ge;
  $text =~ s/\$pdf/renderPdf($actionParams)/ge;
  $text =~ s/\$login/renderLogin($actionParams)/ge;
  $text =~ s/\$register/renderRegister($actionParams)/ge;
  $text =~ s/\$account/renderAccount($actionParams)/ge;
  $text =~ s/\$users/renderUsers($actionParams)/ge;
  $text =~ s/\$subscribe/renderSubscribe($actionParams)/ge;
  $text =~ s/\$help/renderHelp($actionParams)/ge;
  $text =~ s/(\$sep)?\$logout/renderLogout($actionParams, $1)/ge;
  $text =~ s/\$close/renderClose($actionParams)/ge;
  $text =~ s/\$first/renderFirst($actionParams)/ge;
  $text =~ s/\$last/renderLast($actionParams)/ge;
  $text =~ s/\$next/renderNext($actionParams)/ge;
  $text =~ s/\$prev/renderPrev($actionParams)/ge;
  $text =~ s/\$diff/renderDiff($actionParams)/ge;
  $text =~ s/\$sep/$sepString/g;

  return $header . $text . $footer;
}

###############################################################################
sub renderNew {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'new'}) {
    $result = Foswiki::Func::expandTemplate('NEW_ACTION_RESTRICTED');
  } else {
    my $topicFactory = Foswiki::Func::getPreferencesValue('TOPICFACTORY') || 'topicnew';
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', 
      undef, undef, 
      'template' => $topicFactory, 
    );
    $result = Foswiki::Func::expandTemplate('NEW_ACTION');
    $result =~ s/%url%/$url/g;
  }
   
  return $result;
}

###############################################################################
sub renderEditForm {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'edit'}) {
    $result = Foswiki::Func::expandTemplate('EDITFORM_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef,
      't'=> time(),
      'action'=>'form'
    );
    $result = Foswiki::Func::expandTemplate('EDITFORM_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderEditText {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'edit'}) {
    $result = Foswiki::Func::expandTemplate('EDITTEXT_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef,
      't'=> time(),
      'action'=>'text'
    );
    $result = Foswiki::Func::expandTemplate('EDITTEXT_ACTION_RESTRICTED');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderEdit {
  my $params = shift;

  my $result = '';

  my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();

  if ($params->{isRestrictedAction}{'edit'}) {
    if ($themeEngine->{skinState}{"history"}) {
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION_RESTRICTED');
    }
  } else {
    if ($themeEngine->{skinState}{"history"}) {
      my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef, 
        't'=>time(),
        'rev'=>$params->{prevRev}
      );
      $result = Foswiki::Func::expandTemplate('RESTORE_ACTION');
      $result =~ s/%url%/$url/g;
    } else {
      my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("edit", undef, undef,
        't'=>time(),
      );
      my $whiteBoard = Foswiki::Func::getPreferencesValue('WHITEBOARD');
      my $editAction = Foswiki::Func::getPreferencesValue('EDITACTION') || '';
      if (!Foswiki::Plugins::NatSkinPlugin::Utils::isTrue($whiteBoard, 1) || $editAction eq 'form') {
        $url .= '&action=form';
      } elsif ($editAction eq 'text') {
        $url .= '&action=text';
      }
      $result = Foswiki::Func::expandTemplate('EDIT_ACTION');
      $result =~ s/%url%/$url/g;
    }
  }

  return $result;
}

###############################################################################
sub renderAttach {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'attach'}) {
    $result = Foswiki::Func::expandTemplate('ATTACH_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("attach");
    $result = Foswiki::Func::expandTemplate('ATTACH_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderMove {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'move'}) {
    $result = Foswiki::Func::expandTemplate('MOVE_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("rename", undef, undef, 
      'currentwebonly'=>'on'
    );
    $result = Foswiki::Func::expandTemplate('MOVE_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderDelete {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'delete'}) {
    $result = Foswiki::Func::expandTemplate('DELETE_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("rename", undef, undef, 
      'currentwebonly'=>'on', 'newweb'=>$Foswiki::cfg{TrashWebName});
    $result = Foswiki::Func::expandTemplate('DELETE_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderRaw {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'raw'}) {
    if ($params->{isRaw}) {
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('RAW_ACTION_RESTRICTED');
    }
  } else {
    my $themeEngine = Foswiki::Plugins::NatSkinPlugin::ThemeEngine::getThemeEngine();
    my $revParam = $themeEngine->{skinState}{"history"}?"?rev=$params->{curRev}":'';
    if ($params->{isRaw}) {
      my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("view").$revParam;
      $result = Foswiki::Func::expandTemplate('VIEW_ACTION');
      $result =~ s/%url%/$url/g;
    } else {
      my $rawParam = $themeEngine->{skinState}{"history"}?"&rev=$params->{curRev}":'';
      my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("view") .'?raw=on'.$rawParam;
      $result = Foswiki::Func::expandTemplate('RAW_ACTION');
      $result =~ s/%url%/$url/g;
    }
  }

  return $result;
}
  
###############################################################################
sub renderHistory {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'history'}) {
    $result = Foswiki::Func::expandTemplate('HISTORY_ACTION_RESTRICTED');
  } else {
    my $url = getDiffUrl();
    $result = Foswiki::Func::expandTemplate('HISTORY_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
# display url to enter topic diff/history
sub getDiffUrl {

  return Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
    "oops", undef, undef,
    'template' => (Foswiki::Func::getContext()->{"HistoryPluginEnabled"}) ? 'oopshistory' : 'oopsrev',
    'param1' => Foswiki::Plugins::NatSkinPlugin::Utils::getPrevRevision(),
    'param2' => Foswiki::Plugins::NatSkinPlugin::Utils::getCurRevision(),
    'param3' => Foswiki::Plugins::NatSkinPlugin::Utils::getMaxRevision()
  );
}

###############################################################################
sub renderMore {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'more'}) {
    $result = Foswiki::Func::expandTemplate('MORE_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("view", undef, undef,
      'template'=>'more'
    );
    $result = Foswiki::Func::expandTemplate('MORE_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderPrint {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'print'}) {
    $result = Foswiki::Func::expandTemplate('PRINT_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', undef, undef, 
      'cover'=>'print'
    );
    my $extraParams = Foswiki::Plugins::NatSkinPlugin::Utils::makeParams();
    $url .= ';'.$extraParams if $extraParams;
    $result = Foswiki::Func::expandTemplate('PRINT_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderPdf {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'pdf'}) {
    $result = Foswiki::Func::expandTemplate('PDF_ACTION_RESTRICTED');
  } else {
    my $url;
    my $context = Foswiki::Func::getContext();
    if ($context->{GenPDFPrincePluginEnabled} ||
        $context->{GenPDFWebkitPluginEnabled}) {
      $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', 
        undef, undef,
        'contenttype'=>'application/pdf',
      );
    } else {
      # SMELL: can't check for GenPDFAddOn reliably; we'd like to 
      # default to normal printing if no other print helper is installed
      $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('genpdf', 
        undef, undef,
        'cover'=>'print',
      );
    }
    my $extraParams = Foswiki::Plugins::NatSkinPlugin::Utils::makeParams();
    $url .= ';'.$extraParams if $extraParams;
    $result = Foswiki::Func::expandTemplate('PDF_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}


###############################################################################
sub renderRegister {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'register'}) {
    $result = Foswiki::Func::expandTemplate('REGISTER_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $Foswiki::cfg{SystemWebName}, 'UserRegistration');
    $result = Foswiki::Func::expandTemplate('REGISTER_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderAccount {
  my $params = shift;

  my $result = '';

  my $usersWeb = $Foswiki::cfg{UsersWebName};
  my $wikiName = Foswiki::Func::getWikiName();
  if (Foswiki::Func::topicExists($usersWeb, $wikiName)) {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("view", $usersWeb, $wikiName);
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION');
    $result =~ s/%url%/$url/g;
  } else {
    $result = Foswiki::Func::expandTemplate('ACCOUNT_ACTION_RESTRICTED');
  }

  return $result;
}

###############################################################################
sub renderUsers {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'users'}) {
    $result = Foswiki::Func::expandTemplate('USERS_ACTION_RESTRICTED');
  } else {
    $result = Foswiki::Func::expandTemplate('USERS_ACTION');
  }

  return $result;
} 

###############################################################################
sub renderSubscribe {
  my $params = shift;

  my $result = '';

  if (Foswiki::Func::getContext()->{SubscribePluginEnabled}) {
    if ($params->{isRestrictedAction}{'subscribe'}) {
      $result = Foswiki::Func::expandTemplate('SUBSCRIBE_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('SUBSCRIBE_ACTION');
    }
  }

  return $result;
}

###############################################################################
sub renderHelp {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'help'}) {
    $result = Foswiki::Func::expandTemplate('HELP_ACTION_RESTRICTED');
  } else {
    my $systemWeb = $Foswiki::cfg{SystemWebName};
    my $helpTopic = $params->{help} || "UsersGuide";
    my $helpWeb;
    ($helpWeb, $helpTopic) = Foswiki::Func::normalizeWebTopicName($systemWeb, $helpTopic);
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath('view', $helpWeb, $helpTopic);
    $result = Foswiki::Func::expandTemplate('HELP_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderFirst {
  my $params = shift;

  my $result = '';
  if ($params->{isRestrictedAction}{'first'} || $params->{curRev} == 1+$params->{nrRev}) {
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION_RESTRICTION');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath($params->{diffCommand}, undef, undef,
      'rev1'=>(1+$params->{nrRev}),
      'rev2'=>1,
      'render'=>$params->{renderMode},
      'context'=>2
    );
    $result = Foswiki::Func::expandTemplate('FIRST_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderLogin {
  my $params = shift;

  my $result = '';

  my $loginUrl = getLoginUrl();
  if ($loginUrl) {
    if ($params->{isRestrictedAction}{'login'}) {
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('LOG_IN_ACTION');
      $result =~ s/%url%/$loginUrl/g;
    }
  }

  return $result;
}

###############################################################################
sub renderLogout {
  my ($params, $sep) = @_;

  my $result = '';
  $sep ||= '';

  my $logoutUrl = getLogoutUrl();
  if ($logoutUrl) {
    if ($params->{isRestrictedAction}{'logout'}) {
      $result = Foswiki::Func::expandTemplate('LOG_OUT_ACTION_RESTRICTED');
    } else {
      $result = Foswiki::Func::expandTemplate('LOG_OUT_ACTION');
      $result =~ s/%url%/$logoutUrl/g;
    }
    $result = $sep.$result;
  }

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
sub renderClose {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'close'}) {
    $result = Foswiki::Func::expandTemplate('CLOSE_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath("view");
    $result = Foswiki::Func::expandTemplate('CLOSE_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}


###############################################################################
sub renderLast {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'last'} || $params->{curRev} == $params->{maxRev}) {
    $result = Foswiki::Func::expandTemplate('LAST_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{diffCommand}, undef, undef,
      'rev1' => $params->{maxRev},
      'rev2' => ($params->{maxRev} - $params->{nrRev}),
      'render' => $params->{renderMode},
      'context'=>2
    );
    $result = Foswiki::Func::expandTemplate('LAST_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderNext {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'next'} || $params->{nextRev} > $params->{maxRev}) {
    $result = Foswiki::Func::expandTemplate('NEXT_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{diffCommand}, undef, undef,
      'rev1' => $params->{nextRev},
      'rev2' => $params->{curRev},
      'render' => $params->{renderMode},
      'context'=>2
    );
    $result = Foswiki::Func::expandTemplate('NEXT_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderPrev {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'prev'} || $params->{prevRev} <= 1) {
    $result = Foswiki::Func::expandTemplate('PREV_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{diffCommand}, undef, undef,
      'rev1' => $params->{prevRev},
      'rev2' => ($params->{prevRev} - $params->{nrRev}),
      'render' => $params->{renderMode},
      'context'=>2
    );
    $result = Foswiki::Func::expandTemplate('PREV_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}

###############################################################################
sub renderDiff {
  my $params = shift;

  my $result = '';

  if ($params->{isRestrictedAction}{'diff'} || $params->{prevRev} < 1) {
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION_RESTRICTED');
  } else {
    my $url = Foswiki::Plugins::NatSkinPlugin::Utils::getScriptUrlPath(
      $params->{diffCommand}, undef, undef,
      'rev1' => $params->{curRev},
      'rev2' => $params->{prevRev},
      'render' => $params->{renderMode},
      'context'=>2
    );
    $result = Foswiki::Func::expandTemplate('DIFF_ACTION');
    $result =~ s/%url%/$url/g;
  }

  return $result;
}



1;
