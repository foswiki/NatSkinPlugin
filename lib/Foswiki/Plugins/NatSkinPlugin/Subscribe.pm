###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
#
# Copyright (C) 2013-2019 MichaelDaum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatSkinPlugin::Subscribe;
use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Contrib::MailerContrib ();
use Error qw (:try);

sub render {
  my ($session, $params, $theTopic, $theWeb) = @_;

  Foswiki::Func::addToZone('skinjs', 'NATSKIN::SUBSCRIBE', <<'HERE', 'NATSKIN::JS, JQUERYPLUGIN::BLOCKUI');
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/subscribe.js"></script>
HERE

  my $webTopic = $params->{topic} || $theTopic;
  my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $webTopic);
  my $who = $params->{_DEFAULT} || $params->{who} || Foswiki::Func::getWikiName();

  my $then = $params->{then};
  $then = "1" unless defined $then;

  my $else = $params->{else};
  $else = "0" unless defined $else;

  return Foswiki::Contrib::MailerContrib::isSubscribedTo($web, $who, $topic) ? $then : $else;
}

sub restSubscribe {
  my ($session, $plugin, $verb, $response) = @_;

  my $request = Foswiki::Func::getRequestObject();

  my $web = $session->{webName};
  my $topic = $session->{topicName};

  throw Error::Simple("topic does not exist")
    unless Foswiki::Func::topicExists($web, $topic);

  my $user = Foswiki::Func::getWikiName();

  throw Error::Simple("bad subscriber")
    if $user eq $Foswiki::cfg{DefaultUserWikiName};

  my $sub = $request->param("subscription") || $topic;

  if ($verb eq 'subscribe') {
    Foswiki::Contrib::MailerContrib::changeSubscription($web, $user, $sub);
  } else {
    Foswiki::Contrib::MailerContrib::changeSubscription($web, $user, $sub, "-");
  }
}

1;
