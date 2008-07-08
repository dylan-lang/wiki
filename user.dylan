module: wiki

define thread variable *user-username* = #f;


// class

define constant <wiki-user> = <user>;

define object-test (user) in wiki end;

/*
define action-tests
 (add-user, edit-user, remove-user, list-users)
in wiki end;
*/

define error-tests
 (username, password, email)
in wiki end;


// verbs

*change-verbs*[<wiki-user-change>] :=
  table(#"edit" => "edited",
	#"removal" => "removed",
	#"add" => "registered");


// url

define method permanent-link (user :: <wiki-user>, #key escaped?, full?)
 => (url :: <url>);
  user-permanent-link(user.username);
end;

define method user-permanent-link (username :: <string>) => (url :: <url>);
  let location = parse-url("/users/");
  last(location.uri-path) := username;
  transform-uris(*wiki-url*, location, as: <url>);
end;

define method redirect-to (user :: <wiki-user>)
  redirect-to(permanent-link(user));
end;


// methods

define method save-user
    (user-username :: <string>, user-password :: false-or(<string>), user-email :: <string>,
     #key comment :: <string> = "")
 => ();
  let user :: false-or(<wiki-user>) = find-user(user-username);
  let action :: <symbol> = #"edit";
  if (user)
    if (password)
      user.password := user-password;
    end if;
    user.email := user-email;
  else
    user := make(<wiki-user>, username: user-username,
			      password: user-password,
			      email: user-email);
    action := #"add";
  end;
  save-change(<wiki-user-change>, user-username, action,
				  comment, authors: if (authenticated-user())
				      list(authenticated-user().username)
				    else
				      list(user-username)
                                    end if);
  save(user);
  dump-data();
end;

define method rename-user
    (username :: <string>, new-username :: <string>,
     #key comment :: <string> = "")
 => ();
  let user = find-user(username);
  if (user)
    rename-user(user, new-username, comment: comment)
  end if;
end;

define method rename-user
    (user :: <wiki-user>, new-username :: <string>,
     #key comment :: <string> = "")
 => ();
  let comment = concatenate("was: ", user.username, ". ", comment);
  remove-key!(storage(<wiki-user>), user.username);
  user.username := new-username;
  storage(<wiki-user>)[new-username] := user;
  save-change(<wiki-user-change>, new-username, #"renaming", comment);
  save(user);
  dump-data();
end;

define method remove-user
    (user :: <wiki-user>,
     #key comment :: <string> = "")
 => ();
  save-change(<wiki-user-change>, user.username, #"removal", comment);
  remove-key!(storage(<wiki-user>), user.username);
  dump-data();
end;


// pages

define variable *view-user-page* =
  make(<wiki-dsp>, source: "view-user.dsp");

define variable *edit-user-page* = 
  make(<wiki-dsp>, source: "edit-user.dsp");

define variable *list-users-page* =
  make(<wiki-dsp>, source: "list-users.dsp");

define variable *remove-user-page* =
  make(<wiki-dsp>, source: "remove-user.dsp");

define variable *non-existing-user-page* =
  make(<wiki-dsp>, source: "non-existing-user.dsp");


// actions

define method do-users ()
  case
    get-query-value("go") =>
      redirect-to(user-permanent-link(get-query-value("query")));
    otherwise =>
      process-page(*list-users-page*);
  end;
end;

define method bind-user (#key username)
  *user* := find-user(percent-decode(username));
end;

define method show-user (#key username)
  dynamic-bind (*user-username* = percent-decode(username))
    respond-to(#"get", case
	                 *user* => *view-user-page*;
			 otherwise => *edit-user-page*;
                       end case);
  end;
end method show-user;

define method show-edit-user (#key username)
  dynamic-bind (*user-username* = percent-decode(username))
    respond-to(#"get", case
	                 *user* => *edit-user-page*;
			 otherwise => *non-existing-user-page*;
                       end case);
  end;
end method show-edit-user;

define method do-save-user (#key username)
  let username = percent-decode(username);
  let new-username = get-query-value("username");
  let password = get-query-value("password");
  let email = get-query-value("email");
  let user = find-user(username);  
  let errors = #();
  
  if (~ instance?(username, <string>) | username = "" |
      (new-username & (~ instance?(new-username, <string>) | new-username = "")))
    errors := add!(errors, #"username");
  end if;

  if (user)
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
      rename-user(user, new-username, comment: comment);
      username := new-username;
    end if;
  end if;

  if (empty?(errors))
    save-user(username, password, email);
    redirect-to(find-user(username));
  else
    current-request().request-query-values["password"] := "";
    dynamic-bind (*errors* = errors, *form* = current-request().request-query-values)
      respond-to(#"get", *edit-user-page*);
    end;
  end if;
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

define constant show-remove-user =
  curry(redirect-to-user-or, *remove-user-page*);


// tags

define tag show-user-username in wiki (page :: <wiki-dsp>)
 ()
  output("%s", if (*user*)
      escape-xml(*user*.username)
    elseif (*form* & element(*form*, "username", default: #f))
      escape-xml(*form*["username"])
    elseif (*user-username*)
      *user-username*
    else "" end if);
end;

define tag show-user-email in wiki (page :: <wiki-dsp>)
 ()
  output("%s", if (*user*)
    escape-xml(*user*.email);
  elseif (*form* & element(*form*, "email", default: #f))
    escape-xml(*form*["email"]);
  else "" end if);
end;

define tag show-user-permanent-link in wiki (page :: <wiki-dsp>)
 (use-change :: <boolean>)
  output("%s", if (use-change)
      user-permanent-link(*change*.title);
    elseif (*user*)
      permanent-link(*user*)
    else "" end if);
end;


// body tags

define body tag list-users in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  for (user in storage(<wiki-user>))
    dynamic-bind(*user* = user)
      do-body();
    end;
  end for;
end;

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
