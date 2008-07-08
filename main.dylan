module: wiki


define function sort-table
    (the-table :: <table>, getter :: <function>,
     #key order :: <function> = \>)
 => (entries :: <sequence>);
  sort(map-as(<vector>, identity, the-table),
    test: method (first, second)
      order(getter(first), getter(second))
    end);
end function sort-table;

define url-map
  url "/recent-changes"
    action get () => *recent-changes-page*,
    action get ("^feed/?$") => do-feed;

  url "/users"
    action get () => do-users,
    action get ("^(?P<username>[^/]+)/?$") =>
      (bind-user, show-user),
    action get ("^(?P<username>[^/]+)/edit$") =>
      (bind-user, show-edit-user),
    action (post, put) ("^(?P<username>[^/]+)(/(edit)?)?$") =>
      do-save-user,
    action get ("^(?P<username>[^/]+)/remove$") =>
      (bind-user, show-remove-user),
    action (delete, post) ("^(?P<username>[^/]+)/remove$") =>
      do-remove-user;

  url "/pages"
    action get () => do-pages,
    action get ("^(?P<title>[^/]+)/?$") =>
      (bind-page, show-page),
    action get ("^(?P<title>[^/]+)/edit$") =>
      (bind-page, show-edit-page),
    action (post, put) ("^(?P<title>[^/]+)(/(edit)?)?$") =>
      do-save-page,
    action get ("^(?P<title>[^/]+)/remove$") =>
      (bind-page, show-remove-page),
    action (delete, post) ("^(?P<title>[^/]+)/remove$") =>
      do-remove-page,
   // versions
    action get ("^(?P<title>[^/]+)/versions$") => 
      (bind-page, show-page-versions),
    action get ("^(?P<title>[^/]+)/versions/(?P<version>\\d+)$") =>
      (bind-page, show-page),
    action get ("^(?P<title>[^/]+)/versions/(?P<a>\\d+)/diff(/(?P<b>\\d+))?$") => 
      (bind-page, show-page-versions-differences),
    // connections
    action get ("^(?P<title>[^/]+)/connections$") => 
      (bind-page, show-page-connections),
    // authors
    action get ("^(?P<title>[^/]+)/authors$") =>
      (bind-page, show-page-authors),
    // access
    action get ("^(?P<title>[^/]+)/access") =>
      (bind-page, show-page-access);

  url "/groups"
    action get () => do-groups,
    action get ("^(?P<name>[^/]+)/?$") =>
      (bind-group, show-group),
    action get ("^(?P<name>[^/]+)/edit$") =>
      (bind-group, show-edit-group),
    action (post, put) ("^(?P<name>[^/]+)(/(edit)?)?$") =>
      do-save-group,
    action get ("^(?P<name>[^/]+)/remove$") =>
      (bind-group, show-remove-group),
    action (delete, post) ("^(?P<name>[^/]+)/remove$") =>
      do-remove-group,
    // members
    action get ("^(?P<name>[^/]+)/members$") =>
      (bind-group, edit-group-members),
    action (post, put) ("^(?P<name>[^/]+)/members$") =>
      do-save-group-members,
    // authorization
    action get ("^(?P<name>[^/]+)/authorization$") =>
      (bind-group, edit-group-authorization),
    action (post, put) ("^(?P<name>[^/]+)/authorization$") =>
      do-save-group-authorization;

  url "/"
    action get () => *main-page*;
end;

define function main () => ()
  let config-file = if (application-arguments().size > 0)
                      application-arguments()[0]
                    end;
  start-sockets();
  start-server(config-file: config-file);
end;

begin
  main()
end;
