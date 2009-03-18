module: wiki-internal

// generator  (nice comment!  i bet this generates something...)
define constant $generator :: <generator> =
  make(<generator>, text: "wiki", version: "0.1", uri: "");

define variable *change-verbs* = make(<table>);

define object-tests (day, change) in wiki end;

define error-test (exists) in wiki end;

define class <wiki-page-version> (<entry>)
  slot version-number :: <integer>,
    init-keyword: version:;
  slot version-page :: <wiki-page>,
    init-keyword: page:;
  slot references :: <sequence> = list(),
    init-keyword: references:;
end;

define class <versioned-object> (<object>)
  slot versions :: <vector> = #[],
    init-keyword: versions:;
end;

define class <wiki-change> (<entry>)
  slot change-action :: <symbol>,
    required-init-keyword: action:;
end;

define class <wiki-user-change> (<wiki-change>) end;

define class <wiki-page-change> (<wiki-change>)
  slot change-version :: <integer> = 0,
    init-keyword: version:;
end;

define class <wiki-group-change> (<wiki-change>) end;

// If authors: is not provided then the current authenticate user is used
// or an error is signalled if there is no authenticated user.
//
define method save-change
    (class :: <class>, title :: <string>, action :: <symbol>, comment :: <string>,
     #key authors)
 => ()
  if (~authors)
    let auth-user = authenticated-user();
    if (auth-user)
      authors := list(auth-user.username);
    else
      unauthorized-error();
    end;
  end;
    
  let change = make(class, title: title, action: action, authors: authors);
  change.comments[0] := make(<comment>, name: as(<string>, action), authors: authors,
                                        content: make(<raw-content>, content: comment));
  save(change);
end;


define tag show-version-published in wiki (page :: <wiki-dsp>)
 (formatted :: <string>)
  if (*version*)
    output("%s", format-date(formatted, *version*.published));
  end if;
end;

define tag show-page-published in wiki (page :: <wiki-dsp>)
 (formatted :: <string>)
  if (*page*)
    output("%s", format-date(formatted, *page*.published));
  end if;
end;

define tag show-version-number in wiki (page :: <wiki-dsp>)
 ()
  if (*version*)
    output("%d", *version*.version-number);
  end if;
end; 

define tag show-version-comment in wiki (page :: <wiki-dsp>)
 ()
  if (*version*)
    output("%s", *version*.comments[0].content.content);
  end if;
end;

define variable *recent-changes-page* =
  make(<wiki-dsp>, source: "list-recent-changes.dsp");

define method wiki-changes
    ()
 => (changes :: <sequence>);
  let change-types = list(<wiki-user-change>, <wiki-page-change>, <wiki-group-change>);
  apply(concatenate,
        map(curry(map-as, <vector>, identity),
            map(storage, change-types)));
end;
/*
  let user-changes = map-as(<vector>, identity, storage(<wiki-user-change>));
  let page-changes = map-as(<vector>, identity, storage(<wiki-page-change>));
  let group-changes = map-as(<vector>, identity, storage(<wiki-group-change>));
  let changes = concatenate(user-changes, page-changes, group-changes);
*/

define body tag list-changes-daily in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  local method bind-and-do-body (day)
    dynamic-bind(*day* = day)
      do-body();
    end;
  end;
  let day = #[];
  
  let changes = sort(wiki-changes(), test: method (first, second)
      first.published > second.published   
    end);
  for (change in changes)
    let (this-year, this-month, this-day) = decode-date(change.published);
    let (last-year, last-month, last-day) = if (size(day) > 0)
        decode-date(first(day).published);
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
    output("%s", format-date(formatted, first(*day*).published));
  end if;
end;

define tag show-change-date in wiki
 (page :: <wiki-dsp>)
 (formatted :: <string>)
  if (*change*)
    output("%s", format-date(formatted, *change*.published));
  end if;
end;

define tag show-change-comment in wiki (page :: <wiki-dsp>)
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

define tag show-change-author in wiki (page :: <wiki-dsp>)
 ()
  if (*change*)
    output("%s", first(*change*.authors));
  end if;
end;

define tag show-change-verb in wiki (page :: <wiki-dsp>)
 ()
  if (*change*)
    output("%s", *change-verbs*[*change*.object-class][*change*.change-action]);
  end if;
end;

define tag show-change-version in wiki (page :: <wiki-dsp>)
 ()  
  if (*change*)
    output("%d", *change*.change-version);
  end if;
end;

define named-method change-action=edit? in wiki (page :: <wiki-dsp>)
  *change* & *change*.change-action = #"edit";
end;

define named-method change-action=removal? in wiki (page :: <wiki-dsp>)
  *change* & *change*.change-action = #"removal";
end;

define sideways method permission-error (action, #key)
//  respond-to(#"get", *not-logged-in-page*);  
end;

define sideways method authentication-error (action, #key)
  respond-to(#"get", *not-logged-in-page*);
end;

define variable *main-page* =
  make(<wiki-dsp>, source: "main.dsp");

define variable *not-logged-in-page* =
  make(<wiki-dsp>, source: "not-logged-in.dsp");

