# ---+ Extensions
# ---++ NatSkin

# ---+++ Default theme settings
# **STRING**
# This is the default style used for this site. Note, that theming and layout can be configured using preference settings
# per web, topic and user thus overriding settings specified here.
$Foswiki::cfg{NatSkin}{Style} = 'matter';

# **STRING**
# Choose a default style variation. Note, that only variations shipped within the same theme package can be used,
# that is you can't combine a {Style} from theme A with {Variation} from theme B.
$Foswiki::cfg{NatSkin}{Variation} = 'off';

# **SELECT fixed,fluid,bordered,fullscreen **
# Choose from a set of basic page layouts. 'fluid' is a good choice for sites mostly displayed on small display devices
# and wide content, like large tables. 'fixed' is a typical center aligned blog-like layout that limits
# the text width to a readable size while the content area will still resize proportional to the font width. 
# 'Bordered' is very similar to the fluid width layout but adds extra white space around the content.
# 'Fullscreen' is a reduced page layout giving the content maximum space.
$Foswiki::cfg{NatSkin}{Layout} = 'fixed';

# **BOOLEAN**
# Use this flag to switch on/off the horizontal navigation menu.
$Foswiki::cfg{NatSkin}{Menu} = 1;

# **SELECT left,right,both,off**
# This setting configures different vertical layout variations where sidebars either appear left, right or on both sides
# of the main content area. 'off' switches off any skin-driven sidebars. This is useful when columns are designed inside
# the content area directly instead of being controlled by the template engine.
$Foswiki::cfg{NatSkin}{SideBar} = 'right';

# **BOOLEAN**
# Switch to enable the dark mode feature. Note this is still work in progress.
$Foswiki::cfg{NatSkin}{DarkModeFeature} = 0;

# **STRING**
# This is a list of actions that switch off the sidebar navigation automatically. Note, these are basically known cgi entry
# points to Foswiki.
$Foswiki::cfg{NatSkin}{NoSideBarActions} = 'edit, manage, login, logon, oops, register, compare, rdiff, diff, attach';

# **SELECT on,guest,off**
# This setting enables a cookie warning required by european law. On intranets you most probably can disable it.
# Note that this value can override be overwritten using the NATSKIN_COOKIEINFO preference flag. Setting it to "guest"
# will dislay a cookie warning for unauthenticated visitors only.
$Foswiki::cfg{NatSkin}{DisplayCookieInfo} = 'guest';

# ---+++ HTML post processing
# **BOOLEAN**
# If switched on, external links will be detected and styled accordingly to give the user visual feedback that this
# link is driving him off the site. This is a prerequisite to open external links in an extra borwser window/tab.
$Foswiki::cfg{NatSkin}{DetectExternalLinks} = 1;

# **BOOLEAN**
# Enable this switch to perform some basic typographic fixes to the output text: support proper quotes, arrows and 
# ellipsis.
$Foswiki::cfg{NatSkin}{FixTypograpghy} = 1;

1;
