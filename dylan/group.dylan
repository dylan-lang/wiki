Module: wiki-internal

// todo -- I don't like that these are mutable.  It makes it hard to
//         reason about the code.  Probably goes for other objects too.
//
define class <wiki-group> (<object>)
  slot group-name :: <string>,
    required-init-keyword: name:;
  slot group-owner :: <wiki-user>,
    required-init-keyword: owner:;
  slot group-members :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: members:;
  slot group-description :: <string> = "",
    init-keyword: description:;
end class <wiki-group>;

define method initialize
    (group :: <wiki-group>, #key)
  add-new!(group.group-members, group.group-owner);
end;

// This is pretty restrictive for now.  Easier to loosen the rules later
// than to tighten them up.  The name has been pre-trimmed and %-decoded.
//
define method validate-group-name
    (name :: <string>) => (name :: <string>)
  if (empty?(name))
    error("Group is required.");
  elseif (~regex-search("^[A-Za-z0-9_-]+$", name))
    error("Group names may contain only alphanumerics, hyphens and underscores.");
  end;
  name
end method validate-group-name;

// Must come up with a simpler, more general way to handle form errors...
define wf/error-test (name) in wiki end;


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
    save-change(<wiki-group-change>, new-name, $rename, comment);
    save(group);
    dump-data();
  end if;
end method rename-group;

define method create-group
    (name :: <string>, #key comment :: <string> = "")
 => (group :: <wiki-group>)
  let group = make(<wiki-group>,
                   name: name,
                   owner: authenticated-user());
  save-change(<wiki-group-change>, name, $create, comment);
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
  save-change(<wiki-group-change>, group.group-name, $edit, comment);  
  save(group);
  dump-data();
end;

define method remove-member
    (user :: <wiki-user>, group :: <wiki-group>,
     #key comment :: <string> = "")
 => ()
  remove!(group.group-members, user);
  let comment = concatenate("removed ", user.user-name, ". ", comment);
  save-change(<wiki-group-change>, group.group-name, $edit, comment);  
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
  save-change(<wiki-group-change>, group.group-name, $remove, comment);
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

define method respond-to-get
    (page :: <list-groups-page>, #key)
  local method group-info (group)
          table(<string-table>,
                "name" => group.group-name,
                "count" => integer-to-string(group.group-members.size),
                "description" => quote-html(group.group-description))
        end;
  set-attribute(page-context(), "all-groups",
                map(group-info, table-values(storage(<wiki-group>))));
  next-method();
end method respond-to-get;

// Posting to /groups creates a new group.
//
define method respond-to-post
    (page :: <list-groups-page>, #key)
  let user = authenticated-user();
  let (new-name, error?) = validate-form-field("group", validate-group-name);
  if (~error? & find-group(new-name))
    add-field-error("group", "A group named %s already exists.", new-name);
  end;
  if (page-has-errors?())
    respond-to-get($list-groups-page)
  else
    redirect-to(create-group(new-name));
  end;
end method respond-to-post;


//// Group page

define class <group-page> (<wiki-dsp>)
end;

// Add basic group attributes to page context and display the page template.
//
define method respond-to-get
    (page :: <group-page>, #key name :: <string>)
  let name = percent-decode(name);
  let group = find-group(name);
  let pc = page-context();
  set-attribute(pc, "group-name", name);
  let user = authenticated-user();
  if (user)
    set-attribute(pc, "active-user", user.user-name);
  end;
  if (group)
    set-attribute(pc, "group-owner", group.group-owner.user-name);
    set-attribute(pc, "group-description", group.group-description);
    set-attribute(pc, "group-members", sort(map(user-name, group.group-members)));
    next-method();
  else
    // Should only get here via a typed-in URL.
    respond-to-get($non-existing-group-page);
  end if;
end method respond-to-get;

define constant $non-existing-group-page
  = make(<wiki-dsp>, source: "non-existing-group.dsp");


//// View Group

define constant $view-group-page
  = make(<group-page>, source: "view-group.dsp");


//// Edit Group

define class <edit-group-page> (<group-page>)
end;

define constant $edit-group-page
  = make(<edit-group-page>, source: "edit-group.dsp");

define method respond-to-post
    (page :: <edit-group-page>, #key name :: <string>)
  let name = trim(percent-decode(name));
  let group = find-group(name);
  if (~group)
    // foreign post?
    respond-to-get($non-existing-group-page);
  else
    let new-name = validate-form-field("group-name", validate-group-name);
    let owner-name = validate-form-field("group-owner", validate-user-name);
    let new-owner = find-user(owner-name);
    let comment = trim(get-query-value("comment") | "");
    let description = trim(get-query-value("group-description") | "");
    if (empty?(description))
      add-field-error("group-description", "A description is required.");
    end;
    if (~new-owner)
      add-field-error("group-owner", "User %s unknown", owner-name);
    end;
    if (new-name ~= name & find-group(new-name))
      add-field-error("group-name",
                      "A group named %s already exists.", new-name);
    end;
    if (page-has-errors?())
      // redisplay page with errors
      respond-to-get($edit-group-page, name: name);
    else
      // todo -- the rename and save should be part of a transaction.
      if (new-name ~= name)
        rename-group(group, new-name, comment: comment);
        name := new-name;
      end;
      if (description ~= group.group-description
            | new-owner ~= group.group-owner)
        group.group-description := description;
        group.group-owner := new-owner;
        save(group);
        save-change(<wiki-group-change>, name, $edit, comment);
        dump-data();
      end;
      redirect-to(group);
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
  let group-name = percent-decode(name);
  let group = find-group(group-name);
  if (group)
    let user = authenticated-user();
    if (user & (user = group.group-owner | administrator?(user)))
      remove-group(group, comment: get-query-value("comment"));
      add-page-note("Group %s removed", group-name);
    else
      add-page-error("You do not have permission to remove this group.")
    end;
    respond-to-get($list-groups-page);
  else
    respond-to-get($non-existing-group-page);
  end;
end method respond-to-post;


//// Edit Group Members

// todo -- eventually it should be possible to edit the group name, owner,
// and members all in one page.

define class <edit-group-members-page> (<edit-group-page>)
end;

define constant $edit-group-members-page
  = make(<edit-group-members-page>, source: "edit-group-members.dsp");

define method respond-to-get
    (page :: <edit-group-members-page>,
     #key name :: <string>, must-exist :: <boolean> = #t)
  let name = percent-decode(name);
  let group = find-group(name);
  if (group)
    // Note: user must be logged in.  That check is done in the template.
    // non-members is for the add/remove members page
    set-attribute(page-context(),
                  "non-members",
                  sort(key-sequence(storage(<wiki-user>))));
    // Add all users to the page context so they can be selected
    // for group membership.
    set-attribute(page-context(),
                  "all-users",
                  sort(key-sequence(storage(<wiki-user>))));
  end;
  next-method();
end method respond-to-get;

define method respond-to-post
    (page :: <edit-group-members-page>, #key name :: <string>)
  let group-name = percent-decode(name);
  let group = find-group(group-name);
  if (group)
    with-query-values (add as add?, remove as remove?, users, members, comment)
      if (add? & users)
        if (instance?(users, <string>))
          users := list(users);
        end if;
        let users = choose(identity, map(find-user, users));
        do(rcurry(add-member, group, comment:, comment), users);
      elseif (remove? & members)
        if (instance?(members, <string>))
          members := list(members);
        end if;
        let members = choose(identity, map(find-user, members));
        do(rcurry(remove-member, group, comment:, comment), members);
      end if;
      respond-to-get(page, name: name);
    end;
  else
    respond-to-get($non-existing-group-page);
  end;
end method respond-to-post;


define named-method can-modify-group?
    (page :: <group-page>)
  let user = authenticated-user();
  user & (administrator?(user)
            | user.user-name = get-attribute(page-context(), "active-user"));
end;


