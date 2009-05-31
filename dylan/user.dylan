Module: wiki-internal

define thread variable *user-username* = #f;


// class

define constant <wiki-user> = <user>;
/*
define class <wiki-user> (<user>)
end;
*/

// This is set in main.dylan, via the config file.
define variable *admin-user* :: false-or(<wiki-user>) = #f;

define wf/object-test (user) in wiki end;

/*
define wf/action-tests
 (add-user, edit-user, remove-user, list-users)
in wiki end;
*/

define wf/error-tests
 (username, password, email)
in wiki end;


// verbs

$change-verbs[<wiki-user-change>] :=
  table(#"edit" => "edited",
	#"removal" => "removed",
	#"add" => "registered");


// url

define method permanent-link
    (user :: <wiki-user>, #key escaped?, full?)
 => (url :: <url>)
  user-permanent-link(user.user-name);
end;

define method user-permanent-link
    (username :: <string>)
 => (url :: <url>)
  let location = wiki-url("/users/%s", username);
  transform-uris(request-url(current-request()), location, as: <url>);
end;

define method redirect-to (user :: <wiki-user>)
  redirect-to(permanent-link(user));
end;


// methods

// This is pretty restrictive for now.  Easier to loosen the rules later
// than to tighten them up.  The name has been pre-trimmed and %-decoded.
//
define method validate-user-name
    (name :: <string>) => (name :: <string>)
  if (empty?(name))
    error("A user name is required.");
  elseif (~regex-search("^[A-Za-z0-9_-]+$", name))
    error("User names must contain only alphanumerics, hyphens and underscores.");
  end;
  name
end method validate-user-name;

/*
define method storage-type
    (type == <wiki-user>)
 => (type :: <type>)
  <string-table>
end;
*/

define method save-user
    (name :: <string>, password :: false-or(<string>), email :: <string>,
     #key comment :: <string> = "", administrator?)
 => (user :: <wiki-user>)
  let user :: false-or(<wiki-user>) = find-user(name);
  let action :: <symbol> = #"edit";
  if (user)
    if (password)
      user.user-password := password;
    end if;
    user.user-email := email;
  else
    user := make(<wiki-user>,
                 name: name,
                 password: password,
                 email: email);
    action := #"add";
  end;
  save-change(<wiki-user-change>, name, action, comment,
              authors: if (authenticated-user())
                         list(authenticated-user().user-name)
                       else
                         list(name)
                       end if);
  save(user);
  dump-data();
  user
end method save-user;

define generic rename-user
    (user :: <object>, new-name :: <string>, #key comment :: false-or(<string>))
 => ();

define method rename-user
    (name :: <string>, new-name :: <string>,
     #key comment :: false-or(<string>))
 => ()
  let user = find-user(name);
  if (user)
    rename-user(user, new-name, comment: comment)
  end if;
end method rename-user;

define method rename-user
    (user :: <wiki-user>, new-name :: <string>,
     #key comment :: false-or(<string>))
 => ()
  let comment = concatenate("was: ", user.user-name, ". ", comment | "");
  remove-key!(storage(<wiki-user>), user.user-name);
  user.user-name := new-name;
  storage(<wiki-user>)[new-name] := user;
  save-change(<wiki-user-change>, new-name, #"renaming", comment);
  save(user);
  dump-data();
end method rename-user;

// todo -- MAKE THREAD SAFE
define method remove-user
    (user :: <wiki-user>, #key comment :: <string> = "")
 => ()
  remove-key!(storage(<wiki-user>), user.user-name);
  let message = "Automatic change due to user removal.";
  for (group in groups-owned-by-user(user))
    group.group-owner := *admin-user*;
    save-change(<wiki-user-change>,
                user.user-name, #"remove-group-owner", message)
  end;
  for (group in user-groups(user))
    group.group-members := remove!(group.group-members, user);
    save-change(<wiki-user-change>,
                user.user-name, #"remove-group-member", message);
  end;
  save-change(<wiki-user-change>, user.user-name, #"removal", comment);
  dump-data();
end;


// pages

define constant $view-user-page
  = make(<wiki-dsp>, source: "view-user.dsp");

define constant $edit-user-page
  = make(<wiki-dsp>, source: "edit-user.dsp");

define constant $list-users-page
  = make(<wiki-dsp>, source: "list-users.dsp");

define constant $remove-user-page
  = make(<wiki-dsp>, source: "remove-user.dsp");

define constant $non-existing-user-page
  = make(<wiki-dsp>, source: "non-existing-user.dsp");

define constant $login-page
  = make(<wiki-dsp>, source: "login.dsp");

// actions

define method show-user (#key username)
  dynamic-bind (*user-username* = percent-decode(username),
                *user* = find-user(*user-username*))
    // This call to process-page feels hackish.  It's here specifically so that
    // *page-context* is bound, but we shouldn't have to worry about that!
    process-page(case
                   *user* => $view-user-page;
                   otherwise => $edit-user-page;
                 end);
  end;
end method show-user;

define method show-edit-user (#key username)
  dynamic-bind (*user-username* = percent-decode(username),
                *user* = find-user(*user-username*))
    respond-to-get(case
                     *user* => $edit-user-page;
                     otherwise => $non-existing-user-page;
                   end);
  end;
end method show-edit-user;

define method do-save-user (#key username :: <string>)
  with-query-values (username as new-username, password, email, comment)
    let errors = #();

    let username = percent-decode(trim(username));
    if (empty?(username))
      errors := add!(errors, #"username");
    end if;

    let user = find-user(username);
    if (user)
      // No password needed if user already logged in.
      if (password = "")
        password := #f;
      end if;
    else
      if (~ instance?(password, <string>) | password = "")
        errors := add!(errors, #"password");
      end if;
    end if;

    if (~ instance?(email, <string>) | email = "")
      errors := add!(errors, #"email");
    end if;

    if (user & new-username & new-username ~= username & new-username ~= "")
      if (find-user(new-username))
        errors := add!(errors, #"exists");
      else
        username := new-username;
      end if;
    end if;

    if (empty?(errors))
      save-user(username, password, email);
      redirect-to(find-user(username));
    else
      current-request().request-query-values["password"] := "";
      dynamic-bind (wf/*errors* = errors,
                    wf/*form* = current-request().request-query-values)
        respond-to(#"get", $edit-user-page);
      end;
    end if;
  end with-query-values;
end method do-save-user;

define method do-remove-user (#key username)
  let user = find-user(percent-decode(username));
  remove-user(user, comment: get-query-value("comment"));
  redirect-to(user);
end;

define method redirect-to-user-or (page :: <page>, #key username)
  if (*user*)
    respond-to(#"get", page);
  else
    redirect-to(user-permanent-link(percent-decode(username)));
  end if;
end;

define method show-remove-user (#key username :: <string>)
  dynamic-bind(*user* = find-user(percent-decode(username)))
    redirect-to-user-or($remove-user-page);
  end;
end;

// tags

define tag show-user-username in wiki (page :: <wiki-dsp>)
    ()
  output("%s", if (*user*)
                 escape-xml(*user*.user-name)
               elseif (wf/*form* & element(wf/*form*, "username", default: #f))
                 escape-xml(wf/*form*["username"])
               elseif (*user-username*)
                 *user-username*
               else
                 ""
               end if);
end;

define tag show-user-email in wiki (page :: <wiki-dsp>)
    ()
  output("%s", if (*user*)
                 escape-xml(*user*.user-email);
               elseif (wf/*form* & element(wf/*form*, "email", default: #f))
                 escape-xml(wf/*form*["email"]);
               else
                 ""
               end if);
end;

define tag show-user-permanent-link in wiki (page :: <wiki-dsp>)
    (use-change :: <boolean>)
  output("%s", if (use-change)
                 user-permanent-link(*change*.title);
               elseif (*user*)
                 permanent-link(*user*)
               else
                 ""
               end if);
end;


// body tags

define body tag list-users in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  let users = storage(<wiki-user>);
  if (users.size == 0)
    // todo -- quick hack.  replace wiki:list-users with dsp:do
    output("<li>No users</li>");
  else
    for (user in users)
      dynamic-bind(*user* = user)
        do-body();
      end;
    end for;
  end;
end tag list-users;

define body tag with-authenticated-user in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  dynamic-bind(*user* = authenticated-user())
    do-body();
  end;
end;

define body tag with-change-author in wiki
    (page :: <wiki-dsp>, do-body :: <function>)
    ()
  if (*change*)
    let user = find-user(*change*.authors[0]);
    if (user)
      dynamic-bind(*user* = user)
        do-body();
      end;
    end if;
  end if;
end;


// named methods

define named-method user-changed? in wiki (page :: <wiki-dsp>)  
  instance?(*change*, <wiki-user-change>);
end;

define named-method logged-in? in wiki
    (page :: <wiki-dsp>)
  authenticated-user() ~= #f
end;

define named-method admin? in wiki (page :: <wiki-dsp>)
  *user* & administrator?(*user*)
end;

define named-method user-group-names in wiki (page :: <wiki-dsp>)
  if (*user*)
    sort(map(group-name, user-groups(*user*)))
  else
    #[]
  end;
end;

define named-method group-names-owned-by-user in wiki (page :: <wiki-dsp>)
  if (*user*)
    sort(map(group-name, groups-owned-by-user(*user*)))
  else
    #[]
  end;
end;

define named-method can-modify-user?
    (page :: <wiki-dsp>)
  let user = authenticated-user();
  user & (administrator?(user) | user = *user*)
end;

