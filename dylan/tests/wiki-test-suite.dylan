Module: wiki-test-suite

define suite acl-test-suite ()
  test test-has-permission?;
end;

// Tests the default access controls for a <wiki-page>.
//
define test test-has-permission? ()
  let owner = make(<wiki-user>,
                   username: "owner",
                   password: "owner",
                   email: "owner",
                   administrator?: #f);
  let plain = make(<wiki-user>,
                   username: "plain",
                   password: "plain",
                   email: "admin",
                   administrator?: #f);
  let admin = make(<wiki-user>,
                   username: "admin",
                   password: "admin",
                   email: "admin",
                   administrator?: #t);
  // Explicitly not specifying the access-contols for this page so the
  // default is used.
  let page = make(<wiki-page>,
                  title: "test page",
                  owner: owner);

  check-true("not-logged-in can view content",
             has-permission?(#f, page, $view-content));
  check-false("not-logged-in can modify content",
              has-permission?(#f, page, $modify-content));
  check-false("not-logged-in can modify acls",
              has-permission?(#f, page, $modify-acl));

  check-true("owner can view content",   has-permission?(owner, page, $view-content));
  // This fails because it needs to get the Auth header from the HTTP request
  // and there's no request active.  Need to either define a way to fake-out
  // current-request() or test this via an HTTP request.
  check-true("owner can modify content", has-permission?(owner, page, $modify-content));
  check-true("owner can modify acls",    has-permission?(owner, page, $modify-acl));

  check-true("plain can view content",    has-permission?(plain, page, $view-content));
  // This fails for the same reason as above.
  check-false("plain can modify content", has-permission?(plain, page, $modify-content));
  check-false("plain can modify acls",    has-permission?(plain, page, $modify-acl));

  check-true("admin can view content",   has-permission?(admin, page, $view-content));
  check-true("admin can modify content", has-permission?(admin, page, $modify-content));
  check-true("admin can modify acls",    has-permission?(admin, page, $modify-acl));
end;

define test save-user-test ()
end;

define suite storage-test-suite ()
  test save-user-test;
end suite storage-test-suite;

define suite wiki-test-suite ()
  suite storage-test-suite;
  suite acl-test-suite;
end suite wiki-test-suite;

define method main () => ()
  let filename = locator-name(as(<file-locator>, application-name()));
  if (split(filename, ".")[0] = "wiki-test-suite")
    run-test-application(wiki-test-suite);
  end;
end method main;

begin
  main()
end;
