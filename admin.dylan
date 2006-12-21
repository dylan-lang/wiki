module: wiki

define method respond-to-post
 (page :: <admin-page>, request :: <request>, response :: <response>)
  if (logged-in?(request))
    let action = as(<symbol>, get-query-value("action"));
    if (any?(method(x) action = x end, current-user().access))
      select (action)
        #"undo" => undo(get-query-value("title"));
        #"rename" => rename-page(get-query-value("oldtitle"), get-query-value("title"));
        #"remove" => remove-page(get-query-value("title"));
        #"change-privileges" => change-privileges();
        #"remove-user" => remove-user(get-query-value("username"));
      end;
    end;
  end;
  respond-to-get(page, request, response);
end;

define method remove-user (username)
  remove-key!(storage(<user>), username);
end;
define method change-privileges ()
  //this is evil and should be done better!
  for (user in storage(<user>))
    for (privilege in $privileges)
      let was = any?(method(x) x = privilege end, user.access);
      let should-be = get-query-value(concatenate(user.username, ":", as(<string>, privilege)));
      if (should-be & was = #f)
        user.access := pair(privilege, user.access);
      end;
      if (was & should-be = #f)
        user.access := remove!(user.access, privilege);
      end;
    end;
  end;
end;
define method remove-page (title)
  save(make(<wiki-page-diff>,
            content: "",
            comment: "removed",
            page-version: 0,
            wiki-page-content: storage(<wiki-page-content>)[title]));
  remove-key!(storage(<wiki-page-content>), title);
end;

define method rename-page (old-title, new-title)
  let page = find-page(old-title);
  page.page-title := new-title;
  storage(<wiki-page-content>)[new-title] := page;
  remove-key!(storage(<wiki-page-content>), old-title);
  //fix backlinks
  let comment = concatenate("Page ", old-title, " has been moved to ", new-title, ".");
  for (ele in find-backlinks(old-title))
    let new-version = make(<wiki-page-diff>,
                           page-version: ele.revisions.size + 1,
                           content: substring-replace(latest-text(ele),
                                                      concatenate("[[", old-title, "]]"),
                                                      concatenate("[[", new-title, "]]")),
                           comment: comment,
                           wiki-page-content: ele);
    add!(ele.revisions, new-version);
  end;
  save(make(<wiki-page-diff>,
            content: "",
            comment: comment,
            page-version: page.revisions.size,
            wiki-page-content: page));
end;

//undo last change
define method undo (title)
  let page = find-page(title);
  if (page)
    let previous-version = page.revisions[page.revisions.size - 2];
    save-page(title, previous-version.content, comment: "reverted to previous version");
  end;
end;

define body tag privilege in wiki
  (page :: <wiki-page>, response :: <response>, do-body :: <function>)
  (value :: <string>)
  let user = *user* | current-user();
  if (user & any?(method(x) x = as(<symbol>, value) end, user.access))
    do-body()
  end;
end;


define named-method privilege? in wiki
  (page :: <wiki-page>, request :: <request>)
  *user* & *privilege* & any?(method(x) x = *privilege* end, *user*.access)
end;

define constant $privileges = #(#"remove", #"rename", #"undo", #"change-privileges", #"remove-user");

define thread variable *privilege* = #f;

define body tag show-privileges in wiki
  (page :: <wiki-page>, response :: <response>, do-body :: <function>)
  ()
  for (privilege in $privileges)
    dynamic-bind(*privilege* = privilege)
      do-body()
    end;
  end;
end;

define thread variable *user* = #f;

define tag show-privilege in wiki
  (page :: <wiki-page>, response :: <response>)
  ()
  write(output-stream(response), as(<string>, *privilege*));
end;


define body tag show-users in wiki
  (page :: <wiki-page>, response :: <response>, do-body :: <function>)
  ()
  for (user in sort(key-sequence(storage(<user>))))
    dynamic-bind(*user* = storage(<user>)[user])
      do-body()
    end;
  end;
end;

define tag show-user in wiki
  (page :: <wiki-page>, response :: <response>)
  ()
  write(output-stream(response), *user*.username);
end;

define body tag show-recent-changes in wiki
  (page :: <wiki-page>, response :: <response>, do-body :: <function>)
  (count :: <string>)
  let count = string-to-integer(count);
  let done = make(<list>);
  block(ret)
    for (change in reverse(storage(<wiki-page-diff>)))
      if (count = size(done))
        ret()
      end;
      unless (any?(method(x) x = change.wiki-page-content end, done))
        dynamic-bind(*change* = change)
          do-body();
          done := pair(change.wiki-page-content, done);
        end;
      end;
    end;
  end;
end;

