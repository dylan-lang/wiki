Module: wiki-test-suite

define suite acls-test-suite ()
  test test-default-access-controls;
  test test-has-permission?;
  test test-invalid-acls;
  test test-no-rule-matches-means-deny;
  test test-no-deny-owner;
end;

define constant $owner-user = make(<wiki-user>,
                                   name: "owner",
                                   password: "owner",
                                   email: "owner",
                                   administrator?: #f);

define constant $plain-user = make(<wiki-user>,
                                   name: "plain",
                                   password: "plain",
                                   email: "admin",
                                   administrator?: #f);

define constant $admin-user = make(<wiki-user>,
                                   name: "admin",
                                   password: "admin",
                                   email: "admin",
                                   administrator?: #t);

define function make-page
    (title :: <string>, acls :: <acls>)
 => (page :: <wiki-page>)
  make(<wiki-page>,
       title: title,
       author: $plain-user,
       tags: #(),
       source: "foo",
       parsed-source: parse-wiki-markup("foo", title),
       comment: "bar",
       owner: $owner-user,
       access-controls: acls)
end;
  

// Tests the default access controls for a <wiki-page>.
// This depends on administrator being the page owner.
//
define test test-default-access-controls ()
  for (page in list(#f,  // #f is for new pages being created
                    make-page("test-default-access-controls",
                              $default-access-controls)))
    let test-data =
      list(list("not-logged-in can view content",   #t, #f, $view-content),
           list("not-logged-in can modify content", #f, #f, $modify-content),
           list("not-logged-in can modify ACLs",    #f, #f, $modify-acls),

           list("owner can view content",   #t, $owner-user, $view-content),
           list("owner can modify content", #t, $owner-user, $modify-content),
           list("owner can modify ACLs",    #t, $owner-user, $modify-acls),

           list("vanilla user can view content",   #t, $plain-user, $view-content),
           list("vanilla user can modify content", #t, $plain-user, $modify-content),
           list("vanilla user can modify ACLs",    #f, $plain-user, $modify-acls),

           list("admin user can view content",   #t, $admin-user, $view-content),
           list("admin user can modify content", #t, $admin-user, $modify-content),
           list("admin user can modify ACLs",    #t, $admin-user, $modify-acls));

    for (item in test-data)
      let (check-name, expected-result, user, acl-operation) = apply(values, item);
      check-equal(format-to-string("%s (page = %s)", check-name, page),
                  expected-result,
                  has-permission?(user, page, acl-operation));
    end for;
  end for;
end test test-default-access-controls;

// Verify that if no rule matches access is denied.
define test test-no-rule-matches-means-deny ()
  let page = make-page("test-no-match-means-deny",
                       make(<acls>, view-content: #()));
  check-false("access is denied if no rule matches",
              has-permission?($plain-user, page, $view-content));
end;

define test test-invalid-acls ()
  // todo -- should raise more specific error class
  check-condition("create acls with non-sequence rules",
                  <error>,
                  make(<acls>, view-content: make(<table>)));
  check-condition("create acls with wrong rule length",
                  <error>,
                  make(<acls>, modify-content: list(list(deny:, $anyone, foo:))));
  check-condition("create acls with bad action",
                  <error>,
                  make(<acls>, modify-content: list(list(foo: $anyone))));
  check-condition("create acls with bad target",
                  <error>,
                  make(<acls>, modify-acls: list(vector(allow:, foo:))));
end test test-invalid-acls;

define test test-no-deny-owner ()
  // todo -- make sure that if the owner is a member of a denied group they
  //         still have access.
  let page = make-page("test-no-deny-owner",
                       make(<acls>, view-content: list(list(deny:, $owner-user))));
  check-true("owner still has permission even if explicitly denied",
             has-permission?($owner-user, page, $view-content));
end test test-no-deny-owner;

define test test-has-permission? ()
/*
  let acls = make(<acls>,
                  view-content: list(list(deny:, $plain-user1),
                                     list(deny:, $plain-user2),
                                     list(allow:, $anyone)),
                  modify-content: list(list(allow:, $trusted)),
                  modify-acls: list(list(allow:, $owner)));
  let page = make(<wiki-page>,
                  title: "test page",
                  owner: $owner-user,
                  access-controls: acls);

  let test-data =
    list(list("not-logged-in can view content",   #t, #f, $view-content),
         list("not-logged-in can modify content", #f, #f, $modify-content),
         list("not-logged-in can modify ACLs",    #f, #f, $modify-acl),
         
         list("owner can view content",   #t, $owner-user, $view-content),
         list("owner can modify content", #t, $owner-user, $modify-content),
         list("owner can modify ACLs",    #t, $owner-user, $modify-acl),
         
         list("vanilla user can view content",   #t, $plain-user, $view-content),
         list("vanilla user can modify content", #t, $plain-user, $modify-content),
         list("vanilla user can modify ACLs",    #f, $plain-user, $modify-acl),
         
         list("admin user can view content",   #t, $admin-user, $view-content),
         list("admin user can modify content", #t, $admin-user, $modify-content),
         list("admin user can modify ACLs",    #t, $admin-user, $modify-acl));
  for (item in list)
    let (check-name, expected-result, user, acl-operation) = apply(values, item);
    check-equal(check-name,
                expected-result,
                has-permission?(user, page, acl-operation));
  end;
*/
end test test-has-permission?;
