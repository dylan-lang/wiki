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


// url

define sideways method permanent-link
    (user :: <wiki-user>, #key escaped?, full?)
 => (url :: <url>)
  user-permanent-link(user.user-name);
end;

define method user-permanent-link
    (username :: <string>)
 => (uri :: <uri>)
  let location = wiki-url("/user/view/%s", username);
  transform-uris(request-url(current-request()), location, as: <url>);
end;

define sideways method redirect-to (user :: <wiki-user>)
  redirect-to(permanent-link(user));
end;


// methods

define method send-new-account-email
    (user :: <wiki-user>)
  let url = account-activation-url(user);
  // body contains "subject\n\n"...weird
  let body = format-to-string(
    "To: %s\nSubject: Confirmation for account %s on %s\n\n"
    "This message is to confirm the account '%s' you registered on %s.  "
    "Click the following URL to complete the registration process and  "
    "activate your new account: %s\n",
                              user.user-email, user.user-name, *site-name*,
                              user.user-name, *site-name*, url);

  // Try to send the message.
  // Retry once if we get 451, to work around grey listing.
  iterate loop (first? = #t)
    let handler <transient-smtp-error> = method (ex, next-handler)
                                           if (first? & ex.smtp-error-code = 451)
                                             loop(#f);
                                           else
                                             next-handler();
                                           end;
                                         end;
    send-smtp-message(host: *mail-host*,
                      port: *mail-port*,
                      recipients: list(user.user-email),
                      from: *admin-user*.user-email,
                      body: body);
    log-info("Email verification sent to %s for user %s",
             user.user-email, user.user-name);
  end;
end method send-new-account-email;

define method account-activation-url
    (user :: <wiki-user>)
 => (url :: <string>)
  let default = current-request().request-absolute-url;
  let prefix = iff(*wiki-url-prefix*.size = 0,
                   #(),
                   split(*wiki-url-prefix*, "/", remove-if-empty: #t));
  as(<string>,
     make(<url>,
          scheme: "http",
          host: default.uri-host,
          port: default.uri-port,
          path: concatenate(list(""),
                            prefix,
                            list("user", "activate", user.user-name,
                                 user.user-activation-key))))
end method account-activation-url;

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
end;

define method validate-password
    (password :: <string>) => (password :: <string>)
  if (password.size <= 3)
    error("A password of four or more characters is required.");
  end;
  password
end;

define method validate-email
    (email :: <string>) => (email :: <string>)
  // Just checking some basic syntax for now.  Will eventually send mail
  // to verify.
  let parts = split(email, '@');
  if (parts.size ~= 2
        | parts[0].size = 0
        | parts[1].size = 0
        | ~member?('.', parts[1]))
    error("Invalid email address syntax.");
  end;
  email
end;

/*
define method storage-type
    (type == <wiki-user>)
 => (type :: <type>)
  <string-table>
end;
*/


// todo -- MAKE THREAD SAFE
define method remove-user
    (user :: <wiki-user>, #key comment :: <string> = "")
 => ()
  remove-key!(storage(<wiki-user>), user.user-name);
  let message = "Automatic change due to user account removal.";
  for (group in groups-owned-by-user(user))
    group.group-owner := *admin-user*;
    save-change(<wiki-user-change>,
                user.user-name, $remove-group-owner, message)
  end;
  for (group in user-groups(user))
    group.group-members := remove!(group.group-members, user);
    save-change(<wiki-user-change>,
                user.user-name, $remove-group-member, message);
  end;
  save-change(<wiki-user-change>, user.user-name, $remove, comment);
  dump-data();
end;


//// List Users

define class <list-users-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <list-users-page>, #key)
  let pc = page-context();
  set-attribute(pc, "active-users",
                map(method (user)
                      table(<string-table>,
                            "name" => user.user-name,
                            "admin?" => user.administrator?)
                    end,
                    choose(user-activated?,
                           value-sequence(storage(<wiki-user>)))));
  let active-user = authenticated-user();
  set-attribute(pc, "active-user", active-user & active-user.user-name);
  next-method();
end;

define method respond-to-post
    (page :: <list-users-page>, #key)
  let user-name = percent-decode(get-query-value("user-name"));
  let user = find-user(user-name);
  if (user)
    respond-to-get(*view-user-page*, name: user-name);
  else
    add-field-error("user-name", "User %s not found.", user-name);
    next-method();
  end;
end method respond-to-post;

//// View User

define class <view-user-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <view-user-page>, #key name :: <string>)
  let name = percent-decode(name);
  let user = find-user(name);
  if (user)
    let pc = page-context();
    set-attribute(pc, "user-name", user.user-name);
    set-attribute(pc, "group-memberships",
                  sort(map(group-name, user-groups(user))));
    set-attribute(pc, "group-ownerships",
                  sort(map(group-name, groups-owned-by-user(user))));
    set-attribute(pc, "admin?", user.administrator?);
    let active-user = authenticated-user();
    set-attribute(pc, "user-email",
                  if (active-user & (active-user = user
                                       | administrator?(active-user)))
                    user.user-email
                  else
                    "private"
                  end);
    next-method();
  else
    // should only get here via a manually typed-in URL
    respond-to-get(*non-existing-user-page*, name: name);
  end;
end method respond-to-get;


//// Registration Page

// This is similar to Edit User except that the account MUST NOT exist yet.
//
define class <registration-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <registration-page>, #key)
  let active-user = authenticated-user();
  if (active-user)
    add-page-note("You are already logged in.  Log out to register a new account.");
    respond-to-get(*view-user-page*, name: active-user.user-name);
  else
    next-method();
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <registration-page>, #key)
  let active-user = authenticated-user();
  if (active-user)
    add-page-note("You are already logged in.  Log out to register a new account.");
    respond-to-get(*view-user-page*, name: active-user.user-name);
  else
    let new-name = validate-form-field("user-name", validate-user-name);
    if (find-user(new-name))
      add-field-error("user-name", "A user named %s already exists.", new-name);
    end;
    let email = validate-form-field("email", validate-email);
    let password = validate-form-field("password", validate-password);
    let password2 = validate-form-field("password2", validate-password);
    if (password ~= password2)
      add-field-error("password2", "Passwords don't match.");
    end;
    let user = #f;
    if (~page-has-errors?())
      user := make(<wiki-user>,
                   name: new-name,
                   password: password,
                   email: email,
                   administrator?: #f);
      block ()
        send-new-account-email(user);
      exception (ex :: <serious-condition>)
        log-error("Email failed to %s (for %s): %s",
                  user.user-email, user.user-name, ex);
        add-field-error("email",
                        "Unable to send confirmation email to this address.");
      end;
    end;
    if (page-has-errors?())
      next-method();
    else
      save(user);
      save-change(<wiki-user-change>, new-name, $create, "User created",
                  authors: list(new-name));
      add-page-note("User %s created.  Please follow the link in the confirmation "
                    "email sent to %s to activate the account.",
                    new-name, email);
      dump-data();
      respond-to-get(*view-user-page*, name: user.user-name);
    end if;
  end if;    
end method respond-to-post;


//// User activation

// Responder for the URL sent in confirmation email to activate the account.

define function respond-to-user-activation-request
    (#key name :: <string>, key :: <string>)
  let name = percent-decode(name);
  let user = find-user(name);
  if (user)
    if (~user.user-activated?)
      let key = percent-decode(key);
      if (key = user.user-activation-key)
        user.user-activated? := #t;
        save-change(<wiki-user-change>, name, $activate, "Account activated",
                    authors: list(name));
      end;
    end;
    if (user.user-activated?)
      add-page-note("User %s activated.", name);
    else
      add-page-error("User activation failed.");
    end;
  else
    add-page-error("User %s not found.", name);
  end;
  respond-to-get(*view-user-page*, name: name);
end function respond-to-user-activation-request;

//// Edit User

// This is similar to <registration-page> except the user MUST exist.
//
define class <edit-user-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <edit-user-page>, #key name :: <string>)
  let name = percent-decode(name);
  let user = find-user(name);
  let active-user = authenticated-user();
  let pc = page-context();
  set-attribute(pc, "user-name", name);
  set-attribute(pc, "button-text", iff(user, "Save", "Create"));
  set-attribute(pc, "active-user-is-admin?",
                active-user & administrator?(active-user));
  if (user & (active-user = user | (active-user & administrator?(active-user))))
    set-attribute(pc, "password", user.user-password);
    set-attribute(pc, "email", user.user-email);
    set-attribute(pc, "admin?", user.administrator?);
    next-method();
  else
    add-page-error("You don't have permission to change this user.");
    respond-to-get(*view-user-page*, name: name);
  end;
end method respond-to-get;

define method respond-to-post
    (page :: <edit-user-page>, #key name :: <string>)
  let name = percent-decode(name);
  let user = find-user(name);
  let active-user = authenticated-user();
  if (user & (~active-user | ~(active-user = user | active-user.administrator?)))
    add-page-error("You don't have permission to change this user.");
    respond-to-get(*view-user-page*, name: name);
  else
    let new-name = validate-form-field("user-name", validate-user-name);
    if (name ~= new-name & find-user(new-name))
      add-field-error("user-name", "A user named %s already exists.", new-name);
    end;
    let email = validate-form-field("email", validate-email);
    let password = validate-form-field("password", validate-password);
    let admin? = get-query-value("admin?");
    if (page-has-errors?())
      next-method();  // redisplay page with errors
    else
      if (user)
        let comments = make(<stretchy-vector>);
        if (user.user-name ~= new-name)
          remove-key!(storage(<wiki-user>), name);  // old name
          user.user-name := new-name;
          add!(comments, format-to-string("renamed to %s", new-name));
        end;
        if (user.user-password ~= password)
          user.user-password := password;
          add!(comments, "password changed");
        end;
        if (user.user-email ~= email)
          user.user-email := email;
          add!(comments, "email changed");
        end;
        if (user.administrator? ~= admin?)
          user.administrator? := admin?;
          add!(comments, format-to-string("%s admin status",
                                          iff(admin?, "added", "removed")));
        end;
        save(user);
        save-change(<wiki-user-change>, name, $edit, join(comments, ", "));
        add-page-note("User %s updated.", new-name);
      else
        // new user
        user := make(<wiki-user>,
                     name: new-name,
                     password: password,
                     email: email,
                     administrator?: admin?);
        save(user);
        save-change(<wiki-user-change>, new-name, $create, "User created");
        add-page-note("User %s created.", new-name);
        login(realm: *wiki-realm*);
      end;
      dump-data();
      redirect-to(user);
    end if;
  end if;    
end method respond-to-post;

define method do-remove-user (#key username)
  let user = find-user(percent-decode(username));
  remove-user(user, comment: get-query-value("comment"));
  redirect-to(user);
end;

define method redirect-to-user-or
    (page :: <wiki-dsp>, #key username)
  if (*user*)
    respond-to-get(page);
  else
    redirect-to(user-permanent-link(percent-decode(username)));
  end if;
end;

define method show-remove-user (#key username :: <string>)
  dynamic-bind(*user* = find-user(percent-decode(username)))
    redirect-to-user-or(*remove-user-page*);
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
  if (*user*)
    output("%s", permanent-link(*user*))
  end;
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

// named methods

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
  user & (administrator?(user)
            | begin
                let user-name = get-attribute(page-context(), "user-name");
                user-name & (find-user(percent-decode(user-name)) = user)
              end)
end;

