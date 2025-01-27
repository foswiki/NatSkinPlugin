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

package Foswiki::Plugins::NatSkinPlugin::MessageBox;

=begin TML

---+ package Foswiki::Plugins::NatSkinPlugin::MessageBox

service class to render the MESSAGEBOX macro

=cut

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins::MultiLingualPlugin();

use Foswiki::Plugins::NatSkinPlugin::BaseModule ();
our @ISA = ('Foswiki::Plugins::NatSkinPlugin::BaseModule');

=begin TML

---++ render( $params, $topic, $web, $topicObject) -> $html

implements the %MESSAGEBOX macro

=cut

sub render {
  my ($this, $params, $topic, $web, $topicObject) = @_;

  my $type = $params->{type} // 'message';

  my @classes = ();
  my $class = $params->{class} // '';
  push @classes, $class if defined $class && $class ne "";

  push @classes, "foswiki".ucfirst($type)."Message" if $type =~ /^(success|error|info|warning|tip)$/;
  push @classes, "foswikiHelp" if $type eq "help";
  push @classes, "foswikiMessage" if $type eq "message";
  push @classes, "foswikiAlt" if $type eq "alt";

  my $showIcon = Foswiki::Func::isTrue($params->{showicon}, 1);
  push @classes, "foswikiNoIcon" unless $showIcon;

  my $doSticky = Foswiki::Func::isTrue($params->{sticky}, 0);
  push @classes, "foswikiSticky" if $doSticky;

  $class = join(" ", @classes);

  my $doTranslate = Foswiki::Func::isTrue($params->{translate}, 0);
  my $text = $params->{_DEFAULT} // $params->{text} // "";
  $text = Foswiki::Plugins::MultiLingualPlugin::translate($text, $web, $topic) if $doTranslate;

  my $result = "<div class='$class'> $text </div>";

  return Foswiki::Func::decodeFormatTokens($result);;
}

1;
