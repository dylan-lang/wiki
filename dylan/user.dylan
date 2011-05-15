Module: %wiki
Synopsis: User account management.


// User data is stored in a separate git repository so that it can
// be maintained under stricter security than other data.

define thread variable *user-username* = #f;

define thread variable *authenticated-user* = #f;

// The default "realm" value passed in the WWW-Authenticate header.
//
define variable *default-authentication-realm* :: <string> = "koala";

// Because clients (browsers) continue to send the Authentication header
// once an authentication has been accepted (at least until the browser
// is restarted, it seems) we need to keep track of the fact that a user
// has logged out by storing the auth values here.
//
// Also, note that if the server restarts and browsers resend the auth,
// the user is suddenly logged in again.  Yikes.
//
define variable *ignore-authorizations* = list();
define variable *ignore-logins* = list();


// TODO: options to specify which fields are visible to whom.  (acls)
//
define class <wiki-user> (<wiki-object>)

  slot user-name :: <string>,
    required-init-keyword: name:;

  slot %user-real-name :: false-or(<string>) = #f,
    init-keyword: real-name:;

  slot user-password :: <string>,
    required-init-keyword: password:;

  slot user-email :: <string>,
    required-init-keyword: email:;

  slot administrator? :: <boolean> = #f,
    init-keyword: administrator?:;

  slot user-activation-key :: <string>,
    init-keyword: activation-key:;

  slot user-activated? :: <boolean> = #f,
    init-keyword: activated?:;
end class <wiki-user>;

define method initialize
    (user :: <wiki-user>, #key)
  next-method();
  if (~slot-initialized?(user, user-activation-key))
    user.user-activation-key := generate-activation-key(user);
  end;
end;

define generic user-real-name
    (user :: <wiki-user>) => (real-name :: <string>);

define method user-real-name
    (user :: <wiki-user>) => (real-name :: <string>)
  user.%user-real-name | user.user-name
end;

define function find-user
    (name :: <string>, #key default)
 => (user :: false-or(<wiki-user>))
  element(*users*, as-lowercase(name), default: default)
end;

// This is set when the config file is loaded.
define variable *admin-user* :: false-or(<wiki-user>) = #f;

define method generate-activation-key
    (user :: <wiki-user>)
 => (key :: <string>)
  // temporary.  should be more secure.
  base64-encode(concatenate(user.user-name, user.user-email))
end;

// What's this for?
define method as (class == <string>, user :: <wiki-user>)
 => (result :: <string>)
  user.user-name;
end;

define function authenticated-user ()
 => (user :: false-or(<wiki-user>))
  authenticate();
  *authenticated-user*
end;

define method \=
    (user1 :: <wiki-user>, user2 :: <wiki-user>)
 => (equal? :: <boolean>)
  user1.user-name = user2.user-name
end;

define method login
    (#key realm :: false-or(<string>))
  let redirect-url = get-query-value("redirect");
  let user = check-authorization();
  if (~user)
    require-authorization(realm: realm);
  elseif (member?(user, *ignore-authorizations*, test: \=) &
          member?(user, *ignore-logins*, test: \=))
    *ignore-authorizations* := remove!(*ignore-authorizations*, user);
    require-authorization(realm: realm);
  elseif (~member?(user, *ignore-authorizations*, test: \=) &
          member?(user, *ignore-logins*, test: \=))
    *ignore-logins* := remove!(*ignore-logins*, user);
    redirect-url & redirect-to(redirect-url);
  else
    redirect-url & redirect-to(redirect-url);
  end if;
end;

define function logout ()
  let user = check-authorization();
  if (user)
    *authenticated-user* := #f;
    *ignore-authorizations* :=
      add!(*ignore-authorizations*, user);
    *ignore-logins* :=
      add!(*ignore-logins*, user);
  end if;
  let redirect-url = get-query-value("redirect");
  redirect-url & redirect-to(redirect-url);
end;

// TODO: this should signal an error, which we can handle in one place
//       and redirect to a login page.
define function check-authorization
    () => (user :: false-or(<wiki-user>))
  let authorization = get-header(current-request(), "Authorization", parsed: #t);
  if (authorization)
    let name = head(authorization);
    let pass = tail(authorization);
    let user = find-user(name);
    if (user
          & user.user-activated?
          & user.user-password = pass)
      user
    end
  end
end function check-authorization;

define function authenticate
    () => (user :: false-or(<wiki-user>))
  let user = check-authorization();
  if (user)
    *authenticated-user*
      := if (~member?(user, *ignore-authorizations*, test: \=)
               & ~member?(user, *ignore-logins*, test: \=))
           user
         end;
  end
end function authenticate;

define function require-authorization
    (#key realm :: false-or(<string>))
  let realm = realm | *default-authentication-realm*;
  let headers = current-response().raw-headers;
  set-header(headers, "WWW-Authenticate", concatenate("Basic realm=\"", realm, "\""));
  unauthorized-error(headers: headers);
end;

define wf/object-test (user) in wiki end;

define wf/error-tests (username, password, email) in wiki end;


define sideways method permanent-link
    (user :: <wiki-user>) => (url :: <url>)
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
  elseif (~regex-search(compile-regex("^[A-Za-z0-9_-]+$"), name))
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



//// List Users

define class <list-users-page> (<wiki-dsp>)
end;

define method respond-to-get
    (page :: <list-users-page>, #key)
  let pc = page-context();
  set-attribute(pc, "active-users",
                map(method (user)
                      make-table(<string-table>,
                                 "name" => user.user-name,
                                 "admin?" => user.administrator?)
                    end,
                    choose(user-activated?,
                           load-all(*storage*, <wiki-user>))));
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
    add-field-error("user-name", "User '%s' not found.", user-name);
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
    let email = validate-form-field("email", validate-email);
    let password = validate-form-field("password", validate-password);
    let password2 = validate-form-field("password2", validate-password);
    if (password ~= password2)
      add-field-error("password2", "Passwords don't match.");
    end;

    // Hold this user name, by adding it to *users*, while email is being sent.
    // It will be removed if there are any further errors.
    let user
      = if (find-user(new-name))
          add-field-error("user-name", "A user named %s already exists.", new-name);
          #f
        else
          with-lock ($user-lock)
            // check again with lock held
            if (find-user(new-name))
              add-field-error("user-name", "A user named %s already exists.", new-name);
              #f
            else
              *users*[as-lowercase(new-name)] := make(<wiki-user>,
                                                      name: new-name,
                                                      real-name: #f,  // TODO
                                                      password: password,
                                                      email: email,
                                                      administrator?: #f);
            end;
          end;
        end if;
    if (user)
      // Hannes commented in IRC 2009-06-12: this will probably block
      // the responder thread while the mail is being delivered; and
      // to circumvent greylisting you've to wait 5-10 minutes between
      // the first and second attempt. I'd suggest a separate thread
      // which cares about email notifications, and the responder
      // thread to push a message to a queue which is popped by the
      // email thread...
      block ()
        send-new-account-email(user);
      exception (ex :: <serious-condition>)
        log-error("Email failed to %s (for %s): %s",
                  user.user-email, user.user-name, ex);
        add-field-error("email",
                        "Unable to send confirmation email to this address.");
      end;
    end;

    // Check again for errors since sending mail may have failed.
    if (page-has-errors?())
      with-lock($user-lock)
        remove-key!(*users*, as-lowercase(new-name));
      end;
      next-method();
    else
      block ()
        store(*storage*, user, user, "New user created",
              standard-meta-data(user, "create"));
        with-lock ($user-lock)
          *users*[as-lowercase(user.user-name)] := user;
        end;
        add-page-note("User %s created.  Please follow the link in the confirmation "
                      "email sent to %s to activate the account.",
                      new-name, email);
        respond-to-get(*view-user-page*, name: user.user-name);
      exception (ex :: <serious-condition>)
        with-lock($user-lock)
          remove-key!(*users*, as-lowercase(new-name));
        end;
      end;
    end if;
  end if;    
end method respond-to-post;


//// User activation/deactivation

// Responder for the URL sent in confirmation email to activate the account.
//
define function respond-to-user-activation-request
    (#key name :: <string>, key :: <string>)
  let name = percent-decode(name);
  let user = find-user(name);
  if (user)
    if (~user.user-activated?)
      let key = percent-decode(key);
      if (key = user.user-activation-key)
        user.user-activated? := #t;
        store(*storage*, user, *admin-user*, "Account activated",
              standard-meta-data(user, "activate"));
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

define class <deactivate-user-page> (<wiki-dsp>)
end;

define method respond-to-get
    (dsp :: <deactivate-user-page>, #key name :: <string>)
  dynamic-bind (*user* = find-user(name))
    next-method();
  end;
end;

define method respond-to-post
    (dsp :: <deactivate-user-page>, #key name :: <string>)
  dynamic-bind (*user* = find-user(name))
    let author = authenticated-user();
    if (author
        & (author = *user* | author.administrator?)
        & (*user* ~= *admin-user*))
      let comment = get-query-value("comment") | "Deactivated";
      store(*storage*, *user*, author, comment,
            standard-meta-data(*user*, "deactivate"));
      *user*.user-activated? := #f;
      add-page-note("User '%s' deactivated", *user*.user-name);
      respond-to-get(*list-users-page*);
    else
      add-page-error("You don't have permission to deactivate this user.");
      respond-to-get(*view-user-page*, name: name);
    end;
  end;
end method respond-to-post;


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
          let comment = sformat("Rename to %s", new-name);
          rename-user(user, new-name, comment);
          add!(comments, comment);
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
        store(*storage*, user, active-user, join(comments, ", "),
              standard-meta-data(user, "edit"));
        add-page-note("User %s updated.", new-name);
      else
        // new user
        user := make(<wiki-user>,
                     name: new-name,
                     password: password,
                     email: email,
                     administrator?: admin?);
        store(*storage*, user, active-user, "User created",
              standard-meta-data(user, "create"));
        with-lock ($user-lock)
          *users*[as-lowercase(new-name)] := user;
        end;
        add-page-note("User %s created.", new-name);
        login(realm: *wiki-realm*);
      end;
      redirect-to(user);
    end if;
  end if;    
end method respond-to-post;

define function rename-user
    (user :: <wiki-user>, new-name :: <string>, comment :: <string>)
 => ()
  let author = authenticated-user();
  let revision = rename(*storage*, user, new-name, author, comment,
                        standard-meta-data(user, "rename"));
  let old-name = user.user-name;
  with-lock ($user-lock)
    remove-key!(*users*, as-lowercase(old-name));
    *users*[as-lowercase(new-name)] := user;
  end;
  user.user-name := new-name;
  // user.user-revision := revision;
end function rename-user;

define method redirect-to-user-or
    (page :: <wiki-dsp>, #key username)
  if (*user*)
    respond-to-get(page);
  else
    redirect-to(user-permanent-link(percent-decode(username)));
  end if;
end;


// tags

define tag show-user-username in wiki (page :: <wiki-dsp>)
    ()
  output("%s", (*user* & escape-xml(*user*.user-name))
               | get-query-value("username")
               | *user-username*
               | "");
end;

define tag show-user-email in wiki (page :: <wiki-dsp>)
    ()
  output("%s", (*user* & escape-xml(*user*.user-email))
               | get-query-value("email")
               | "");
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
  if (*users*.size == 0)
    // todo -- quick hack.  replace wiki:list-users with dsp:do
    output("<li>No users</li>");
  else
    for (user in *users*)
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


define tag show-login-url in wiki (page :: <dylan-server-page>)
    (redirect :: type-union(<string>, <boolean>), current :: <boolean>)
  let url = parse-url("/login");
  if (redirect)
    url.uri-query["redirect"] := if (current) 
                                   build-uri(request-url(current-request()))
                                 else 
                                   redirect
                                 end;
  end if;
  output("%s", url);
end;

define tag show-logout-url in wiki (page :: <dylan-server-page>)
    (redirect :: type-union(<string>, <boolean>), current :: <boolean>)
  let url = parse-url("/logout");
  if (redirect)
    url.uri-query["redirect"] := if (current) 
                                   build-uri(request-url(current-request())) 
                                 else
                                   redirect
                                 end;
  end if;
  output("%s", url);
end;


define named-method authenticated? in wiki (page :: <dylan-server-page>)
  authenticated-user()
end;


