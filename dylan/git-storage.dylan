Module: %wiki
Synopsis: Implements the storage protocol with a git back-end
Author: Carl Gay


// See wiki.dylan for the storage protocol generics.

// TODO: locking strategy.  Ensure that only one instance of the wiki
//       application can run for a given repository. Then load-all-users/groups
//       can be done safely at startup. Then there could be one file lock per
//       page/group/user.  File locks are needed because these objects need to
//       be locked while the user is busily editing them in some web page.
//       This could get arbitrarily complicated and needs some research first.
//       I will proceed for now without locking at all.  Weee!
//       Also (or instead) need to lock around prefix creation/add/commit.

// TODO: error handling.  Think "disk error".

// TODO: Fix run-application to accept command args as a sequence of strings.
//       (At which point we can stop escaping the "s in command arguments, and
//       various other potential escaping bugs will die.)

define constant $user-prefix-size :: <integer> = 1;
define constant $group-prefix-size :: <integer> = 1;
define constant $page-prefix-size :: <integer> = 3;

// For now there is no way to create new "sandboxes"; that level
// in the directory hierarchy exists only for future expansion.
define constant $default-sandbox-name :: <string> = "main";

// File names inside a git page directory
define constant $content :: <byte-string> = "content";
define constant $tags :: <byte-string> = "tags";
define constant $acls :: <byte-string> = "acls";

// Some directory names, relative to the repository roots.
define constant $pages-directory-name :: <string> = "pages";
define constant $groups-directory-name :: <string> = "groups";
define constant $users-directory-name :: <string> = "users";

define constant sformat = format-to-string;

define constant $newline-regex :: <regex> = compile-regex("[\r\n]+");
define constant $whitespace-regex :: <regex> = compile-regex("[ \r\n\t]");
define constant $git-author-regex :: <regex>
  = compile-regex("Author: .* <([^@]+)@.*>");

define variable *pages-directory* :: false-or(<directory-locator>) = #f;
define variable *users-directory* :: false-or(<directory-locator>) = #f;
define variable *groups-directory* :: false-or(<directory-locator>) = #f;


define class <git-storage> (<storage>)

  // The root directory of the wiki data repository, as a string.
  constant slot git-repository-root :: <directory-locator>,
    required-init-keyword: repository-root:;

  // User data is stored in a separate repository so that it can
  // be maintained separately (more securely) than other data.
  constant slot git-user-repository-root :: <directory-locator>,
    required-init-keyword: user-repository-root:;

  constant slot git-executable :: <file-locator>,
    required-init-keyword: executable:;

end class <git-storage>;


define class <git-storage-error> (<storage-error>)
end;

define function git-error
    (fmt :: <string>, #rest args)
  signal(make(<git-storage-error>,
              format-string: fmt,
              format-arguments: args))
end;


//// Initialization

// Initialization is broken into two parts because writes are dependent
// on the admin user existing.  The caller is expected to:
// 1. initialize-storage-for-reads
// 2. make admin user
// 3. initialize-storage-for-writes, passing admin user
// 4. store admin user

/// Make sure the git repository directories exist and have been
/// initialized as git repositories.
///
define method initialize-storage-for-reads
    (storage :: <git-storage>) => ()
  ensure-directories-exist(storage.git-repository-root);
  ensure-directories-exist(storage.git-user-repository-root);

  // It is supposed to be safe to call "git init" on an already
  // initialized repository, so we don't check whether it has already
  // been done first.
  call-git(storage, "init");
  call-git(storage, "init", working-directory: storage.git-user-repository-root);

  *pages-directory*
    := subdirectory-locator(storage.git-repository-root, $pages-directory-name);
  *users-directory*
    := subdirectory-locator(storage.git-user-repository-root, $users-directory-name);
  *groups-directory*
    := subdirectory-locator(storage.git-repository-root, $groups-directory-name);

  ensure-directories-exist(*pages-directory*);
  ensure-directories-exist(subdirectory-locator(*pages-directory*,
                                                $default-sandbox-name));
  ensure-directories-exist(*groups-directory*);
  ensure-directories-exist(*users-directory*);
end method initialize-storage-for-reads;

define method initialize-storage-for-writes
    (storage :: <git-storage>, admin :: <wiki-user>) => ()
  log-debug("initialize-storage-for-writes");
  // Commits are all done by Administrator, with the Author set to the
  // user making the change.
  let set-name = sformat("config --global user.name \"%s\"", admin.user-name);
  let set-email = sformat("config --global user.email \"%s\"", admin.user-email);
  call-git(storage, set-name);
  call-git(storage, set-email);
  call-git(storage, set-name, working-directory: storage.git-user-repository-root);
  call-git(storage, set-email, working-directory: storage.git-user-repository-root);
end method initialize-storage-for-writes;


//// Pages

/// Load a page from back-end storage.  'name' is the page title.
/// Return: version -- a git hash code (a string)
///
define method load
    (storage :: <git-storage>, class == <wiki-page>, title :: <string>,
     #key revision :: <string> = "HEAD")
 => (page :: <wiki-page>)
  log-debug("Loading page %=", title);

  let prefix = title-prefix(title);
  let etitle = git-encode-title(title);
  let page-dir = subdirectory-locator(*pages-directory*,
                                      $default-sandbox-name,
                                      prefix,
                                      etitle);
  let page-path = sformat("%s/%s/%s/%s",
                          $pages-directory-name,
                          $default-sandbox-name, prefix, etitle);
  let content-path = sformat("%s/%s", page-path, $content);
  let changes = git-load-changes(storage, content-path, revision, 1);
  if (empty?(changes))
    git-error("Page %= not found.", title);
  end;
  let change = changes[0];
  let hash = change.change-revision;
  let tags = git-load-blob(storage, sformat("%s/%s", page-path, $tags), hash);
  let acls = git-load-blob(storage, sformat("%s/%s", page-path, $acls), hash);
  let content = git-load-blob(storage, content-path, hash);
  let (owner, acls) = git-parse-acls(acls, title);
  make(<wiki-page>,
       creation-date: creation-date,
       title: title,
       content: content,
       comment: change.change-comment,
       owner: owner,
       author: find-user(change.change-author) | *admin-user*,
       revision: hash,
       tags: git-parse-tags(tags),
       access-controls: acls)
end method load;

// This may be crazy in the long run, but I think it will scale well enough
// until we get up to, say, 10k pages?  We shall see.  It simplifies the
// code a lot to load all the pages up front.
define method load-all
    (storage :: <storage>, class == <wiki-page>)
 => (pages :: <sequence>)
  log-info("Loading all pages from storage (%s)...",
           as(<string>, storage.git-repository-root));
  let pages :: <stretchy-vector> = make(<stretchy-vector>);
  local method load-page (page-directory :: <directory-locator>)
          let title = git-decode-title(locator-name(page-directory));
          block ()
            add!(pages, load(storage, <wiki-page>, title));
          exception (ex :: <git-storage-error>)
            log-error("Unable to load page %=: %s", title, ex);
          end;
        end;
  do-object-files(subdirectory-locator(*pages-directory*, $default-sandbox-name),
                  <wiki-page>,
                  load-page);
  log-info("Loaded %d pages.", pages.size);
  pages
end method load-all;


// TODO: this should cache the tags and maintain a map of them in
//       memory, to prevent having to scan the file system each time.
//       (Though really, a full text index would be nice.)
define method find-or-load-pages-with-tags
    (storage :: <storage>, tags :: <sequence>)
 => (pages :: <sequence>)
  let pages = make(<stretchy-vector>);
  local method load-page-tags (page-directory :: <directory-locator>)
          with-open-file(stream = file-locator(page-directory, $tags))
            split(read-to-end(stream), '\n')
          end
        end;
  local method load-page-with-tags (page-directory :: <directory-locator>)
          let title = git-decode-title(locator-name(page-directory));
          let page = find-page(title);
          let page-tags = iff(page,
                              page.page-tags,
                              load-page-tags(page-directory));
          block (return)
            for (tag in tags)
              if (member?(tag, page-tags, test: \=))
                add!(pages, find-or-load-page(title));
                return();
              end;
            end;
          end block;
        end;
  do-object-files(subdirectory-locator(*pages-directory*, $default-sandbox-name),
                  <wiki-page>,
                  load-page-with-tags);
  pages
end method find-or-load-pages-with-tags;


define method store
    (storage :: <storage>, page :: <wiki-page>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  let (page-path, prefix, safe-title) = git-page-path(page.page-title);
  let prefix-dir = subdirectory-locator(*pages-directory*,
                                        $default-sandbox-name,
                                        prefix);
  let page-dir = subdirectory-locator(prefix-dir, safe-title);
  ensure-directories-exist(prefix-dir);
  ensure-directories-exist(page-dir);

  store-blob(file-locator(page-dir, $content), page.page-content);
  store-blob(file-locator(page-dir, $tags), tags-to-string(page.page-tags));
  store-blob(file-locator(page-dir, $acls), acls-to-string(page));

  call-git(storage,
           sformat("add \"%s/%s\" \"%s/%s\" \"%s/%s\"",
                   page-path, $content,
                   page-path, $tags,
                   page-path, $acls));
  let revision = git-commit(storage, page-path, author, comment, meta-data);
  log-info("Stored page %= revision %s", page.page-title, revision);
  page.page-revision := revision
end method store;

define method delete
    (storage :: <storage>, page :: <wiki-page>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => ()
  let (page-path, prefix, safe-title) = git-page-path(page.page-title);
  let prefix-dir = subdirectory-locator(*pages-directory*,
                                        $default-sandbox-name,
                                        prefix);
  let page-dir = subdirectory-locator(prefix-dir, safe-title);
  if (file-exists?(page-dir))
    call-git(storage, sformat("rm -r \"%s\"", page-path));
  end;
  git-commit(storage, page-path, author, comment, meta-data)
end method delete;

define method rename
    (storage :: <storage>, page :: <wiki-page>, new-title :: <string>,
     author :: <wiki-user>, comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  let old-page-path = git-page-path(page.page-title);
  let (new-page-path, prefix, safe-title) = git-page-path(new-title);
  let new-dir = subdirectory-locator(*pages-directory*, $default-sandbox-name,
                                     prefix);
  ensure-directories-exist(new-dir);
  call-git(storage, sformat("mv \"%s\" \"%s\"", old-page-path, new-page-path));
  let revision = git-commit(storage, old-page-path, author, comment, meta-data,
                            extra-path: new-page-path);
  log-info("Renamed page %= to %= @%s", page.page-title, new-title, revision);
  revision
end method rename;
  
define method find-changes
    (storage :: <storage>, type == <wiki-page>,
     #key start :: false-or(<string>),
          name :: false-or(<string>),
          count :: <integer> = $default-list-size,
          diff? :: <boolean>)
 => (changes :: <sequence>)
  let path = iff(name, git-page-path(name), $pages-directory-name);
  git-load-changes(storage, path, start | "HEAD", count, diff?: diff?)
end method find-changes;


define function git-page-path
    (title :: <string>)
 => (path :: <string>, prefix :: <string>, safe-title :: <string>)
  let safe-title = git-encode-title(title);
  let prefix = title-prefix(safe-title);
  values(sformat("%s/%s/%s/%s",
                 $pages-directory-name,
                 $default-sandbox-name, prefix, safe-title),
         prefix,
         safe-title)
end;

/// Encode the title to make it safe for use as a directory name.
///
define function git-encode-title
    (title :: <string>) => (encoded-title :: <string>)
  // TODO: do it
  title
end;

define function git-decode-title
    (encoded-title :: <string>) => (title :: <string>)
  // TODO: do it
  encoded-title
end;

define function title-prefix
    (title :: <string>) => (prefix :: <string>)
  // This'll do for now, but will result in certain common title words
  // (e.g., "The") causing a lot of pages to go into the same prefix
  // directory.  It might work better to use something like the first
  // character from the first n words of the title, with special treatment
  // of one-word titles.  (Using a hash has the drawback of not being able
  // to easily see which directory a page is in.)
  let prefix = slice(title, 0, $page-prefix-size);
  if (prefix.size < $page-prefix-size)
    concatenate(prefix, make(<byte-string>,
                             size: $page-prefix-size - prefix.size,
                             fill: '_'))
  else
    prefix
  end
end function title-prefix;
  


//// Users

// All users are loaded from storage at startup and they are written
// to storage individually as they're created or changed.  Therefore
// there is no need for 'load' or 'store-all' methods.

/// Load all users from back-end storage.
/// Returns a collection of <wiki-user>s.
/// See ../README.rst for a description of the file format.
///
define method load-all
    (storage :: <storage>, class == <wiki-user>)
 => (users :: <sequence>)
  log-info("Loading all users...");
  let users = #();
  local method load-user(pathname :: <file-locator>)
          with-open-file(stream = pathname, direction: #"input")
            let creation-date = read-line(stream, on-end-of-stream: #f);
            let line = read-line(stream, on-end-of-stream: #f);
            log-debug("creation-date = %=", creation-date);
            log-debug("line = %=", line);
            users := pair(git-parse-user(creation-date, line),
                          users);
          end;
        end;
  do-object-files(*users-directory*, <wiki-user>, load-user);
  log-info("Loaded %d users from storage", users.size);
  reverse!(users)
end method load-all;

define function git-parse-user
    (creation-date :: <string>, line :: <string>) => (user :: <wiki-user>)
  let (name, real-name, admin?, password, email, activation-key, activated?)
    = apply(values, split(line, ':'));
  make(<wiki-user>,
       creation-date: git-parse-date(creation-date),
       name: name,
       real-name: iff(empty?(real-name), #f, real-name),
       password: password,  // in base-64 (for now)
       email: email,    // in base-64
       administrator?: git-parse-boolean(admin?),
       activation-key: activation-key,
       activated?: git-parse-boolean(activated?))
end function git-parse-user;

define method store
    (storage :: <storage>, user :: <wiki-user>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  let name :: <string> = user.user-name;
  log-info("Storing user %=", name);

  let user-file = git-user-storage-file(storage, name);
  ensure-directories-exist(user-file);
  store-blob(user-file,
             sformat("%s\n%s:%s:%s:%s:%s:%s:%s\n",
                     git-encode-date(user.creation-date),
                     name,
                     user.%user-real-name | "",
                     git-encode-boolean(user.administrator?),
                     user.user-password,  // in base-64 (for now)
                     user.user-email,     // already in base-64
                     user.user-activation-key,
                     git-encode-boolean(user.user-activated?)));

  let user-path = git-user-path(name);
  call-git(storage, sformat("add \"%s\"", user-path),
           working-directory: storage.git-user-repository-root);
  git-user-commit(storage, user-path, author, comment, meta-data)
end method store;

define method delete
    (storage :: <storage>, user :: <wiki-user>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => ()
  git-error("User deletion disallowed");
end method delete;

define method rename
    (storage :: <storage>, user :: <wiki-user>, new-name :: <string>,
     author :: <wiki-user>, comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  let old-user-path = git-user-path(user.user-name);
  let new-user-path = git-user-path(new-name);

  ensure-directories-exist(git-user-storage-file(storage, new-name));

  call-git(storage, sformat("mv \"%s\" \"%s\"", old-user-path, new-user-path));
  let revision = git-user-commit(storage, old-user-path, author, comment,
                                 meta-data, extra-path: new-user-path);
  log-info("Renamed user %= to %= @%s", user.user-name, new-name, revision);
end method rename;

define method find-changes
    (storage :: <storage>, type == <wiki-user>,
     #key start :: false-or(<string>),
          name :: false-or(<string>),
          count :: <integer> = $default-list-size)
 => (changes :: <sequence>)
  let path = iff(name, git-user-path(name), $users-directory-name);
  git-load-changes(storage, path, start | "HEAD", count)
end;

define function git-user-storage-file
    (storage :: <git-storage>, name :: <string>)
 => (locator :: <file-locator>)
  file-locator(subdirectory-locator(*users-directory*,
                                    slice(name, 0, $user-prefix-size)),
               name)
end;

define inline function git-user-path
    (username :: <string>) => (path :: <string>)
  sformat("%s/%s/%s",
          $users-directory-name,
          slice(username, 0, $user-prefix-size), username)
end;


//// Groups

// All groups are loaded from storage at startup and they are written
// to storage individually as they're created or changed.  Therefore
// there is no need for 'load' or 'store-all' methods.

/// Load all users from back-end storage.
/// Returns a collection of <wiki-user>s.
/// See ../README.rst for a description of the file format.
///
define method load-all
    (storage :: <storage>, class == <wiki-group>)
 => (groups :: <sequence>)
  log-info("Loading all groups...");
  let groups = #();
  local method load-group(file :: <file-locator>)
          with-open-file(stream = file, direction: #"input")
            let creation-date    = read-line(stream, on-end-of-stream: #f);
            let people           = read-line(stream, on-end-of-stream: #f);
            let description-size = read-line(stream, on-end-of-stream: #f);
            let description      = read-to-end(stream);
            groups := pair(git-parse-group(creation-date,
                                           people, description-size, description),
                           groups);
          end;
        end;
  do-object-files(*groups-directory*, <wiki-group>, load-group);
  log-info("Loaded %d groups from storage", groups.size);
  reverse!(groups)
end;

define function git-parse-group
    (creation-date :: <string>,
     people :: <string>,
     description-size :: <string>,
     description :: <string>)
 => (user :: <wiki-group>)
  let (group-name, owner-name, #rest member-names) = apply(values, split(people, ':'));
  let desc-size = string-to-integer(trim(description-size));
  let description = slice(description, 0, desc-size);
  local method find-user-or-admin (name)
          let user = find-user(name);
          if (user)
            user
          else
            log-error("Owner of group %= not found: %=", group-name, owner-name);
            *admin-user*
          end
        end;
  let owner = find-user-or-admin(owner-name);
  make(<wiki-group>,
       creation-date: git-parse-date(creation-date),
       name: group-name,
       owner: owner,
       members: remove-duplicates(map(find-user-or-admin, member-names)),
       description: description)
end function git-parse-group;

define method store
    (storage :: <storage>, group :: <wiki-group>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  let name :: <string> = group.group-name;
  log-info("Storing group %=", name);

  let group-file = git-group-storage-file(storage, name);
  ensure-directories-exist(group-file);
  store-blob(group-file,
             sformat("%s\n%s:%s:%s\n%d\n%s\n",
                     git-encode-date(group.creation-date),
                     name,
                     group.group-owner.user-name,
                     join(map(user-name, group.group-members), ":"),
                     group.group-description.size,
                     group.group-description));

  let group-path = git-group-path(name);
  call-git(storage, sformat("add \"%s\"", group-path));
  git-commit(storage, group-path, author, comment, meta-data)
end method store;

define method delete
    (storage :: <storage>, group :: <wiki-group>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>)
 => ()
  TODO--delete-group;
end method delete;

define method rename
    (storage :: <storage>, group :: <wiki-group>, new-name :: <string>,
     author :: <wiki-user>, comment :: <string>, meta-data :: <string-table>)
 => (revision :: <string>)
  TODO--rename-group;
  // Need to maintain object IDs that are permanent and monotonically increasing
  // so that renaming an object doesn't require modifying all references.
  // Page references are problematic since users type in the page names.
end method rename;

define function git-group-storage-file
    (storage :: <git-storage>, name :: <string>)
 => (locator :: <file-locator>)
  file-locator(subdirectory-locator(*groups-directory*,
                                    slice(name, 0, $group-prefix-size)),
               name)
end;

define method find-changes
    (storage :: <storage>, type == <wiki-group>,
     #key start :: false-or(<string>),
          name :: false-or(<string>),
          count :: <integer> = $default-list-size)
 => (changes :: <sequence>)
  let path = iff(name, git-group-path(name), $groups-directory-name);
  git-load-changes(storage, path, start | "HEAD", count)
end;

define inline function git-group-path
    (groupname :: <string>) => (path :: <string>)
  sformat("%s/%s/%s",
          $groups-directory-name,
          slice(groupname, 0, $group-prefix-size), groupname)
end;



//// Utilities

/// Implement the find-changes generic for <wiki-object>.  Interleaves the
/// recent changes for pages, users, and groups, in reverse time order. Note
/// that the "name" keyword is not meaningful here so it is left off.
///
define method find-changes
    (storage :: <storage>, type == <wiki-object>,
     #key start :: false-or(<string>),
          count :: <integer> = $default-list-size)
 => (changes :: <sequence>)
  let changes = concatenate(find-changes(storage, <wiki-page>,
                                         start: start, count: count),
                            find-changes(storage, <wiki-user>,
                                         start: start, count: count),
                            find-changes(storage, <wiki-group>,
                                         start: start, count: count));
  slice(sort(changes, test: method (c1, c2)
                              c1.change-date > c2.change-date
                            end),
        0, count)
end method find-changes;


/// Run the given git command with CWD set to the wiki data repository root.
///
// TODO: This should accept a sequence of strings.  IIRC there was a bug
//       which prevented that from working.
define function call-git
    (storage :: <git-storage>, command-fmt :: <string>,
     #key error? :: <boolean> = #t,
          format-args,
          working-directory,
          debug? = #t)
 => (stdout :: <string>,
     stderr :: <string>,
     exit-code :: <integer>)
  let command
    = concatenate(as(<string>, storage.git-executable),
                  " ",
                  iff(format-args,
                      apply(sformat, command-fmt, format-args),
                      command-fmt));
  let cwd = working-directory | storage.git-repository-root;
  log-debug("Running command in cwd = %s: %s",
            as(<string>, cwd),
            command);
  let (exit-code, signal, child, stdout-stream, stderr-stream)
    = run-application(command,
                      asynchronous?: #f,
                      working-directory: cwd,
                      output: #"stream",
                      error: #"stream");
  // TODO:
  // I'm not going to worry about buffering problems this might run into
  // due to massive amounts of output right now, but something more robust
  // will be needed eventually.
  let stdout = read-to-end(stdout-stream);
  let stderr = read-to-end(stderr-stream);
  if (debug?)
    log-debug("exit-code: %s\nstdout:\n%s\nstderr:\n%s",
              exit-code, stdout, stderr);
  end;
  if (error? & (exit-code ~= 0))
    git-error("Error running git command %=:\n"
              "exit code: %=\n"
              "stdout: %s\n"
              "stderr: %s\n",
              command, exit-code, stdout, stderr);
  else
    values(stdout, stderr, exit-code)
  end
end function call-git;

// git show master:<page-path>/content
// Could also use:
//   $ echo git-backend:config.xml | git cat-file --batch
//   b0a7106bff6f0249b9e2ea0e5e4d0f282d5217e1 blob 1436
//   <?xml version="1.0"?>...
// Probably need to use "git log" to get the comment, author, and revision,
// and then use "git cat-file" or "git show" to get the content.

define function git-load-blob
    (storage :: <git-storage>, path :: <string>, revision :: <string>,
     #key working-directory)
 => (blob :: <string>)
  let (stdout, stderr, exit-code)
    = call-git(storage,
               sformat("show \"%s:%s\"", revision, path),
               working-directory: working-directory);
  stdout
end function git-load-blob;

define function store-blob
    (file :: <file-locator>, blob :: <string>)
 => ()
  with-open-file (stream = file, direction: #"output", if-exists: #"overwrite")
    write(stream, blob);
  end;
end function store-blob;

/// Parse the content of the "acls" file into an '<acls>' object.
/// See README.rst for a description of the "acls" file format.
///
define function git-parse-acls
    (blob :: <string>, title :: <string>)
 => (owner :: <wiki-user>, acls :: <acls>)
  local method parse-rule(rule)
          let action = select (rule[0])
                         '+' => $allow;
                         '-' => $deny;
                         otherwise =>
                           git-error("Invalid access spec, %=, in ACLs for page %s",
                                     rule[0], title);
                       end;
          let name = slice(rule, 1, #f);
          let target = select(name by \=)
                         "anyone" => $anyone;
                         "trusted" => $trusted;
                         "owner" => $owner;
                         otherwise =>
                           find-user(name)
                           | find-group(name)
                           | git-error("Invalid name spec, %=, in ACLs for page %s",
                                       name, title);
                       end;
          list(action, target)
        end;
  local method rules (line)
          let rules = map(parse-rule, slice(split(line, ','), 1, #f));
          ~empty?(rules) & rules
        end;
  let lines = split(blob, $newline-regex);
  let owner = find-user(slice(lines[0], "owner: ".size, #f))
              | *admin-user*;
  let view-content   = rules(lines[1]) | $default-access-controls.view-content-rules;
  let modify-content = rules(lines[2]) | $default-access-controls.modify-content-rules;
  let modify-acls    = rules(lines[3]) | $default-access-controls.modify-acls-rules;

  values(owner,
         make(<acls>,
              view-content: view-content,
              modify-content: modify-content,
              modify-acls: modify-acls))
end function git-parse-acls;

define function git-parse-tags
    (blob :: <string>) => (tags :: <sequence>)
  // one tag per line...
  choose(complement(empty?),
         remove-duplicates!(map(trim, split(blob, $newline-regex)),
                            test: \=))
end;

define inline function git-encode-boolean
    (bool :: <boolean>) => (bool :: <string>)
  iff(bool, "T", "F")
end;

define inline function git-parse-boolean
    (string :: <string>) => (bool :: <boolean>)
  iff(string = "T", #t, #f)
end;

define inline function git-encode-date
    (date :: <date>) => (date :: <string>)
  as-iso8601-string(date)
end;

define inline function git-parse-date
    (string :: <string>) => (date :: <date>)
  parse-iso8601-string(string, strict?: #f)
end;

/// Iterate over an object directory hierarchy applying 'fun' to each one in turn.
/// i.e., each page directory, user file, or group file.
///
define function do-object-files
    (root :: <directory-locator>,
     class :: subclass(<wiki-object>),
     fun :: <function>)
 => ()
  local method do-object-dir (directory, name, type)
          log-debug("do-object-dir(%=, %=, %=)", directory, name, type);
          // called once for each file/dir in a prefix directory
          if (class = <wiki-page> & type = #"directory")
            fun(subdirectory-locator(directory, name));
          elseif (type = #"file")
            fun(file-locator(directory, name));
          end;
        end,
        method do-prefix-dir (directory, name, type)
          log-debug("do-prefix-dir(%=, %=, %=)", directory, name, type);
          // called once per prefix directory
          if (type = #"directory")
            do-directory(do-object-dir, subdirectory-locator(directory, name))
          end;
        end;
  do-directory(do-prefix-dir, root);
end function do-object-files;

define function git-commit
    (storage :: <git-storage>, path :: <string>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>,
     #key extra-path :: false-or(<string>))
 => (revision :: <string>)
  %git-commit(storage, path, author, comment, meta-data,
              storage.git-repository-root,
              extra-path)
end;

define function git-user-commit
    (storage :: <git-storage>, path :: <string>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>,
     #key extra-path :: false-or(<string>))
 => (revision :: <string>)
  %git-commit(storage, path, author, comment, meta-data,
              storage.git-user-repository-root,
              extra-path)
end;
 
/// Commit files.  All commits are done with explicit paths so that
/// adds aren't necessary.
/// Arguments:
///   path - The path to commit, relative to repo-root.
///   repo-root - The root directory of the repository.  
///   extra-path - The "to" path for rename operations.  The revision hash
///       returned is for this path.
///
define function %git-commit
    (storage :: <git-storage>, path :: <string>, author :: <wiki-user>,
     comment :: <string>, meta-data :: <string-table>, repo-root :: <directory-locator>,
     extra-path :: false-or(<string>))
 => (revision :: <string>)
  // TODO: Don't want to put the real user email address in the author field,
  //       so probably need to use a (configurable?) fake address of some sort.
  //       Do I need to maintain the git authorsfile also?
  let path-args = iff(extra-path,
                      sformat("\"%s\" \"%s\"", path, extra-path),
                      sformat("\"%s\"", path));

  let comment = trim(comment);
  let (stdout, stderr, exit-code)
    = call-git(storage,
               sformat("commit --author \"%s <%s@opendylan.org>\" -m \"%s\" %s",
                       author.user-real-name,
                       author.user-name,
                       iff(empty?(comment), "-", comment),
                       path-args),
               working-directory: repo-root,
               error?: #f);
  if (subsequence-position(stdout, "nothing to commit"))
    // No changes were made.  Return the head revision.
    trim(call-git(storage,
                  sformat("rev-list --max-count 1 HEAD -- %s", extra-path | path),
                  working-directory: repo-root))
  elseif (exit-code ~= 0)
    log-error("Commit failed:\nexit-code: %s\nstdout: %s\nstderr: %s",
              exit-code, stdout, stderr);
    git-error("Commit failed for path %=.\nexit-code: %s\nstdout: %s\nstderr: %s",
              path, exit-code, stdout, stderr);
  else
    // The stdout from git commit looks like this:
    //     [git-backend 804b716] ...commit comment...
    //     1 files changed, 64 insertions(+), 24 deletions(-)
    let open-bracket = find-key(stdout, curry(\=, '['));
    let close-bracket = find-key(stdout, curry(\=, ']'));
    if (~open-bracket | ~close-bracket)
      git-error("Unexpected output from the 'git commit' command: %=", stdout);
    else
      let parts = split(slice(stdout, open-bracket + 1, close-bracket),
                        $whitespace-regex);
      let short-hash = elt(parts, -1);
      // Unfortunately we have to run another command to get the full hash...
      let hash = trim(call-git(storage,
                               sformat("rev-list --max-count 1 %s -- \"%s\"",
                                       short-hash, extra-path | path),
                               working-directory: repo-root));
      if (~empty?(meta-data))
        let meta-data = meta-data-to-string(meta-data);
        call-git(storage, sformat("notes add -m \"%s\" %s", meta-data, hash));
      end;
      hash
    end
  end
end function %git-commit;

/// Read the git log output and create a sequence of <wiki-change>s.
///
define function git-load-changes
    (storage :: <git-storage>, path :: <string>, revision :: <string>,
     count :: <integer>,
     #key diff? :: <boolean>)
 => (changes :: <sequence>)
  local method hash? (s :: <string>)
          s.size = 40 & every?(rcurry(member?, "0123456789abcdef"), s)
        end;
  local method read-multi-line (lines, end-marker)
          // end-marker is a hash or #f, meaning match any hash.
          iterate loop (meta-data = #(), lines = lines)
            if (empty?(lines)
                | (lines.head = end-marker)
                | (~end-marker & hash?(lines.head)))
              log-debug("meta-data = %=", meta-data);
              values(reverse!(meta-data),
                     lines.tail)
            else
              loop(pair(trim(lines.head), meta-data),
                   lines.tail)
            end
          end
        end;
  // The basic idea here is that each commit is delimited by the commit hash
  // in three places: on first line and after the any multi-line field, namely
  // the comment (%s) and the notes (%N).  That way it can be used to find the
  // end of multi-line fields.
  let (stdout, stderr, exit-code)
    = call-git(storage,
               sformat("log %s -%d --format=%s %s -- \"%s\"",
                       iff(diff?, "-p", ""),
                       count,
                       "%H%n%ci%n%an%n%s%n%H%n%N%H",
                       revision,
                       path));
  iterate loop (lines = as(<list>, split(stdout, "\n")),
                changes = #())
    if (changes.size = count | lines.size <= 4)
      reverse!(changes)
    else
      let hash = lines[0];
      let date = git-parse-date(lines[1]);
      let author = lines[2];
      let (comment, rest) = read-multi-line(lines.tail.tail.tail, hash);
      let (raw-meta-data, rest) = read-multi-line(rest, hash);
      let meta-data = lines-to-meta-data(raw-meta-data);
      let name = element(meta-data, "name", default: "<unknown>");
      let type = element(meta-data, "type", default: "object");
      // The diff output comes after the --format output, and is terminated
      // by the next commit's hash or by EOF.
      let diff = iff(diff?, read-multi-line(rest, #f), "");
      let change = make(<wiki-change>,
                        name: name,
                        type: type,
                        revision: hash,
                        author: author,
                        date: date,
                        comment: join(comment, "\n"),
                        meta-data: meta-data,
                        diff: join(diff, "\n"));
      loop(rest, pair(change, changes))
    end
  end iterate
end function git-load-changes;

define function lines-to-meta-data
    (lines :: <sequence>) => (meta-data :: <string-table>)
  let t = make(<string-table>);
  for (line in lines)
    let (key, val) = apply(values, split(line, '=', count: 2));
    t[key] := val;
  end;
  t
end;

define function meta-data-to-string
    (meta-data :: <string-table>) => (string :: <string>)
  join(map(method (key)
             concatenate(key, "=", meta-data[key])
           end,
           meta-data.key-sequence),
       "\n")
end;

define function tags-to-string
    (tags :: <sequence>) => (string :: <string>)
  join(tags, "\n")
end;

// This function must match string-to-acls
define function acls-to-string
    (page :: <wiki-page>) => (string :: <string>)
  local method rule-to-string (rule :: <rule>) => (string :: <string>)
          let target = rule.rule-target;
          concatenate(select (rule.rule-action)
                        $allow => "+";
                        $deny => "-";
                      end,
                      case
                        target = $anyone => "$any";
                        target = $trusted => "$trusted";
                        target = $owner => "$owner";
                        instance?(target, <wiki-user>) => target.user-name;
                        instance?(target, <wiki-group>) => target.group-name;
                      end)
        end;
  let acls :: <acls> = page.page-access-controls;
  sformat("owner: %s\nview-content: %s\nmodify-content: %s\nmodify-acls: %s",
          page.page-owner.user-name,
          join(acls.view-content-rules, ",", key: rule-to-string),
          join(acls.modify-content-rules, ",", key: rule-to-string),
          join(acls.modify-acls-rules, ",", key: rule-to-string))
end function acls-to-string;

define method file-locator
    (directory :: <directory-locator>, name :: <string>)
 => (file :: <file-locator>)
  merge-locators(as(<file-locator>, name), directory)
end;


