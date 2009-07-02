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

define wf/object-tests (day, change) in wiki end;

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

// If authors: is not provided then the current authenticated user is used
// or an error is signalled if there is no authenticated user.
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
  // todo -- can remove a lot of the tags defined for this page's template
  //         by using page context etc.
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

define body tag list-changes-daily in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  local method bind-and-do-body (day)
    dynamic-bind(*day* = day)
      do-body();
    end;
  end;
  let day = #[];
  
  let changes = sort(wiki-changes(),
                     test: method (change1, change2)
                             change1.date-published > change2.date-published   
                           end);
  for (change in changes)
    let (this-year, this-month, this-day) = decode-date(change.date-published);
    let (last-year, last-month, last-day) = if (size(day) > 0)
        decode-date(first(day).date-published);
      end if;
    if (empty?(day) | (last-year & 
     (last-year = this-year & last-month = this-month & last-day = this-day)))
      day := add!(day, change);
      if (change = last(changes))
        bind-and-do-body(day);
      end if;
    else
      bind-and-do-body(day);
      day := vector(change);
    end if;
  end for;
end;

define body tag list-day-changes in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*day*)
    for (change in *day*)
      dynamic-bind(*change* = change)
        do-body();
      end;
    end for;
  end if;
end;

define tag show-day-date in wiki (page :: <wiki-dsp>)
 (formatted :: <string>)
  if (*day*)
    output("%s", format-date(formatted, first(*day*).date-published));
  end if;
end;

define tag show-change-date in wiki
    (page :: <wiki-dsp>)
    (formatted :: <string>)
  if (*change*)
    output("%s", format-date(formatted, *change*.date-published));
  end if;
end;

define tag show-change-comment in wiki
    (page :: <wiki-dsp>)
    ()
  if (*change*)
    output("%s", *change*.comments[0].content.content);
  end if;
end;

define tag show-change-title in wiki (page :: <wiki-dsp>)
    ()
  if (*change*)
    output("%s", *change*.title);
  end if;
end;

define tag show-change-author in wiki
    (page :: <wiki-dsp>)
    ()
  if (*change*)
    output("%s", first(*change*.authors));
  end if;
end;

define tag show-change-verb in wiki
    (page :: <wiki-dsp>)
    ()
  if (*change*)
    let verb = element($past-tense-table, *change*.change-action, default: #f)
                 | as(<string>, *change*.change-action);
    output("%s", verb);
  end if;
end;

define tag show-change-version in wiki (page :: <wiki-dsp>)
    ()
  if (*change*)
    output("%d", *change*.change-version);
  end if;
end;

define tag base-url in wiki
    (page :: <wiki-dsp>)
    ()
  let url = current-request().request-absolute-url; // this may make a new url
  output("%s", build-uri(make(<url>,
                              scheme: url.uri-scheme,
                              host: url.uri-host,
                              port: url.uri-port)));
end tag base-url;

define named-method group-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-group-change>);
end;

define named-method change-action=edit? in wiki
    (page :: <wiki-dsp>)
  *change* & *change*.change-action = #"edit";
end;

define named-method change-action=removal? in wiki
    (page :: <wiki-dsp>)
  *change* & *change*.change-action = #"removal";
end;

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


