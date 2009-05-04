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
    break("username = %s, password = %s, email = %s", username, password, email);
    error("The <administrator> element must be specified in the config file "
          "with a username, password, and email.");
  else
    let user = make(<wiki-user>,
                    username: username,
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
      show-edit-page,
    action post ("^(?P<title>[^/]+)(/(edit)?)?$") =>
      do-save-page,
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
      show-page-connections,
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

define function main
    ()
  let filename = locator-name(as(<file-locator>, application-name()));
  if (split(filename, ".")[0] = "wiki")
    koala-main(server: $wiki-http-server,
               description: "Dylan wiki")
  end;
end;

begin
  main();
end;

