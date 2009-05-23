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
  slot group-members :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: members:;
  /* todo
  slot group-description :: <string>,
    init-keyword: description:;
  */
end class <wiki-group>;

define method initialize
    (group :: <wiki-group>, #key)
  add-new!(group.group-members, group.group-owner);
end;

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

$change-verbs[<wiki-group-change>]
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

// Find all groups that a user is a member of.
//
define method user-groups
    (user :: <wiki-user>)
 => (groups :: <collection>)
  choose(method (group)
           member?(user, group.group-members)
         end,
         table-values(storage(<wiki-group>)))
end;

define method groups-owned-by-user
    (user :: <wiki-user>)
 => (groups :: <collection>)
  choose(method (group)
           group.group-owner = user
         end,
         table-values(storage(<wiki-group>)))
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

define method create-group
    (name :: <string>, #key comment :: <string> = "")
 => (group :: <wiki-group>)
  let group = make(<wiki-group>,
                   name: name,
                   owner: authenticated-user());
  save-change(<wiki-group-change>, name, #"add", comment);
  save(group);
  dump-data();
  group
end method create-group;

define method add-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ()
  add-new!(group.group-members, user);
  let comment = concatenate("added ", user.user-name, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

define method remove-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ()
  remove!(group.group-members, user);
  let comment = concatenate("removed ", user.user-name, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, #"edit", comment);  
  save(group);
  dump-data();
end;

// todo -- MAKE THREAD SAFE
define method remove-group
    (group :: <wiki-group>,
     #key comment :: <string> = "")
  remove-key!(storage(<wiki-group>), group.group-name);
  for (page in storage(<wiki-page>))
    remove-rules-for-target(page.access-controls, group);
  end;
  save-change(<wiki-group-change>, group.group-name, #"removal", comment);
  dump-data();
end;


/*
define method permitted? (action == #"edit-page", #key)
 => (permitted? :: <boolean>);
  (~ authenticated-user()) & error(make(<authentication-error>));
end;
*/

//// List Groups (note not a subclass of <group-page>)

define class <list-groups-page> (<wiki-dsp>)
end;

define constant $list-groups-page
  = make(<list-groups-page>, source: "list-groups.dsp");

// Posting to /groups creates a new group.
//
define method respond-to-post
    (page :: <list-groups-page>, #key)
  let user = authenticated-user();
  let new-name = trim(get-query-value("group") | "");
  // "block" really needs a no-error clause...write a try macro...
  let error? = block (return)
                 validate-group-name(new-name);
                 #f
               exception (ex :: <error>)
                 add-field-error("group", ex);
                 respond-to-get($list-groups-page);
                 #t
               end;
  if (~error?)
    if (find-group(new-name))
      add-field-error("group", "A group named %s already exists.", new-name);
      respond-to-get($list-groups-page);
    else
      redirect-to(create-group(new-name));
    end;
  end;
end method respond-to-post;


//// Group page

define class <group-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <group-page>, #key name :: <string>)
  dynamic-bind (*group-name* = percent-decode(name),
                *group* = find-group(*group-name*))
    if (~page-requires-group-modify-permission?(page)
          | can-modify-group?(page))
      next-method();
    else
      add-page-error("You do not have permission to modify group '%s'.", name);
      respond-to-get($view-group-page, name: name);
    end;
  end;
end method respond-to-get;

define constant $non-existing-group-page
  = make(<group-page>, source: "non-existing-group.dsp");

define method page-requires-group-modify-permission?
    (page :: <group-page>) => (req? :: <boolean>)
  #t
end;


//// View Group

define class <view-group-page> (<group-page>)
end;

define constant $view-group-page
  = make(<view-group-page>, source: "view-group.dsp");

define method page-requires-group-modify-permission?
    (page :: <view-group-page>) => (req? :: <boolean>)
  #f
end;

define named-method user-is-group-owner?
    (page :: <view-group-page>)
  *group*.group-owner = find-user(get-attribute(page-context(), "user-name"))
end;


//// Edit Group

define class <edit-group-page> (<group-page>)
end;

define constant $edit-group-page
  = make(<edit-group-page>, source: "edit-group.dsp");

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
        add-field-error("name", ex);
      end;
      if (find-group(new-name))
        add-field-error("name", "A group named %s already exists", new-name);
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

define class <remove-group-page> (<group-page>)
end;

define constant $remove-group-page
  = make(<remove-group-page>, source: "remove-group.dsp");

define method respond-to-post
    (page :: <remove-group-page>, #key name :: <string>)
  dynamic-bind(*group-name* = percent-decode(name),
               *group* = find-group(*group-name*))
    if (*group*)
      remove-group(*group*, comment: get-query-value("comment"));
      add-page-note("Group %s removed", *group-name*);
      respond-to-get($list-groups-page);
    else
      respond-to-get($non-existing-group-page);
    end;
  end;
end method respond-to-post;


//// Edit Group Members

// todo -- eventually it should be possible to edit the group name, owner,
// and members all in one page.

define class <edit-group-members-page> (<group-page>)
end;

define constant $edit-group-members-page
  = make(<edit-group-members-page>, source: "edit-group-members.dsp");

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



//// Tags

define tag show-group-permanent-link in wiki
    (page :: <wiki-dsp>)
    (use-change :: <boolean>)
  output("%s", iff(use-change,
                   group-permanent-link(*change*.title),
                   permanent-link(*group*)));
end;

// get rid of this and put the group name in the page context so it
// can be accessed by <dsp:get>?
//
define tag show-group-name in wiki
    (page :: <wiki-dsp>)
    ()
  output("%s", escape-xml(case
                            *group* => *group*.group-name;
                            *group-name* => *group-name*;
                            otherwise => "";
                          end));
end tag show-group-name;


//// Named Methods

define named-method all-group-names in wiki
    (page :: <list-groups-page>)
  sort(map(group-name, table-values(storage(<wiki-group>))))
end;

define named-method group-changed? in wiki
    (page :: <wiki-dsp>)
  instance?(*change*, <wiki-group-change>);
end;

define named-method group-member-names in wiki
    (page :: <group-page>)
  sort(map(user-name, group-members(*group*)))
end;

define named-method can-modify-group?
    (page :: <group-page>)
  let user = authenticated-user();
  user & (administrator?(user) | user = *group*.group-owner)
end;


