module: wiki-internal

define thread variable *group-name* = #f;


// class

define class <wiki-group> (<object>) 
  slot group-name :: <string>,
    required-init-keyword: name:;
  slot group-members :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: members:;
  slot group-authorization :: <table> = default-group-authorization(),
    init-keyword: authorization:;
end;

define object-test (group) in wiki end;

/*
define action-tests
 (view-page, edit-page,
  remove-page, view-versions)
in wiki end;
*/

define error-test (name) in wiki end;

/*
define group-authorizations
 (pages-write = #f, 
  pages-read = #t)
end;

=>
*/

define method default-group-authorization ()
 => (authorization :: <table>);
  table(#"pages-write" => #f,
	#"pages-read" => #t);
end;

define named-method group-authorization-pages-write? in wiki
 (page :: <wiki-dsp>)
  *group* & *group*.group-authorization[#"pages-write"]
end;

define named-method group-authorization-pages-read? in wiki
 (page :: <wiki-dsp>)
  *group* & *group*.group-authorization[#"pages-read"]
end;


// verbs

*change-verbs*[<wiki-group-change>] := 
  table(#"edit" => "edited",
	#"removal" => "removed",
	#"add" => "added",
	#"renaming" => "renamed");


// storage

define method storage-type
    (type == <wiki-group>)
 => (type :: <type>);
  <string-table>;
end;

define inline-only method key
    (group :: <wiki-group>)
 => (res :: <string>);
  group.group-name;
end;


// url

define method permanent-link
    (group :: <wiki-group>, #key escaped?, full?)
 => (url :: <url>);
  group-permanent-link(key(group));
end;

define method group-permanent-link
    (name :: <string>)
 => (url :: <url>);
  let location = parse-url("/groups/");
  last(location.uri-path) := name;
  transform-uris(request-url(current-request()), location, as: <url>);
end;

define method redirect-to (group :: <wiki-group>)
  redirect-to(permanent-link(group));
end;


// methods

define method find-group
    (name :: <string>)
 => (group :: false-or(<wiki-group>));
  element(storage(<wiki-group>), name, default: #f);
end;

/*
define method add-author
    (page :: <wiki-page>, user :: <user>)
 => (user :: <user>);
  page.authors := add-new!(page.authors, user, test: method (first, second)
      first.username = second.username
    end);
  user;
end;
*/

define method rename-group
    (name :: <string>, new-name :: <string>,
     #key comment :: <string> = "")
 => ();
  let group = find-group(name);
  if (group)
    rename-group(group, new-name, comment: comment)
  end if;
end;
 
define method rename-group 
    (group :: <wiki-group>, name :: <string>,
     #key comment :: <string> = "")
 => ();
  let comment = concatenate("was: ", group.group-name, ". ", comment);
  remove-key!(storage(<wiki-group>), group.group-name);
  group.group-name := name;
  storage(<wiki-group>)[name] := group;
  save-change(<wiki-group-change>, name, #"renaming", comment);
  save(group);
  dump-data();
end;

define method save-group
    (name :: <string>,
     #key comment :: <string> = "")
 => ();
  let group :: false-or(<wiki-group>) = find-group(name);
  let action :: <symbol> = #"edit";
  if (~group)
    group := make(<wiki-group>, name: name);
    action := #"add";
  end if;
  save-change(<wiki-group-change>, name, action, comment);
  save(group);
  dump-data();
end;

define method add-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ();
  add!(group.group-members, user);
  let comment = concatenate("added ", user.username, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

define method remove-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ();
  remove!(group.group-members, user);
  let comment = concatenate("removed ", user.username, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

define method remove-group
    (group :: <wiki-group>,
     #key comment :: <string> = "")
 => ();
  save-change(<wiki-group-change>, group.group-name, #"removal", comment);
  remove-key!(storage(<wiki-group>), group.group-name);
  dump-data();
end;

/*
define method permitted? (action == #"edit-page", #key)
 => (permitted? :: <boolean>);
  (~ authenticated-user()) & error(make(<authentication-error>));
end;
*/


// pages

define variable *view-group-page* =
  make(<wiki-dsp>, source: "view-group.dsp");

define variable *edit-group-page* = 
  make(<wiki-dsp>, source: "edit-group.dsp");

define variable *edit-group-members-page* = 
  make(<wiki-dsp>, source: "edit-group-members.dsp");

define variable *edit-group-authorization-page* =
  make(<wiki-dsp>, source: "edit-group-authorization.dsp");

define variable *list-groups-page* =
  make(<wiki-dsp>, source: "list-groups.dsp");

define variable *remove-group-page* = 
  make(<wiki-dsp>, source: "remove-group.dsp");

define variable *non-existing-group-page* =
  make(<wiki-dsp>, source: "non-existing-group.dsp");


// actions

define method do-groups ()
  case
    get-query-value("go") =>
      redirect-to(group-permanent-link(get-query-value("query")));
    otherwise =>
      process-page(*list-groups-page*);
  end;
end;

define method bind-group (#key name)
  *group* := find-group(percent-decode(name));
end;

define method show-group (#key name)
  dynamic-bind (*group-name* = percent-decode(name))
    respond-to(#"get", case
                         *page* => *view-group-page*;
                         authenticated-user() => *edit-group-page*;
                         otherwise => *non-existing-group-page*;
                       end case);
  end;
end method show-group;

define method show-edit-group (#key name)
  dynamic-bind (*group-name* = percent-decode(name))
    respond-to(#"get", case
                         authenticated-user() => *edit-group-page*;
                         otherwise => *non-existing-group-page*;
                       end case);
  end;
end method show-edit-group;

define method do-save-group-members (#key name)
  let name = percent-decode(name);
  let comment = get-query-value("comment");
  let group = find-group(name);
  if (get-query-value("add") & get-query-value("users"))
    let user-list = get-query-value("users");
    if (instance?(user-list, <string>))
      user-list := list(user-list);
    end if;
    let users = choose(rcurry(instance?, <wiki-user>), 
                       map(find-user, user-list));  
    do(rcurry(add-member, group, comment:, comment), users);
  elseif (get-query-value("remove") & get-query-value("members"))
    let member-list = get-query-value("members");
    if (instance?(member-list, <string>))
      member-list := list(member-list);
    end if;
    let members = choose(rcurry(instance?, <wiki-user>),
                         map(find-user, member-list));
    do(rcurry(remove-member, group, comment:, comment), members);
  end if;
  redirect-to(request-url(current-request()));
end method do-save-group-members;

define method do-save-group-authorization (#key name)
  let name = percent-decode(name);
  let comment = get-query-value("comment");
  let group = find-group(name);
  if (group)
    for (default keyed-by name in default-group-authorization())
      let value = get-query-value(as(<string>, name));
      group.group-authorization[name] := (value ~= #f);
    end for;
  end if;
  save-change(<wiki-group-change>, name, #"edit", comment);
  save(group);
  dump-data();
  redirect-to(request-url(current-request()));
end method do-save-group-authorization;

define method do-save-group (#key name)
  let name = percent-decode(name);
  let new-name = get-query-value("name");
  let comment = get-query-value("comment");
  let group = find-group(name);  

  let errors = #();

  if (~ instance?(name, <string>) | name = "" | 
      (new-name & (~ instance?(new-name, <string>) | new-name = "")))
    errors := add!(errors, #"name");
  end if;

  if (group & new-name & new-name ~= name & new-name ~= "")
    if (find-group(new-name))
      errors := add!(errors, #"exists");
    else
      rename-group(group, new-name, comment: comment);
      name := new-name;
    end if;
  end if;

  if (empty?(errors))
    save-group(name, comment: comment);
    redirect-to(find-group(name));
  else
    dynamic-bind (*errors* = errors, *form* = current-request().request-query-values)
      respond-to(#"get", *edit-group-page*);
    end;
  end if;
end;

define method do-remove-group (#key name)
   let group = find-group(percent-decode(name));
   remove-group(group, comment: get-query-value("comment"));
   redirect-to(group);
end;

define method redirect-to-group-or (page :: <page>, #key name)
  if (*group*)
    respond-to(#"get", page);
  else
    redirect-to(group-permanent-link(percent-decode(name)));
  end if;
end;

define constant edit-group-members =
  curry(redirect-to-group-or, *edit-group-members-page*);

define constant edit-group-authorization =
  curry(redirect-to-group-or, *edit-group-authorization-page*);

define constant show-remove-group =
  curry(redirect-to-group-or, *remove-group-page*);


// tags

define tag show-group-permanent-link in wiki
 (page :: <wiki-dsp>)
 (use-change :: <boolean>)
  output("%s", 
    if (use-change)
      group-permanent-link(*change*.title)
    elseif (*group*)
      permanent-link(*group*)
    else "" end if);
end;

define tag show-group-name in wiki
 (page :: <wiki-dsp>)
 ()
  output("%s", escape-xml(if (*group*)
    *group*.group-name
  elseif (*group-name*)
    *group-name*
  else "" end if));
end;


// body tags 

define body tag list-groups in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  let groups = storage(<wiki-group>);
  for (group in groups)
    dynamic-bind(*group* = group)
      do-body();
    end;
  end for;
end;

define body tag list-group-members in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  if (*group*)
    for (user in *group*.group-members)
      dynamic-bind(*user* = user)
        do-body();
      end;
    end for;
  end if;
end;


// named methods

define named-method group-changed? in wiki
 (page :: <wiki-dsp>)
  instance?(*change*, <wiki-group-change>);
end;
