Module: wiki-test-suite
Synopsis: Tests of the storage protocol

// This should be the only function here that depends on the git back-end.
// TODO: make paths configurable
// TODO: don't re-use the same storage directory each time since it makes debugging
//       hard.  Create a new directory for each test.
define function init-storage
    () => (storage :: <storage>)
  let base = as(<directory-locator>, "c:/tmp/storage-test-suite");
  let main = subdirectory-locator(base, "main-storage");
  let user = subdirectory-locator(base, "user-storage");
  if (file-exists?(base))
    test-output("Deleting base directory %s\n", as(<string>, base));
    delete-directory(base, recursive?: #t);
  end;
  let git-exe = as(<file-locator>, "c:\\Program Files\\Git\\bin\\git.exe");
  let storage = make(<git-storage>,
                     repository-root: main,
                     user-repository-root: user,
                     executable: git-exe);
  init-admin-user(storage);
  initialize-storage-for-reads(storage);
  initialize-storage-for-writes(storage, *admin-user*);
  store(storage, *admin-user*, *admin-user*, "Init admin user",
        standard-meta-data(*admin-user*, "edit"));
  *storage* := storage;
  storage
end;

define function init-admin-user
    (storage :: <storage>) => (user :: <wiki-user>)
  let admin = make(<wiki-user>,
                   name: "administrator",
                   real-name: "Administrator",
                   password: "secret",
                   email: "cgay@opendylan.org",
                   administrator?: #t,
                   activated?: #t);
  *users*[admin.user-name] := admin;
  *admin-user* := admin
end function init-admin-user;


define function make-test-page
    (#key title, content, comment, owner, author, tags, access-controls)
 => (page :: <wiki-page>)
  let title = title | "Title";
  with-lock ($page-lock)
    *pages*[title] := make(<wiki-page>,
                           title: title,
                           content: content | "Content",
                           comment: comment | "Comment",
                           owner: owner | *admin-user*,
                           author: author | *admin-user*,
                           tags: tags | #("tag"),
                           access-controls: access-controls | $default-access-controls)
  end
end function make-test-page;

define suite user-test-suite ()
  test test-save/load-user;
  test test-remove-user;
end;

define test test-save/load-user ()
  let storage = init-storage();

  check-true("No users in database at startup",
             begin
               let users = load-all(storage, <wiki-user>);
               users.size = 1
               & users[0] = *admin-user*
             end);

  let old-user = make(<wiki-user>,
                      name: "wuser",
                      real-name: "Wiki User",
                      password: "password",
                      email: "luser@opendylan.org",
                      administrator?: #f,
                      activation-key: "abc",
                      activated?: #t);
  let author = old-user;
  check-no-condition("store user works",
                     store(storage, old-user, author, "comment",
                           standard-meta-data(old-user, "create")));

  let users = load-all(storage, <wiki-user>);
  check-equal("Two users in storage", 2, users.size);

  // Verify that all slots are the same in old-user and new-user.
  let new-user = find-element(users, method (u)
                                       u.user-name = old-user.user-name
                                     end);
  for (fn in list(user-name,
                  user-real-name,
                  user-password,
                  user-email,
                  administrator?,
                  user-activation-key,
                  user-activated?))
    check-equal(format-to-string("%s equal?", fn),
                fn(old-user),
                fn(new-user))
  end;
end test test-save/load-user;

/// Verify that when a user is deleted, any groups they belong to
/// are updated and any pages they own become owned by the admin user.
define test test-remove-user ()
end;


define suite page-test-suite ()
  test test-save/load-page;
  test test-remove-page;
end;

define test test-save/load-page ()
  let storage = init-storage();
  let old-page = make-test-page();
  store(storage, old-page, old-page.page-author, old-page.page-comment,
        standard-meta-data(old-page, "create"));
  let new-page = load(storage, <wiki-page>, old-page.page-title);
  for (fn in list(page-title,
                  page-content,
                  page-comment,
                  page-owner,
                  page-author,
                  page-tags))
    check-equal(format-to-string("%s equal?", fn),
                fn(old-page),
                fn(new-page));
  end;

  check-equal("revision is set to a git hash",
              40,
              new-page.page-revision.size);

  for (i from 1,
       fn in list(view-content-rules,
                  modify-content-rules,
                  modify-acls-rules))
    let old-rules = fn(old-page.page-access-controls);
    let new-rules = fn(new-page.page-access-controls);
    check-equal(format-to-string("#%d same number of rules", i),
                old-rules.size,
                new-rules.size);
    for (old-rule in old-rules,
         new-rule in new-rules)
      check-equal(format-to-string("#%d rule actions the same", i),
                  old-rule.rule-action,
                  new-rule.rule-action);
      check-equal(format-to-string("#%d rule targets the same", i),
                  old-rule.rule-target,
                  new-rule.rule-target);
    end for;
  end for;
end test test-save/load-page;

define test test-remove-page ()
end;


define suite group-test-suite ()
  test test-save/load-group;
  test test-remove-group;
end;

define test test-save/load-group ()
  let storage = init-storage();
  let old-group = make(<wiki-group>,
                       name: "group-a",
                       owner: *admin-user*,
                       members: list(*admin-user*),
                       description: "group a");
  check-no-condition("store group works",
                     store(storage, old-group, *admin-user*, "creating group a",
                           standard-meta-data(old-group, "create")));

  let groups = load-all(storage, <wiki-group>);
  check-equal("One group in storage", 1, groups.size);

  let new-group = groups[0];
  check-equal("name", old-group.group-name, new-group.group-name);
  check-equal("owner", old-group.group-owner, new-group.group-owner);
  check-equal("description", old-group.group-description, new-group.group-description);
  check-equal("members", old-group.group-members, new-group.group-members);
end test test-save/load-group;

define test test-remove-group ()
end;

/// Verify that when pages are created references to other pages are
/// updated correctly.
define test test-page-references ()
  // ---*** fill me in
end;

define test test-find-or-load-pages-with-tags ()
  let storage = init-storage();
  let page1 = make-test-page(title: "p1", tags: #());
  let page2 = make-test-page(title: "p2", tags: #("tag2"));
  let page3 = make-test-page(title: "p3", tags: #("tag3"));
  for (page in list(page1, page2, page3))
    store(storage, page, *admin-user*, "comment", standard-meta-data(page, "create"));
  end;
  check-true("revision slot bound after storing page",
             slot-initialized?(page3, page-revision));

  // This checks for identity because the page was already loaded.
  check-equal("find pages with tag2",
              find-or-load-pages-with-tags(storage, #("tag2")),
              list(page2));

  // This checks only that title and revision are equal because the page
  // was loaded and therefore isn't == to page3.
  remove-key!(*pages*, page3.page-title);
  let pages = find-or-load-pages-with-tags(storage, #("tag3"));
  break("pages = %=", pages);
  check-equal("found one page with tag3", pages.size, 1);
  check-true("found page3",
             (pages[0].page-title = page3.page-title)
             & (pages[0].page-revision = page3.page-revision));
end test test-find-or-load-pages-with-tags;



define suite storage-test-suite ()
  suite user-test-suite;
  suite page-test-suite;
  suite group-test-suite;
  test test-page-references;
  test test-find-or-load-pages-with-tags;
end suite storage-test-suite;

