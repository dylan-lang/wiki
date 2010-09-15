Module: wiki-internal

// These are sent as the text and URL for the Atom feed generator element.
define variable *site-name* :: <string> = "Dylan Wiki";
define variable *site-url* :: <string> = "";

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
  // TODO: set site-url to http://<local host name>:<port>
  log-info("Site URL: %s", *site-url*);

  *wiki-url-prefix* := get-attr(node, #"url-prefix") | *wiki-url-prefix*;
  log-info("Wiki URL prefix: %s", *wiki-url-prefix*);

  *static-directory*
    := as(<directory-locator>,
          get-attr(node, #"static-directory") | *static-directory*);
  *template-directory* := subdirectory-locator(*static-directory*, "dsp");
  log-info("Wiki static directory: %s", *static-directory*);

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

define function restore-from-text-files
    () => (num-page-revs)
  let wikidata = as(<directory-locator>, "/home/cgay/wiki-data");
  format-out("Restoring wiki data from %s\n", as(<string>, wikidata));
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
        if (~find-user(username))
          let user = make(<wiki-user>,
                          name: username,
                          password: password,
                          email: email,
                          administrator?: #f,
                          activated?: #t);
          save(user);
          inc!(user-count);
        end;
        assert(empty?(read-line(stream)));
      end;
    exception (ex :: <end-of-stream-error>)
      // done
    end;
  end;
  do-directory(gather-page-data, wikidata);
  page-data := sort(page-data, test: less?);
  let administrator = find-user("administrator")
        | error("No 'administrator' user found.  Run the new wiki without "
                "the --restore option first, so the administrator account "
                "will be created when the config file is loaded.");
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
      save-page-internal(page, content, comment, tags, author, action,
                         published: timestamp);
    end;
  end for;
  dump-data();
  page-data.size
end function restore-from-text-files;


// There is method to this madness....  In general a GET generates a "view"
// or "confirm" page and a POST actually performs the operation, such as
// create, edit, or delete.  The same basic scheme is used for each type of
// object: pages, users, and groups.  Here's the example for groups:
//   GET  /group/list           => list groups (has <form> to create group)
//   POST /group/list           => create new group
//   GET  /group/view/<name>    => view group
//   GET  /group/edit/<name>    => display "edit group" form
//   POST /group/edit/<name>    => save group from form fields
//   GET  /group/remove/<name>  => display "remove group" form
//   POST /group/remove/<name>  => remove group
//   ...
// In most cases a single URL points to an instance of <wiki-dsp> for both
// GET and POST, and the methods for respond-to-get and respond-to-post
// handle the logic for the given HTTP request method.

define function add-wiki-responders
    (http-server :: <http-server>)
  initialize-pages();
  local method add (url, resource, #rest args)
          apply(add-resource,
                http-server, concatenate(*wiki-url-prefix*, url), resource,
                trailing-slash: #t,
                args);
        end;
  add("/static", make(<directory-resource>, directory: *static-directory*));

  add("/", make(<wiki-dsp>, source: "main.dsp"),
      url-name: "wiki.home");
  add("/login", function-resource(curry(login, realm: *wiki-realm*)),
      url-name: "wiki.login");
  add("/logout", function-resource(logout),
      url-name: "wiki.logout");
  add("/recent-changes",
      make(<recent-changes-page>, source: "list-recent-changes.dsp"),
      url-name: "wiki.recent-changes");
  add("/feed/{type}/{name}", function-resource(atom-feed-responder),
      url-name: "wiki.atom-feed");

  add("/user/list", *list-users-page*,
      url-name: "wiki.user.list");
  add("/user/view/{name}", *view-user-page*,
      url-name: "wiki.user.view");
  add("/user/edit/{name}", *edit-user-page*,
      url-name: "wiki.user.edit");
  add("/user/remove/{name}", *remove-user-page*,
      url-name: "wiki.user.remove");
  add("/user/activate/{name}/{key}",
      function-resource(respond-to-user-activation-request),
      url-name: "wiki.user.activate");

  add("/register", *registration-page*,
      url-name: "wiki.register");

  // Provide backward compatibility with old wiki URLs.
  // Note no url-name argument since we don't want this URL generated.
  add("/wiki/view.dsp", function-resource(show-page-back-compatible));

  add("/page/list",
      make(<list-pages-page>, source: "list-pages.dsp"),
      url-name: "wiki.page.list");
  add("/page/view/{title}/{version}",
      function-resource(show-page-responder),
      url-name: "wiki.page.view");
  add("/page/edit/{title}/{version}",
      make(<edit-page-page>, source: "edit-page.dsp"),
      url-name: "wiki.page.edit");
  // was show-remove-page and do-remove-page
  add("/page/remove/{title}/{version}", *remove-page-page*,
      url-name: "wiki.page.remove");
  add("/page/versions/{title}", *page-versions-page*,
      url-name: "wiki.page.versions");
  add("/page/diff/{title}/{version1}/{version2}", *view-diff-page*,
      url-name: "wiki.page.diff");
  add("/page/connections/{title}", *connections-page*,
      url-name: "wiki.page.connections");
  add("/page/authors/{title}", function-resource(show-page-authors),
      url-name: "wiki.page.authors");
  add("/page/access/{title}", *edit-access-page*,
      url-name: "wiki.page.access");

  add("/group/list", *list-groups-page*,
      url-name: "wiki.group.list");
  add("/group/view/{name}", *view-group-page*,
      url-name: "wiki.group.view");
  add("/group/edit/{name}", *edit-group-page*,
      url-name: "wiki.group.edit");
  add("/group/remove/{name}", *remove-group-page*,
      url-name: "wiki.group.remove");
  add("/group/members/{name}", *edit-group-members-page*,
      url-name: "wiki.group.members");

    /***** We'll use Google or Yahoo custom search, at least for a while
    url wiki-url("/search")
      action (get, post) () => $search-page;
    */

end function add-wiki-responders;

// --static-directory <dir>
add-option-parser-by-type(*argument-list-parser*,
                          <parameter-option-parser>,
                          description: "Directory containing wiki static files",
                          long-options: #("static-directory"));

define function initialize-wiki
    (server :: <http-server>)
  let directory = option-value-by-long-name(*argument-list-parser*,
                                            "static-directory");
  if (directory)
    *static-directory* := as(<directory-locator>, directory);
    *template-directory* := subdirectory-locator(*static-directory*, "dsp");
  end;
  add-wiki-responders(server);
end function initialize-wiki;

// This is pretty horrifying, but the plan is to eventually make it all
// disappear behind a somewhat less horrifying macro like "define site".
//
define function initialize-pages
    ()
  // page pages
  *view-diff-page* := make(<view-diff-page>, source: "view-diff.dsp");
  *edit-page-page* := make(<edit-page-page>, source: "edit-page.dsp");
  *view-page-page* := make(<wiki-dsp>, source: "view-page.dsp");
  *remove-page-page* := make(<wiki-dsp>, source: "remove-page.dsp");
  *page-versions-page* := make(<page-versions-page>, source: "list-page-versions.dsp");
  *connections-page* := make(<connections-page>, source: "page-connections.dsp");
  *search-page* := make(<wiki-dsp>, source: "search-page.dsp");
  *page-authors-page* := make(<wiki-dsp>, source: "page-authors.dsp");
  *non-existing-page-page* := make(<wiki-dsp>, source: "non-existing-page.dsp");

  // user pages
  *list-users-page* := make(<list-users-page>, source: "list-users.dsp");
  *view-user-page* := make(<view-user-page>, source: "view-user.dsp");
  *edit-user-page* := make(<edit-user-page>, source: "edit-user.dsp");
  *remove-user-page* := make(<wiki-dsp>, source: "remove-user.dsp");
  *non-existing-user-page* := make(<wiki-dsp>, source: "non-existing-user.dsp");
  *not-logged-in-page* := make(<wiki-dsp>, source: "not-logged-in.dsp");

  // group pages
  *list-groups-page* := make(<list-groups-page>, source: "list-groups.dsp");
  *non-existing-group-page* := make(<wiki-dsp>, source: "non-existing-group.dsp");
  *view-group-page* := make(<group-page>, source: "view-group.dsp");
  *edit-group-page* := make(<edit-group-page>, source: "edit-group.dsp");
  *remove-group-page* := make(<remove-group-page>, source: "remove-group.dsp");
  *edit-group-members-page* := make(<edit-group-members-page>,
                                    source: "edit-group-members.dsp");

  // other pages
  *registration-page* := make(<registration-page>, source: "register.dsp");
  *edit-access-page* := make(<acls-page>, source: "edit-page-access.dsp");

end function initialize-pages;

/*
The conversion procedure probably is like this:

* Run the modified old wiki code, which will write out all the wiki
  pages to text files.  /home/cgay/wiki-conversion-libraries/
* BACKUP THE WIKI DATABASE!
* Run the new wiki code briefly, just so it can read in the config
  file and create the administrator user.
  The next step will use these if it finds them.  Shut down the wiki.
* Run the new wiki code again with the --restore command-line argument.
*/
define function main
    ()
  if (member?("--restore", application-arguments(), test: \=))
    // need to handle the --config argument here so the content directory is set.
    // Remove this when the old, pre-turbo wiki is dead.
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
      koala-main(description: "Dylan Wiki",
                 before-startup: initialize-wiki);
    end;
  end;
end function main;

begin
  main();
end;


