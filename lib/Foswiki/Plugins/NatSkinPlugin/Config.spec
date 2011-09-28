# ---+ Extensions
# ---++ NatSkin

# ---+++ Default theme settings
# **STRING**
# This is the default style used for this site. Note, that theming and layout can be configured using preference settings
# per web, topic and user thus overriding settings specified here.
$Foswiki::cfg{NatSkin}{Style} = 'jazzynote';

# **STRING**
# Choose a default style variation. Note, that only variations shipped within the same theme package can be used,
# that is you can't combine a {Style} from theme A with {Variation} from theme B.
$Foswiki::cfg{NatSkin}{Variation} = 'off';

# **STRING**
# Comma separated list of NatSkin themes installed on your system. This is the path along which themes and styles are 
# searched for.
$Foswiki::cfg{NatSkin}{ThemePath} = '';

# **SELECT fixed,fluid,bordered **
# Choose from a set of basic page layouts. 'fluid' is a good choice for sites mostly displayed on small display devices
# and wide content, like large tables. 'fixed' is a typical center aligned blog-like layout that limits
# the text width to a readable size while the content area will still resize proportional to the font width. 
# 'Bordered' is very similar to the fluid width layout but adds extra white space around the content.
$Foswiki::cfg{NatSkin}{Layout} = 'fixed';

# **BOOLEAN**
# Use this flag to switch on/off the horizontal navigation menu.
$Foswiki::cfg{NatSkin}{Menu} = 1;

# **SELECT left,right,both,none**
# This setting configures different vertical layout variations where sidebars either appear left, right or on both sides
# of the main content area. 'None' switches off any skin-driven sidebars. This is useful when columns are designed inside
# the content area directly instead of being controlled by the template engine.
$Foswiki::cfg{NatSkin}{SideBar} = 'left';

# **STRING EXPERT**
# This is a list of actions that switch off the sidebar navigation automatically. Note, these are basically known cgi entry
# points to Foswiki.
$Foswiki::cfg{NatSkin}{NoSideBarActions} = 'edit, manage, login, logon, oops';

# ---+++ HTML post processing
# **BOOLEAN**
# If switched on, all html comments and any content appearing after the closing &lt;/html> tag will be removed.
$Foswiki::cfg{NatSkin}{CleanUpHTML} = 1;

# **BOOLEAN**
# If switched on, external links will be detected and styled accordingly to give the user visual feedback that this
# link is driving him off the site.
$Foswiki::cfg{NatSkin}{DetectExternalLinks} = 0;

1;

