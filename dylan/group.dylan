Module: wiki-internal

define thread variable *group* :: false-or(<wiki-group>) = #f;
define thread variable *group-name* :: false-or(<string>) = #f;

// This shouldn't be necessary.  Get rid of calls to group? in the
// templates and simply don't show that template if the group isn't
// defined.
define named-method group? in wiki 
    (page :: <dylan-server-page>)
  *group*
end;

define class <wiki-group> (<object>)
  slot group-name :: <string>,
    required-init-keyword: name:;
  slot group-owner :: <wiki-user>,
    required-init-keyword: owner:;
  constant slot group-members :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: members:;
  /* todo
  slot group-description :: <string>,
    init-keyword: description:;
  */
end class <wiki-group>;

// This is pretty restrictive for now.  Easier to loosen the rules later
// than to tighten them up.
define method validate-group-name
    (name :: <string>)
  if (empty?(name))
    error("Group name must be non-empty.");
  elseif (~regex-search("^[A-Za-z0-9_-]", name))
    error("Group name must contain only alphanumerics, hyphens and underscores.");
  end;
end method validate-group-name;

// Must come up with a simpler, more general way to handle form errors...
define wf/error-test (name) in wiki end;

*change-verbs*[<wiki-group-change>]
  := table(#"edit" => "edited",
           #"removal" => "removed",
           #"add" => "added",
           #"renaming" => "renamed");


// storage

define method storage-type
    (type == <wiki-group>)
 => (type :: <type>)
  <string-table>
end;

// Tells web-framework under what unique (I assume) key to store this object.
//
define inline-only method key
    (group :: <wiki-group>)
 => (res :: <string>)
  group.group-name
end;


// url

define method permanent-link
    (group :: <wiki-group>, #key escaped?, full?)
 => (url :: <url>)
  group-permanent-link(key(group))
end;

define method group-permanent-link
    (name :: <string>)
 => (url :: <url>)
  let location = wiki-url("/groups/%s", name);
  transform-uris(request-url(current-request()), location, as: <url>)
end;

define method redirect-to (group :: <wiki-group>)
  redirect-to(permanent-link(group));
end;


// methods

define method find-group
    (name :: <string>)
 => (group :: false-or(<wiki-group>))
  element(storage(<wiki-group>), name, default: #f)
end;

define method rename-group
    (name :: <string>, new-name :: <string>,
     #key comment :: <string> = "")
 => ()
  let group = find-group(name);
  if (group)
    rename-group(group, new-name, comment: comment)
  end if;
end;

define method rename-group
    (group :: <wiki-group>, new-name :: <string>,
     #key comment :: <string> = "")
 => ()
  if (group.group-name ~= new-name)
    if (find-group(new-name))
      // todo -- raise more specific error...test...
      error("group %s already exists", new-name);
    end;
    let comment = concatenate("was: ", group.group-name, ". ", comment);
    remove-key!(storage(<wiki-group>), group.group-name);
    group.group-name := new-name;
    storage(<wiki-group>)[new-name] := group;
    save-change(<wiki-group-change>, new-name, #"renaming", comment);
    save(group);
    dump-data();
  end if;
end method rename-group;

define method save-group
    (name :: <string>, #key comment :: <string> = "")
 => ()
  let group :: false-or(<wiki-group>) = find-group(name);
  let action :: <symbol> = #"edit";
  if (~group)
    group := make(<wiki-group>,
                  name: name,
                  owner: authenticated-user());
    action := #"add";
  end if;
  save-change(<wiki-group-change>, name, action, comment);
  save(group);
  dump-data();
end method save-group;

define method add-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ()
  add!(group.group-members, user);
  let comment = concatenate("added ", user.username, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

define method remove-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ()
  remove!(group.group-members, user);
  let comment = concatenate("removed ", user.username, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

define method remove-group
    (group :: <wiki-group>,
     #key comment :: <string> = "")
  // todo -- Remove the group from any ACLs!
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


//// View Group

define class <view-group-page> (<wiki-dsp>) end;

define constant $view-group-page
  = make(<view-group-page>, source: "view-group.dsp");

define method respond-to-get
    (page :: <view-group-page>, #key name :: <string>)
  dynamic-bind (*group-name* = percent-decode(name),
                *group* = find-group(*group-name*))
    next-method();
  end;
end method respond-to-get;


//// Edit Group

define class <edit-group-page> (<wiki-dsp>) end;

define constant $edit-group-page
  = make(<edit-group-page>, source: "edit-group.dsp");

define method respond-to-get
    (page :: <edit-group-page>, #key name :: <string>)
  dynamic-bind (*group-name* = percent-decode(name),
                *group* = find-group(*group-name*))
    // Note that the template takes care of checking the ACLs.
    respond-to-get(case
                     authenticated-user() => $edit-group-page;
                     otherwise => $non-existing-group-page;
                   end);
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <edit-group-page>, #key name :: <string>)
  let name = trim(percent-decode(name));

  if (empty?(name))
    respond-to-get($non-existing-group-page);
  else
    let errors = #();
    let new-name = trim(get-query-value("name") | "");
    let comment = trim(get-query-value("comment") | "");

    if (~empty?(new-name))
      block ()
        validate-group-name(new-name);
      exception (ex :: <error>)
        note-form-error(ex, field-name: #"name");
      end;
      if (find-group(new-name))
        note-form-error("A group named %s already exists",
                        format-arguments: list(new-name),
                        field-name: #"name");
      end;
    end if;

    if (empty?(errors))
      let group = find-group(name);
      if (~empty?(new-name))
        rename-group(group, new-name, comment: comment);
        name := new-name;
      end;
      save-group(name, comment: comment);
      redirect-to(find-group(name));
    else
      dynamic-bind (wf/*errors* = errors,
                    wf/*form* = current-request().request-query-values)
        respond-to-get($edit-group-page, name: name);
      end;
    end if;
  end if;
end method respond-to-post;
    

//// Remove Group

define class <remove-group-page> (<wiki-dsp>)
end;

define constant $remove-group-page
  = make(<remove-group-page>, source: "remove-group.dsp");

define method respond-to-get
    (page :: <remove-group-page>, #key name :: <string>)
  dynamic-bind(*group-name* = percent-decode(name),
               *group* = find-group(*group-name*))
    next-method();
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <remove-group-page>, #key name :: <string>)
  dynamic-bind(*group-name* = percent-decode(name),
               *group* = find-group(*group-name*))
    if (*group*)
      remove-group(*group*, comment: get-query-value("comment"));
      note-form-message("Group %s removed", *group-name*);
      redirect-to($list-groups-page);
    else
      respond-to-get($non-existing-group-page);
    end;
  end;
end method respond-to-post;



//// Edit Group

// todo -- eventually it should be possible to edit the group name, owner,
// and members all in one page.

define class <edit-group-members-page> (<wiki-dsp>)
end;

define constant $edit-group-members-page
  = make(<edit-group-members-page>, source: "edit-group-members.dsp");

define method respond-to-get
    (page :: <edit-group-members-page>, #key name :: <string>)
  dynamic-bind(*group-name* = percent-decode(name),
               *group* = find-group(*group-name*))
    next-method();
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <edit-group-members-page>, #key name :: <string>)
  dynamic-bind(*group-name* = percent-decode(name),
               *group* = find-group(*group-name*))
    if (*group*)
      with-query-values (add as add?, remove as remove?, users, members, comment)
        if (add? & users)
          if (instance?(users, <string>))
            users := list(users);
          end if;
          let users = choose(identity, map(find-user, users));
          do(rcurry(add-member, *group*, comment:, comment), users);
        elseif (remove? & members)
          if (instance?(members, <string>))
            members := list(members);
          end if;
          let members = choose(identity, map(find-user, members));
          do(rcurry(remove-member, *group*, comment:, comment), members);
        end if;
        redirect-to(request-url(current-request()));
      end;
    else
      respond-to-get($non-existing-group-page);
    end;
  end;
end method respond-to-post;



//// List Groups

define constant $list-groups-page
  = make(<wiki-dsp>, source: "list-groups.dsp");

define variable $non-existing-group-page
  = make(<wiki-dsp>, source: "non-existing-group.dsp");


// actions

define method do-groups ()
  case
    get-query-value("go") =>
      redirect-to(group-permanent-link(get-query-value("query")));
    otherwise =>
      process-page($list-groups-page);
  end;
end;

/*
define method redirect-to-group-or (page :: <page>, #key name)
  if (*group*)
    respond-to(#"get", page);
  else
    redirect-to(group-permanent-link(percent-decode(name)));
  end if;
end;
*/

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
  output("%s", escape-xml(case
                            *group* => *group*.group-name;
                            *group-name* => *group-name*;
                            otherwise => "";
                          end));
end tag show-group-name;


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

// named methods

define named-method group-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-group-change>);
end;

define named-method group-member-names in wiki
    (page :: <wiki-dsp>)
  map(username, group-members(*group*))
end;

define named-method user-is-group-owner?
    (page :: <wiki-dsp>)
  *group*.group-owner = find-user(get-attribute(page-context(), "user-name"))
end;

