Module: %wiki
Synopsis: Utilities, globals, protocols, base classes, ...
          Basically anything that needs to be defined first.


define taglib wiki () end;

// Represents a DSP maintained in our source code tree. Not to be confused
// with <wiki-page>, which is a user-editable wiki page.
//
define class <wiki-dsp> (<dylan-server-page>)
end;

// These are both set to something else when the config file is loaded.
define variable *static-directory* :: <directory-locator> = working-directory();
define variable *template-directory* :: <directory-locator> = working-directory();


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
define variable *page-history-page* = #f;
define variable *connections-page* = #f;
define variable *view-diff-page* = #f;
define variable *search-page* = #f;
define variable *non-existing-page-page* = #f;

define variable *view-user-page* = #f;
define variable *list-users-page* = #f;
define variable *edit-user-page* = #f;
define variable *deactivate-user-page* = #f;
define variable *non-existing-user-page* = #f;

define variable *list-groups-page* = #f;
define variable *non-existing-group-page* = #f;
define variable *view-group-page* = #f;
define variable *edit-group-page* = #f;
define variable *remove-group-page* = #f;
define variable *edit-group-members-page* = #f;

define variable *registration-page* = #f;
define variable *edit-access-page* = #f;



//// Wiki object caches

/// All objects stored in the wiki (pages, users, groups) must subclass this.
///
define class <wiki-object> (<object>)
  constant slot creation-date :: <date> = current-date(),
    init-keyword: creation-date:;

  // TODO:
  //constant slot modification-date :: <date> = <same as creation-date>;

  slot object-name :: <string>,
    required-init-keyword: name:;
end;


// If you need to hold more than one of these locks, acquire them in
// this order: $group-lock, $user-lock, $page-lock.

/// Maps user name to newest revision of <wiki-user>.
define variable *users* :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);

/// Hold this when modifying *users*.
define constant $user-lock :: <lock> = make(<lock>);


/// Maps group name to newest revision of <wiki-group>.
define variable *groups* :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);

/// Hold this when modifying *groups*.
define constant $group-lock :: <lock> = make(<lock>);


/// Maps page titles to newest revision of <wiki-page>.
define variable *pages* :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);

/// Hold this when modifying *pages*.
define constant $page-lock :: <lock> = make(<lock>);



//// General-use DSP tags

// Prefix for all wiki URLs.  Set to "" for no prefix.
// Note that some templates still hard-code this value,
// until URL generation works.
define variable *wiki-url-prefix* :: <string> = "/wiki";

// This shouldn't be needed once generate-url is working.
define tag base in wiki
    (page :: <wiki-dsp>) ()
  output("%s", *wiki-url-prefix*);
end;

define tag base-url in wiki
    (page :: <wiki-dsp>)
    ()
  let url = current-request().request-absolute-url; // this may make a new url
  output("%s", build-uri(make(<url>,
                              scheme: url.uri-scheme,
                              host: url.uri-host,
                              port: url.uri-port)));
end;

// Mostly for use in setting the "redirect" parameter in templates.
define tag current in wiki
    (page :: <wiki-dsp>) ()
  output("%s", build-uri(request-url(current-request())));
end;

define function wiki-url
    (format-string, #rest format-args)
 => (url :: <url>)
  parse-url(concatenate(*wiki-url-prefix*,
                        apply(format-to-string, format-string, format-args)))
end;  

define constant $past-tense-table
  = make-table(<string-table>,
               "activate" => "activated",
               "create"   => "created",
               "edit"     => "edited",
               "remove"   => "removed",
               "rename"   => "renamed",
               "add-members"    => "group member added",
               "remove-members" => "group member removed",

               // I don't think these two are currently used.  --cgay Apr 2011
               "add-group-owner"    => "added owner",
               "remove-group-owner" => "removed owner");

define generic permanent-link (obj :: <object>) => (url :: <url>);



//// Storage protocol

/// Any back-end storage mechanism must be a subclass of this and support
/// the generics that specialize on it.
define class <storage> (<object>)
end;

/// This is initialized when the config file is loaded.
define variable *storage* :: false-or(<storage>) = #f;


/// Initialize storage upon startup
define generic initialize-storage-for-reads
    (storage :: <storage>) => ();

define generic initialize-storage-for-writes
    (storage :: <storage>, admin-user :: <wiki-user>) => ();


define generic load
    (storage :: <storage>, class :: subclass(<wiki-object>), name :: <string>,
     #key)
 => (obj :: <wiki-object>);

define generic load-all
    (storage :: <storage>, class :: subclass(<wiki-object>))
 => (objects :: <sequence>);

define generic find-or-load-pages-with-tags
    (storage :: <storage>, tags :: <sequence>) => (pages :: <sequence>);

// If 'type' ~= <wiki-object>, the 'name' keyword argument is supported.
// If 'type' == <wiki-page>, the 'diff?' keyword argument is supported.
define generic find-changes
    (storage :: <storage>, type :: subclass(<wiki-object>), #key start, count, #all-keys)
 => (changes :: <sequence>);

define generic store
    (storage :: <storage>, obj :: <wiki-object>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>);

define generic delete
    (storage :: <storage>, obj :: <wiki-object>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => ();

define generic rename
    (storage :: <storage>, obj :: <wiki-object>, new-name :: <string>,
     author :: <wiki-user>, comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>);

/// This is what the above methods should signal if they can't fullfill
/// their contract.
define class <storage-error> (<format-string-condition>, <serious-condition>)
end;



//// Changes

define class <wiki-change> (<object>)
  constant slot change-revision    :: <string>, required-init-keyword: revision:;
  constant slot change-author      :: <string>, required-init-keyword: author:;
  constant slot change-date        :: <date>,   required-init-keyword: date:;
  constant slot change-comment     :: <string>, required-init-keyword: comment:;
  constant slot change-diff        :: <string> = "", init-keyword: diff:;

  // Keys that always exist: "name", "type", "action".
  // TODO: Be resilient to by-hand edits, in which case these items may not have
  //       been stored in the Notes for the commit.  This info could be recovered
  //       by grovelling over the output of "git whatchanged".
  constant slot change-meta-data   :: <string-table>, required-init-keyword: meta-data:;
end;

define function change-object-name
    (change :: <wiki-change>) => (name :: <string>)
  change.change-meta-data["name"]
end;

define function change-type-name
    (change :: <wiki-change>) => (name :: <string>)
  change.change-meta-data["type"]
end;

/* unused
define function change-object-type
    (change :: <wiki-change>) => (type :: subclass(<wiki-object>))
  select (change.change-type-name by \=)
    "page" => <wiki-page>;
    "user" => <wiki-user>;
    "group" => <wiki-group>;
  end
end;
*/

define function change-action
    (change :: <wiki-change>) => (action :: <string>)
  element(change.change-meta-data, "action", default: "change")
end;

define function standard-meta-data
    (object :: <wiki-object>, action :: <string>)
 => (meta-data :: <string-table>)
  let meta-data = make(<string-table>);
  meta-data["action"] := action;
  meta-data["name"] := select (object.object-class)
                         <wiki-page> => object.page-title;
                         <wiki-user> => object.user-name;
                         <wiki-group> => object.group-name;
                       end;
  meta-data["type"] := select (object.object-class)
                         <wiki-page> => "page";
                         <wiki-user> => "user";
                         <wiki-group> => "group";
                       end;
  meta-data
end;

define method permanent-link
    (change :: <wiki-change>) => (url :: <url>)
  // Yet another place that needs to be fixed by using generate-url.
  let location = wiki-url("/%s/view/%s/%s",
                          change.change-type-name,
                          change.change-object-name,
                          change.change-revision);
  transform-uris(request-url(current-request()), location, as: <url>)
end;



//// Recent Changes page

define class <recent-changes-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <recent-changes-page>, #key)
  let changes = sort(find-recent-changes(),
                     test: method (change1, change2)
                             change1.change-date > change2.change-date   
                           end);
  let page-number = get-query-value("page", as: <integer>) | 1;
  let paginator = make(<paginator>,
                       sequence: changes,
                       current-page-number: page-number);
  set-attribute(page-context(), "recent-changes", paginator);
  next-method();
end;

/// Synopsis: Find changes for wiki objects of type 'for-type'.
///
/// Arguments:
///   for-type  - Should be <wiki-page>, <wiki-user>, or <wiki-group>
///               or <wiki-object> (the default).  <wiki-object> will
///               find changes for any object.
///   start     - A revision number at which to start searching (backward)
///               for changes.  With the git back-end this is a hash.
///               The default (#f) means to start with the most recent change.
///   name      - Only find changes for objects matching this name exactly.
///               For pages this matches the title.  The default (#f) matches
///               anything.
/// Values:
///   changes - a sequence of <wiki-change> objects representing object
///             creations, edits, deletions, or renames.
///
define method find-recent-changes
    (#key for-type :: subclass(<wiki-object>) = <wiki-object>,
          start :: false-or(<string>),
          name :: false-or(<string>))
 => (changes :: <sequence>)
  find-changes(*storage*, for-type, start: start, name: name, count: 300)
end;

define body tag list-recent-changes in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  let pc = page-context();
  let previous-change = #f;
  let paginator :: <paginator> = get-attribute(pc, "recent-changes");
  for (change :: <wiki-change> in paginator)
    set-attribute(pc, "day", standard-date(change.change-date));
    set-attribute(pc, "previous-day",
                  previous-change & standard-date(previous-change.change-date));
    set-attribute(pc, "time", standard-time(change.change-date));
    set-attribute(pc, "revision-url", as(<string>, permanent-link(change)));
    set-attribute(pc, "newest-url", as(<string>, permanent-link(change)));
    set-attribute(pc, "diff-url",
                  as(<string>, wiki-url("/page/diff/%s/%s",
                                        change.change-object-name,
                                        change.change-revision)));
    set-attribute(pc, "object-type", change.change-type-name);
    set-attribute(pc, "title", change.change-object-name);
    set-attribute(pc, "action", as(<string>, change.change-action));
    set-attribute(pc, "comment", change.change-comment);
    set-attribute(pc, "version", change.change-revision);
    set-attribute(pc, "verb", 
                  element($past-tense-table, change.change-action, default: #f)
                  | change.change-action);
    set-attribute(pc, "author", change.change-author);
    do-body();
    previous-change := change;
  end;
end tag list-recent-changes;



// TODO: replace all these date-related tags with one tag like
//       <wiki:date object="page|group|user" format="..." />

// Standard date format.  The plan is to make this customizable per user
// and to use the user's timezone.  For now just ISO 8601...
//
define method standard-date-and-time
    (date :: <date>) => (date-and-time :: <string>)
  as-iso8601-string(date)
end;

define method standard-date
    (date :: <date>) => (date :: <string>)
  format-date("%Y.%m.%d", date)
end;

define method standard-time
    (date :: <date>) => (time :: <string>)
  format-date("%H:%M", date)
end;

define tag show-version-published in wiki
    (page :: <wiki-dsp>)
    (formatted :: <string>)
  output("%s", format-date(formatted, *page*.creation-date));
end;

define tag show-page-published in wiki
    (page :: <wiki-dsp>)
    (formatted :: <string>)
  if (*page*)
    output("%s", format-date(formatted, *page*.creation-date));
  end if;
end;

define tag page-creation-date in wiki
    (page :: <wiki-dsp>)
    ()
  output("%s", as-iso8601-string(*page*.creation-date));
end; 

// Rename to show-comment
define tag show-version-comment in wiki
    (page :: <wiki-dsp>)
    ()
  output("%s", *page*.page-comment);
end;


define variable *not-logged-in-page* = #f;



//// References (to other wiki objects)


/// A wiki reference is a pointer to another wiki object.
define class <wiki-reference> (<object>)

  /// This holds the name of the page, user, or group.
  constant slot reference-name :: <string>,
    required-init-keyword: name:;

  // The text to display for this reference.  Often the same as the name.
  constant slot reference-text :: <string>,
    required-init-keyword: text:;

end class <wiki-reference>;


/// Map from page name to a sequence of <wiki-object>s that refer to it.
/// The keys here may be for non-existant objects.  e.g. pages that
/// haven't yet been created, or that have been deleted.
define constant $page-reference-map :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);

/// Map from user name to a sequence of <wiki-object>s that refer to it.
/// The keys here may be for non-existant objects.  e.g. users that
/// haven't yet been created, or that have been deleted.
define constant $user-reference-map :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);

/// Map from group name to a sequence of <wiki-object>s that refer to it.
/// The keys here may be for non-existant objects.  e.g. groups that
/// haven't yet been created, or that have been deleted.
define constant $group-reference-map :: <case-insensitive-string-table>
  = make(<case-insensitive-string-table>);


define generic as-rst
    (x :: <object>) => (rst :: <string>);

define generic resolve-reference
    (ref :: <wiki-reference>) => (object :: false-or(<wiki-object>));

       
define class <page-reference> (<wiki-reference>) end;
define class <user-reference> (<wiki-reference>) end;
define class <group-reference> (<wiki-reference>) end;


define method as-rst
    (rst-markup :: <string>) => (rst :: <string>)
  rst-markup
end;

define method as-rst
    (ref :: <page-reference>) => (rst :: <string>)
  format-to-string("`%s %s<%s/page/view/%s>`_",
                   ref.reference-text,
                   iff(ref.resolve-reference, "", "(?) "),
                   *wiki-url-prefix*,
                   percent-encode($uri-pchar, ref.reference-name))
end;

define method as-rst
    (ref :: <user-reference>) => (rst :: <string>)
  format-to-string("`%s %s<%s/user/view/%s>`_",
                   ref.reference-text,
                   iff(ref.resolve-reference, "", "(?) "),
                   *wiki-url-prefix*,
                   percent-encode($uri-pchar, ref.reference-name))
end;

define method as-rst
    (ref :: <group-reference>) => (rst :: <string>)
  format-to-string("`%s %s<%s/group/view/%s>`_",
                   ref.reference-text,
                   iff(ref.resolve-reference, "", "(?) "),
                   *wiki-url-prefix*,
                   percent-encode($uri-pchar, ref.reference-name))
end;


define method resolve-reference
    (ref :: <page-reference>) => (page :: false-or(<wiki-page>))
  find-page(ref.reference-name)
end;

define method resolve-reference
    (ref :: <user-reference>) => (user :: false-or(<wiki-user>))
  find-user(ref.reference-name)
end;

define method resolve-reference
    (ref :: <group-reference>) => (group :: false-or(<wiki-group>))
  find-group(ref.reference-name)
end;


define constant $reference-map-lock :: <lock> = make(<lock>);

/// Update reference tables to reflect changes when an object is created,
/// modified, or deleted.
/// Arguments:
///   source - The source of the references.
///   old-refs - Sequence of <wiki-reference> from before the object was changed.
///   new-refs - Sequence of <wiki-reference> from after the object was changed.
define function update-reference-tables!
    (source :: <wiki-object>, old-refs :: <sequence>, new-refs :: <sequence>)
 => ()
  local method same? (object1 :: <wiki-object>, object2 :: <wiki-object>)
          case-insensitive-equal(object1.object-name, object2.object-name)
        end;
  let table = select (source by instance?)
                <wiki-page> => $page-reference-map;
                <wiki-user> => $user-reference-map;
                <wiki-group> => $group-reference-map;
              end;
  with-lock ($reference-map-lock)
    for (ref in old-refs)
      let target-name = ref.reference-name;
      let refs = element(table, target-name, default: #f);
      if (refs)
        table[target-name] := remove!(refs, source, test: same?);
      end;
    end;
    for (ref in new-refs)
      let target-name = ref.reference-name;
      let refs = element(table, target-name, default: #());
      table[target-name] := add!(refs, source);
    end;
  end;
end function update-reference-tables!;


/// Find references to the given wiki object.  Currently this cannot handle
/// references to specific revisions of objects; all references are assumed
/// to be to the latest revision.
/// Arguments:
///     target - The object being referred to.
/// Values:
///     wiki-objects - A sequence of <wiki-objects>s.
define generic inbound-references
    (target :: <wiki-object>) => (wiki-objects :: <sequence>);

define method inbound-references
    (target :: <wiki-page>) => (wiki-objects :: <sequence>)
  element($page-reference-map, target.object-name, default: #())
end;

define method inbound-references
    (target :: <wiki-user>) => (wiki-objects :: <sequence>)
  element($user-reference-map, target.object-name, default: #())
end;

define method inbound-references
    (target :: <wiki-group>) => (wiki-objects :: <sequence>)
  element($group-reference-map, target.object-name, default: #())
end;


/// Return a sequence of <wiki-object>s that are referred to by 'source'.
define generic outbound-references
    (source :: <wiki-object>) => (refs :: <sequence>);

define method outbound-references
    (source :: <wiki-object>) => (refs :: <sequence>)
  #()  // nothing yet
end;

define method outbound-references
    (page :: <wiki-page>) => (refs :: <sequence>)
  choose(rcurry(instance?, <wiki-reference>),
         page.page-parsed-source)
end method outbound-references;

