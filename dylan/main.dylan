Module: wiki-internal

// These are sent as the text and URL for the Atom feed generator element.
define variable *site-name* :: <string> = "Dylan Wiki";
define variable *site-url* :: <string> = "http://wiki.opendylan.org";

// The realm used for authentication.  Configurable.
define variable *wiki-realm* :: <string> = "wiki";

define variable *mail-host* = #f;
define variable *mail-port* :: <integer> = $default-smtp-port;

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

  *site-name* := get-attr(node, #"site-name") | *site-name*;
  log-info("Site name: %s", *site-name*);

  *site-url*  := get-attr(node, #"site-url")  | *site-url*;
  log-info("Site URL: %s", *site-url*);

  let admin-element = child-node-named(#"administrator");
  if (~admin-element)
    error("An <administrator> element must be specified in the config file.");
  end;
  process-administrator-configuration(admin-element);

  let auth-element = child-node-named(#"authentication");
  if (auth-element)
    process-authentication-configuration(auth-element);
  end;

  let mail-element = child-node-named(#"mail");
  if (mail-element)
    process-mail-configuration(mail-element);
  else
    error("A <mail> element must be specified in the config file.");
  end;
end method process-config-element;

define method process-administrator-configuration
    (admin-element :: xml/<element>)
  let username = get-attr(admin-element, #"username");
  let password = get-attr(admin-element, #"password");
  let email = get-attr(admin-element, #"email");
  if (~(username & password & email))
    error("The <administrator> element must be specified in the config file "
          "with a username, password, and email.");
  end;
  let username = validate-user-name(username);
  let password = validate-password(password);
  let email = validate-email(email);
  let admin = find-user(username);
  let admin-changed? = #f;
  if (admin)
    if (admin.user-password ~= password)
      admin.user-password := password;
      admin-changed? := #t;
      log-info("Administrator user (%s) password changed.", username);
    end;
    if (admin.user-email ~= email)
      admin.user-email := email;
      admin-changed? := #t;
      log-info("Administrator user (%s) email changed to %=.", username, email);
    end;
  else
    admin := make(<wiki-user>,
                  name: username,
                  password: password,
                  email: email,
                  administrator?: #t,
                  activated?: #t);
    admin-changed? := #t;
    log-info("Administrator user (%s) created.", username);
  end;
  if (admin-changed?)
    save(admin);
    dump-data();
  end;
  *admin-user* := admin;
end method process-administrator-configuration;

define method process-authentication-configuration
    (auth-element :: xml/<element>)
  let realm = get-attr(auth-element, #"realm");
  if (realm)
    *wiki-realm* := realm;
    log-info("Authentication realm set to %=", realm);
  end;
end process-authentication-configuration;

define method process-mail-configuration
    (mail-element :: xml/<element>)
  let host = get-attr(mail-element, #"host");
  let port = get-attr(mail-element, #"port");
  if (host)
    *mail-host* := host;
  else
    error("The <mail> configuration element must have a 'host' attribute.");
  end;
  if (port)
    *mail-port* := string-to-integer(port);
  end;
end method process-mail-configuration;

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
    action (get, post) () => curry(login, realm: *wiki-realm*);

  url wiki-url("/logout")
    action (get, post) () => logout;

  url wiki-url("/recent-changes")
    action get () =>
      $recent-changes-page;

  //  /feed[/type[/name]]
  url wiki-url("/feed")
    action get "^((?P<type>[^/]+)(/(?P<name>[^/]+))?)?" =>
      atom-feed-responder;

  url wiki-url("/users")
    action (get, post) () =>
      $list-users-page,
    action get "^(?P<name>[^/]+)/?$" =>
      $view-user-page,
    action (get, post) "^(?P<name>[^/]+)/edit$" =>
      $edit-user-page,
    action get "^(?P<name>[^/]+)/remove$" =>
      show-remove-user,
    action post "^(?P<name>[^/]+)/remove$" =>
      do-remove-user,
    action get "^(?P<name>[^/]+)/activate/(?P<key>.+)$" =>
      respond-to-user-activation-request;

  url wiki-url("/register")
    action (get, post) () => $registration-page;

  // Provide backward compatibility with old wiki URLs.
  url "/wiki/view.dsp"
    action get () => show-page-back-compatible;

  url wiki-url("/pages")
    action get () => do-pages,
    action get "^(?P<title>[^/]+)/?$" =>
      show-page,
    action get "^(?P<title>[^/]+)/edit$" =>
      $edit-page-page,
    action post "^(?P<title>[^/]+)(/(edit)?)?$" =>
      $edit-page-page,
    action get "^(?P<title>[^/]+)/remove$" =>
      show-remove-page,
    action (delete, post) "^(?P<title>[^/]+)/remove$" =>
      do-remove-page,
    action get "^(?P<title>[^/]+)/versions$" =>
      $page-versions-page,
    action get "^(?P<title>[^/]+)/versions/(?P<version>\\d+)$" =>
      show-page,
    action get "^(?P<title>[^/]+)/versions/(?P<a>\\d+)/diff(/(?P<b>\\d+))?$" =>
      show-page-versions-differences,
    action get "^(?P<title>[^/]+)/connections$" =>
      $connections-page,
    action get "^(?P<title>[^/]+)/authors$" =>
      show-page-authors,
    action (get, post) "^(?P<title>[^/]+)/access" =>
      $edit-access-page;

  url wiki-url("/groups")
    action (get, post) () =>
      $list-groups-page,
    action get "^(?P<name>[^/]+)/?$" =>
      $view-group-page,
    action (get, post) "^(?P<name>[^/]+)/edit$" =>
      $edit-group-page,
    action (get, post) "^(?P<name>[^/]+)/remove$" =>
      $remove-group-page,
    // members
    action (get, post) "^(?P<name>[^/]+)/members$" =>
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

