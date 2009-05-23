Module: wiki-internal


define sideways method process-config-element
    (server :: <http-server>, node :: xml/<element>, name == #"wiki")
  // set the content-directory
  process-config-element(server, node, #"web-framework");
  local method child-node-named (name)
          block (return)
            for (child in xml/node-children(node))
              if (xml/name(child) = name)
                return(child);
              end;
            end;
          end;
        end;
  let admin-elem = child-node-named(#"administrator");
  let username = admin-elem & get-attr(admin-elem, #"username");
  let password = admin-elem & get-attr(admin-elem, #"password");
  let email = admin-elem & get-attr(admin-elem, #"email");
  if (~(username & password & email))
    error("The <administrator> element must be specified in the config file "
          "with a username, password, and email.");
  elseif (~find-user(username))
    let user = make(<wiki-user>,
                    name: username,
                    password: password,
                    email: email,
                    administrator?: #t);
    save(user);
    dump-data();
    *admin-user* := user;
  end;
end method process-config-element;

define constant $wiki-http-server = make(<http-server>);


// There is method to this madness....  In general a GET generates a "view"
// or "confirm" page and a POST actually performs the operation, such as modify,
// create, edit, or delete.  The same basic scheme is used for each type of
// object: pages, users, and groups.  Here's the example for groups:
//   GET  /groups                => list groups
//   GET  /groups/<name>         => view group
//   POST /groups/<name>         => 404
//   GET  /groups/<name>/edit    => display "edit group" form
//   POST /groups/<name>/edit    => save group from form fields
//   GET  /groups/<name>/remove  => display "remove group" form
//   POST /groups/<name>/remove  => remove group
//   ...
// In most cases a single URL points to an instance of <wiki-dsp> for both
// GET and POST, and the methods for respond-to-get and respond-to-post
// handle the logic for the given HTTP request method.

define url-map on $wiki-http-server
  url wiki-url("/")
    action get () => $main-page;

  url wiki-url("/login")
    action (get, post) () => curry(login, realm: "dylan-wiki");

  url wiki-url("/logout")
    action (get, post) () => logout;

  url wiki-url("/recent-changes")
    action get () => $recent-changes-page,
    action get ("^feed/?$") => do-feed;

  url wiki-url("/users")
    action get () =>
      $list-users-page,
    action post () =>
      method ()
        redirect-to(user-permanent-link(get-query-value("user-name")))
      end,
    action get ("^(?P<username>[^/]+)/?$") =>
      show-user,
    action get ("^(?P<username>[^/]+)/edit$") =>
      show-edit-user,
    action post ("^(?P<username>[^/]+)$") =>
      do-save-user,
    action get ("^(?P<username>[^/]+)/remove$") =>
      show-remove-user,
    action post ("^(?P<username>[^/]+)/remove$") =>
      do-remove-user;

  url wiki-url("/register")
    // For now the users page gives a way to create an account.
    // Eventually the registration page should be more specialized.
    action get () => $list-users-page;

  url wiki-url("/pages")
    action get () => do-pages,
    action get ("^(?P<title>[^/]+)/?$") =>
      show-page,
    action get ("^(?P<title>[^/]+)/edit$") =>
      $edit-page-page,
    action post ("^(?P<title>[^/]+)(/(edit)?)?$") =>
      $edit-page-page,
    action get ("^(?P<title>[^/]+)/remove$") =>
      show-remove-page,
    action (delete, post) ("^(?P<title>[^/]+)/remove$") =>
      do-remove-page,
    // versions
    action get ("^(?P<title>[^/]+)/versions$") => 
      show-page-versions,
    action get ("^(?P<title>[^/]+)/versions/(?P<version>\\d+)$") =>
      show-page,
    action get ("^(?P<title>[^/]+)/versions/(?P<a>\\d+)/diff(/(?P<b>\\d+))?$") => 
      show-page-versions-differences,
    // connections
    action get ("^(?P<title>[^/]+)/connections$") => 
      $connections-page,
    // authors
    action get ("^(?P<title>[^/]+)/authors$") =>
      show-page-authors,
    // access
    action (get, post) ("^(?P<title>[^/]+)/access") =>
      $edit-access-page;

  url wiki-url("/groups")
    action (get, post) () =>
      $list-groups-page,
    action get ("^(?P<name>[^/]+)/?$") =>
      $view-group-page,
    action (get, post) ("^(?P<name>[^/]+)/edit$") =>
      $edit-group-page,
    action (get, post) ("^(?P<name>[^/]+)/remove$") =>
      $remove-group-page,
    // members
    action (get, post) ("^(?P<name>[^/]+)/members$") =>
      $edit-group-members-page;

/***** We'll use Google or Yahoo custom search, at least for a while
  url wiki-url("/search")
    action (get, post) () => $search-page;
*/

end url-map;

define function restore-from-text-files
    () => (num-page-revs)
  let cwd = locator-directory(as(<file-locator>, application-filename()));
  let wikidata = subdirectory-locator(cwd, "wikidata");
  let page-data = make(<stretchy-vector>);
  local method gather-page-data (directory, filename, type)
          // look for "page-<page-num>-<rev-num>.props"
          let parts = split(filename, '.');
          if (type = #"file" & parts.size = 2 & parts[1] = "props")
            let parts = split(parts[0], '-');
            if (parts.size = 3 & parts[0] = "page")
              let page-num = string-to-integer(parts[1]);
              let rev-num = string-to-integer(parts[2]);
              add!(page-data, pair(page-num, rev-num));
            end;
          end;
        end;
  local method less? (pd1, pd2)
          pd1.head < pd2.head | (pd1.head = pd2.head & pd1.tail < pd2.tail)
        end;
  local method page-locator (page-num, rev-num, extension)
          let filename = format-to-string("page-%d-%d.%s",
                                          page-num, rev-num, extension);
          merge-locators(as(<file-locator>, filename), wikidata)
        end;
  local method parse-line (stream)
          // e.g. "author: hannes"
          let line = read-line(stream);
          let parts = split(line, ':', count: 2);
          copy-sequence(parts[1], start: min(parts[1].size, 1))
        end;
  // Load users in this format:
  // username
  // password
  // email
  // <blank line>
  let user-locator = merge-locators(as(<file-locator>, "users.txt"), wikidata);
  with-open-file(stream = user-locator)
    let user-count = 0;
    block ()
      while (#t)
        let username = read-line(stream);
        let password = read-line(stream);
        let email = read-line(stream);
        let user = make(<wiki-user>,
                        name: username,
                        password: password,
                        email: email,
                        administrator?: #f);
        save(user);
        inc!(user-count);
        assert(empty?(read-line(stream)));
      end;
    exception (ex :: <end-of-stream-error>)
      // done
    end;
  end;
  do-directory(gather-page-data, wikidata);
  page-data := sort(page-data, test: less?);
  let administrator = find-user("administrator");
  let previous-page-num = #f;
  for (pd in page-data)
    let page-num = pd.head;
    let rev-num = pd.tail;
    with-open-file(stream = page-locator(page-num, rev-num, "props"))
      let title = parse-line(stream);
      let author = find-user(parse-line(stream)) | administrator;
      // as-iso8601-string and make(<date>, iso8601-string ...) are not inverses??
      let timestamp = make(<date>,
                           iso8601-string: choose(method(x)
                                                    ~member?(x, "-:")
                                                  end,
                                                  parse-line(stream)));
      let comment = parse-line(stream);
      let action = #"edit";
      let page = find-page(title);
      if (~page)
        page := make(<wiki-page>,
                     title: title,
                     owner: author);
        action := #"add";
      end;
      let tags = #[];
      let content = file-contents(page-locator(page-num, rev-num, "content"));
      save-page-internal(page, content, comment, tags, author, action);
    end;
  end for;
  dump-data();
  page-data.size
end function restore-from-text-files;

/*
The conversion procedure probably is like this:

* Run the modified old wiki code, which will write out all the wiki
  pages to text files.
* BACKUP THE WIKI DATABASE!
* Run the new wiki code briefly, just so it can read in the config
  file and create the administrator user.  Create some user accounts.
  The next step will use these if it finds them.  Shut down the wiki.
* Run the new wiki code again with the --restore command-line argument.
  Be sure the wikidata directory is in the same directory as the wiki
  executable.
*/
define function main
    ()
  if (member?("--restore", application-arguments(), test: \=))
    // need to handle the --config argument here so the content directory is set.
    // copied from koala-main.  not intended to be pretty.
    let parser = *argument-list-parser*;
    parse-arguments(parser, application-arguments());
    let config-file = option-value-by-long-name(parser, "config");
    if (config-file)
      // we just cons up a server here because all we care about is that
      // the <wiki> setting is processed.
      configure-server(make(<http-server>), config-file);
    end;
    format-out("Restored %d page revisions\n", restore-from-text-files());
  else
    let filename = locator-name(as(<file-locator>, application-name()));
    if (split(filename, ".")[0] = "wiki")
      koala-main(server: $wiki-http-server,
                 description: "Dylan wiki")
    end;
  end;
end function main;

begin
  main();
end;

