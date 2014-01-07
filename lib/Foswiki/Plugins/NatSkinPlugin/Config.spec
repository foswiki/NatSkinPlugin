# ---+ Extensions
# ---++ NatSkin

# ---+++ Default theme settings
# **STRING**
# This is the default style used for this site. Note, that theming and layout can be configured using preference settings
# per web, topic and user thus overriding settings specified here.
$Foswiki::cfg{NatSkin}{Style} = 'customato';

# **STRING**
# Choose a default style variation. Note, that only variations shipped within the same theme package can be used,
# that is you can't combine a {Style} from theme A with {Variation} from theme B.
$Foswiki::cfg{NatSkin}{Variation} = 'off';

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

# **STRING**
# This is a list of actions that switch off the sidebar navigation automatically. Note, these are basically known cgi entry
# points to Foswiki.
$Foswiki::cfg{NatSkin}{NoSideBarActions} = 'edit, manage, login, logon, oops, register';

# ---+++ HTML post processing
# **BOOLEAN**
# If switched on, external links will be detected and styled accordingly to give the user visual feedback that this
# link is driving him off the site.
$Foswiki::cfg{NatSkin}{DetectExternalLinks} = 0;

# ---+++ Internet Explorer
# **STRING**
# Add an X-UA-Compatible entry to the HTTP headers. Use "ie=edge" to force any IE into the best mode supported. Add "chrome=1"
# to switch IE using Chrome-Frame if installed.
$Foswiki::cfg{NatSkin}{XuaCompatible} = 'ie=edge,chrome=1';

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE6 has been detected.
$Foswiki::cfg{NatSkin}{DeprecateIE6} = 1;

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE7 has been detected. WARNING: an IE8 in compatibility mode will report
# as an IE7 even though it has been forced back into IE8 standard mode using an appropriate X-UA-Compatible HTTP header.
$Foswiki::cfg{NatSkin}{DeprecateIE7} = 1;

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE8 has been detected. 
$Foswiki::cfg{NatSkin}{DeprecateIE8} = 1;

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE9 has been detected. 
$Foswiki::cfg{NatSkin}{DeprecateIE9} = 0;

1;

