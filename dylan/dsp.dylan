Module: wiki-internal

define taglib wiki () end;

// Represents a DSP maintained in our source code tree. Not to be confused
// with <wiki-page>, which is a user-editable wiki page stored in the database
// by web-framework.
//
define class <wiki-dsp> (<dylan-server-page>)
end;

// These two variables should reflect the layout of the subdirectories
// in trunk/libraries/network/wiki/.  *static-directory* should point to
// the www subdir, and *template-directory* should point to www/dsp.  The
// default values are setup to work if you cd to .../wiki/www and run the
// wiki executable.

define variable *static-directory* :: <directory-locator>
  = working-directory();

define variable *template-directory* :: <directory-locator>
  = subdirectory-locator(*static-directory*, "dsp");

define method make
    (class :: subclass(<wiki-dsp>), #rest args, #key source :: <pathname>)
 => (page :: <wiki-dsp>)
  apply(next-method, class,
        source: merge-locators(as(<file-locator>, source),
                               *template-directory*),
        args)
end;

// The following will all be set after *template-directory* is set.

define variable *edit-page-page* = #f;
define variable *view-page-page* = #f;
define variable *remove-page-page* = #f;
define variable *page-versions-page* = #f;
define variable *connections-page* = #f;
define variable *view-diff-page* = #f;
define variable *search-page* = #f;
define variable *page-authors-page* = #f;
define variable *non-existing-page-page* = #f;

define variable *view-user-page* = #f;
define variable *list-users-page* = #f;
define variable *edit-user-page* = #f;
define variable *remove-user-page* = #f;
define variable *non-existing-user-page* = #f;

define variable *list-groups-page* = #f;
define variable *non-existing-group-page* = #f;
define variable *view-group-page* = #f;
define variable *edit-group-page* = #f;
define variable *remove-group-page* = #f;
define variable *edit-group-members-page* = #f;

define variable *registration-page* = #f;
define variable *edit-access-page* = #f;

