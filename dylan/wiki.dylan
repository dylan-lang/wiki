Module: wiki-internal

define constant $wiki-version :: <string> = "2009.06.27"; // YYYY.mm.dd

// Prefix for all wiki URLs.  Set to "" for no prefix.
define constant $wiki-url-prefix :: <string> = "";

define function wiki-url
    (format-string, #rest format-args)
 => (url :: <url>)
  parse-url(concatenate($wiki-url-prefix,
                        apply(format-to-string, format-string, format-args)))
end;  

define constant $activate = #"activate";
define constant $create = #"create";
define constant $edit   = #"edit";
define constant $remove = #"remove";
define constant $rename = #"rename";
define constant $remove-group-owner = #"remove-group-owner";
define constant $remove-group-member = #"remove-group-member";

define table $past-tense-table = {
    $activate => "activated",
    $create => "created",
    $edit   => "edited",
    $remove => "removed",
    $rename => "renamed",
    $remove-group-owner => "removed as group owner",
    $remove-group-member => "removed as group member"
  };

define wf/error-test (exists) in wiki end;

define class <wiki-page-version> (<entry>)
  slot version-number :: <integer>,
    init-keyword: version:;
  slot version-page :: <wiki-page>,
    init-keyword: page:;
  slot references :: <sequence> = list(),
    init-keyword: references:;
end;

define class <wiki-change> (<entry>)
  slot change-action :: <symbol>,
    required-init-keyword: action:;
end;

define class <wiki-user-change> (<wiki-change>)
end;

define class <wiki-page-change> (<wiki-change>)
  slot change-version :: <integer> = 0,
    init-keyword: version:;
end;

define class <wiki-group-change> (<wiki-change>)
end;

define class <wiki-acls-change> (<wiki-change>)
end;

// Used for css class names in the /recent-changes page.
define generic change-type-name
    (change :: <wiki-change>) => (type-name :: <string>);

define method change-type-name
    (change :: <wiki-user-change>) => (type-name :: <string>)
  "user-change"
end;

define method change-type-name
    (change :: <wiki-page-change>) => (type-name :: <string>)
  "page-change"
end;

define method change-type-name
    (change :: <wiki-group-change>) => (type-name :: <string>)
  "group-change"
end;

define method change-type-name
    (change :: <wiki-acls-change>) => (type-name :: <string>)
  "acls-change"
end;

define method permanent-link
    (change :: <wiki-user-change>, #key) => (url :: <url>)
  user-permanent-link(change.title)
end;

define method permanent-link
    (change :: <wiki-page-change>, #key) => (url :: <url>)
  page-permanent-link(change.title)
end;

define method permanent-link
    (change :: <wiki-group-change>, #key) => (url :: <url>)
  group-permanent-link(change.title)
end;

define method permanent-link
    (change :: <wiki-acls-change>, #key) => (url :: <url>)
  page-permanent-link(change.title)
end;

// If authors: is not provided then the current authenticated user is used
// or an error is signalled if there is no authenticated user.
//
// Note that the title argument is assumed by some code to be the key
// that can be used to find the original object being modified.  e.g.,
// the user name, the group name, or the page title.
//
define method save-change
    (class :: <class>, title :: <string>, action :: <symbol>, comment :: <string>,
     #key authors)
 => ()
  if (~authors)
    let auth-user = authenticated-user();
    if (auth-user)
      authors := list(auth-user.user-name);
    else
      unauthorized-error();
    end;
  end;

  let change = make(class, title: title, action: action, authors: authors);
  change.comments[0] := make(<comment>,
                             name: as(<string>, action),
                             authors: authors,
                             content: make(<raw-content>, content: comment));
  save(change);
end;


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
  if (*version*)
    output("%s", format-date(formatted, *version*.date-published));
  end if;
end;

define tag show-page-published in wiki
    (page :: <wiki-dsp>)
    (formatted :: <string>)
  if (*page*)
    output("%s", format-date(formatted, *page*.date-published));
  end if;
end;

define tag show-version-number in wiki
    (page :: <wiki-dsp>)
    ()
  if (*version*)
    output("%d", *version*.version-number);
  end if;
end; 

define tag show-version-comment in wiki
    (page :: <wiki-dsp>)
    ()
  if (*version*)
    output("%s", *version*.comments[0].content.content);
  end if;
end;


//// Recent Changes

define class <recent-changes-page> (<wiki-dsp>)
end;

define constant $recent-changes-page
  = make(<recent-changes-page>, source: "list-recent-changes.dsp");

define method respond-to-get
    (page :: <recent-changes-page>, #key)
  let changes = sort(wiki-changes(),
                     test: method (change1, change2)
                             change1.date-published > change2.date-published   
                           end);
  let page-number = get-query-value("page", as: <integer>) | 1;
  let paginator = make(<paginator>,
                       sequence: changes,
                       current-page-number: page-number);
  set-attribute(page-context(), "recent-changes", paginator);
  next-method();
end;

// Return a sequence of changes of the given type.  This is used for
// Atom feed requests, in which case there is (presumably) no authenticated
// user so it only returns changes for publicly viewable pages in that case.
//
define method wiki-changes
    (#key change-type :: false-or(<class>),
          tag :: false-or(<string>),
          name :: false-or(<string>))
 => (changes :: <sequence>)
  let change-types = iff(change-type,
                         list(change-type),
                         list(<wiki-user-change>,
                              <wiki-page-change>,
                              <wiki-group-change>));
  let changes = apply(concatenate,
                      map(curry(map-as, <vector>, identity),
                          map(storage, change-types)));
  let auth-user = authenticated-user();
  local method filter (change)
          if (instance?(change, <wiki-page-change>))
            let page = find-page(change.title);
            if (has-permission?(auth-user, page, $view-content))
              // bug: this omits the deletion of a page with the tag.
              if (tag)
                page & member?(tag, page.latest-tags, test: \=)
              else
                ~name | change.title = name
              end
            end
          elseif (name)
            change.title = name
          else
            #t
          end
        end method filter;
  choose(filter, changes)
end method wiki-changes;

define body tag list-recent-changes in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  let pc = page-context();
  let previous-change = #f;
  let paginator :: <paginator> = get-attribute(pc, "recent-changes");
  for (change in paginator)
    set-attribute(pc, "day", standard-date(change.date-published));
    set-attribute(pc, "previous-day",
                  previous-change & standard-date(previous-change.date-published));
    set-attribute(pc, "time", standard-time(change.date-published));
    set-attribute(pc, "permalink", as(<string>, permanent-link(change)));
    set-attribute(pc, "change-class", change.change-type-name);
    set-attribute(pc, "title", change.title);
    set-attribute(pc, "action", as(<string>, change.change-action));
    set-attribute(pc, "comment", change.comments[0].content.content);
    set-attribute(pc, "version",
                  instance?(change, <wiki-page-change>) & change.change-version);
    set-attribute(pc, "verb", 
                  element($past-tense-table, change.change-action, default: #f)
                  | as(<string>, change.change-action));
    set-attribute(pc, "author",
                  begin
                    let authors = change.authors;
                    let user = ~empty?(authors) & find-user(authors[0]);
                    user & user.user-name
                  end);
    do-body();
    previous-change := change;
  end;
end tag list-recent-changes;

define tag base-url in wiki
    (page :: <wiki-dsp>)
    ()
  let url = current-request().request-absolute-url; // this may make a new url
  output("%s", build-uri(make(<url>,
                              scheme: url.uri-scheme,
                              host: url.uri-host,
                              port: url.uri-port)));
end tag base-url;

define sideways method permission-error (action, #key)
//  respond-to(#"get", *not-logged-in-page*);  
end;

define sideways method authentication-error (action, #key)
  respond-to(#"get", $not-logged-in-page);
end;

define constant $main-page
  = make(<wiki-dsp>, source: "main.dsp");

define constant $not-logged-in-page
  = make(<wiki-dsp>, source: "not-logged-in.dsp");


