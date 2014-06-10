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

# **SELECT left,right,both,off**
# This setting configures different vertical layout variations where sidebars either appear left, right or on both sides
# of the main content area. 'off' switches off any skin-driven sidebars. This is useful when columns are designed inside
# the content area directly instead of being controlled by the template engine.
$Foswiki::cfg{NatSkin}{SideBar} = 'right';

# **STRING**
# This is a list of actions that switch off the sidebar navigation automatically. Note, these are basically known cgi entry
# points to Foswiki.
$Foswiki::cfg{NatSkin}{NoSideBarActions} = 'edit, manage, login, logon, oops, register';

# ---+++ HTML post processing
# **BOOLEAN**
# If switched on, external links will be detected and styled accordingly to give the user visual feedback that this
# link is driving him off the site. This is a prerequisite to open external links in an extra borwser window/tab.
$Foswiki::cfg{NatSkin}{DetectExternalLinks} = 0;

# **BOOLEAN**
# Enable this switch to perform some basic typographic fixes to the output text: support proper quotes, arrows and 
# ellipsis.
$Foswiki::cfg{NatSkin}{FixTypograpghy} = 0;

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

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE10 has been detected. 
$Foswiki::cfg{NatSkin}{DeprecateIE10} = 0;

# **BOOLEAN**
# Enable this switch to display a browser warning when an IE11 has been detected. 
$Foswiki::cfg{NatSkin}{DeprecateIE11} = 0;

# ---+++ HTTP Security Headers
# Enable security headers for secure web applications. See also http://perltricks.com/article/81/2014/3/31/Perl-web-application-security-HTTP-headers
# **BOOLEAN**
# Set the X-Frame-Options header to "DENY":
# This header can prevent your application responses from being loaded within
# frame or iframe HTML elements. This is to prevent clickjacking
# requests where your application response is displayed on another website,
# within an invisible iframe, which then hijacks the user's request when they
# click a link on your website.
$Foswiki::cfg{NatSkin}{DenyFrameOptions} = 1;

# **STRING**
# Require all resources to be loaded via SSL.
# This header instructs the requester to load all content from the domain via
# HTTPS and not load any content unless there is a valid ssl certificate. This
# header can help prevent man-in-middle attacks as it ensures that all HTTP
# requests and responses are encrypted. The Strict-Transport-Security header has
# a max-age parameter that defines how long in seconds to enforce the policy for. 
$Foswiki::cfg{NatSkin}{StrictTransportSecurity} = "max-age=3600";

# **STRING EXPERT**
# Set the content security policy.
# The CSP header sets a whitelist of domains from which content can be safely
# loaded. This prevents most types of XSS attack, assuming the malicious content
# is not hosted by a whitelisted domain. For example this specifies that all
# content should only be loaded from the responding domain: "default-src 'self'"
# WARNING: Enabling this setting will currently render your Foswiki non-operational 
# as it relys on unsafe inline css and js.
$Foswiki::cfg{NatSkin}{ContentSecurityPolicy} = ""; 

# **STRING**
# IE-only header to disable mime sniffing.
# This is an IE only header that is used to disable mime sniffing. The
# vulnerability is that IE will auto-execute any script code contained in a file
# when IE attempts to detect the file type.
$Foswiki::cfg{NatSkin}{ContentTypeOptions} = "nosniff"; 


# **STRING**
# IE-only header that prevents it from opening an HTML file directly on download.
# This is another IE-only header that prevents IE from opening an HTML file
# directly on download from a website. The security issue here is, if a browser
# opens the file directly, it can run as if it were part of the site.
$Foswiki::cfg{NatSkin}{DownloadOptions} = "noopen"; 

# **STRING**
# IE-only header to force it to turn on its XSS filter (IE >= 8)
# This header was introduced in IE8 as part of the
# cross-site-scripting (XSS) filter functionality (more here). Additionally it
# has an optional setting called "mode" that can force IE to block the entire
# page if an XSS attempt is detected.
$Foswiki::cfg{NatSkin}{XSSProtection} = "1; mode=block"; 

1;
