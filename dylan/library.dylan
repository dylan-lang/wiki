Module: dylan-user
Author: turbo24prg, Carl Gay

define library wiki
  use base64;
  use collection-extensions,
    import: { sequence-diff };
  use collections,
    import: { set, table-extensions };
  use command-line-parser;
  use common-dylan,
    import: { common-extensions };
  use dsp;
  use dylan;
  use graphviz-renderer;
  use http-common;
  use io;
  use koala;
  use network;
  use smtp-client;
  use strings;
  use string-extensions;
  use system,
    import: {
      date,
      file-system,
      locators,
      operating-system,
      threads
      };
  use regular-expressions;
  use uri;
  use web-framework;
  use xml-parser;
  use xml-rpc-client;

/* for the monday parser, currently unused
  use grammar;
  use simple-parser;
  use regular;
*/

  use uncommon-dylan;

  export
    wiki,
    %wiki;
end library wiki;

/// External module
///
define module wiki
  create
    add-wiki-responders;
end;

/// Internal module, for test suite
///
define module %wiki
  use base64;
  use changes,
    prefix: "wf/",
    exclude: { <uri> };
  use command-line-parser;
  use common-extensions,
    exclude: { format-to-string };
  use date;
  use dsp;
  use dylan;
  use file-system;
  use format;
  use format-out;
  use http-common,
    exclude: { remove-attribute };
  use koala;
  use locators,
    exclude: { <http-server>, <url> };
  use operating-system;
  use permission;
  use sequence-diff;
  use set,
    import: { <set> };
  use simple-xml;
  use smtp-client;
  use streams;
  use strings,
    import: { trim };
  use substring-search;
  use table-extensions,
    rename: { table => make-table };
  use threads;
  use regular-expressions;
  use uncommon-dylan;
  use uri;
  use web-framework,
    prefix: "wf/";
  use wiki;
  use xml-parser,
    prefix: "xml/";
  use xml-rpc-client;

  // for the monday parser, currently unused
/*
  use simple-parser;
  use grammar;
  use simple-lexical-scanner;
*/

  use graphviz-renderer,
    prefix: "gvr/";

  export
    // ACLs
    <acls>,
    $view-content, $modify-content, $modify-acls,
    $anyone, $trusted, $owner,
    $default-access-controls,
    view-content-rules,
    modify-content-rules,
    modify-acls-rules,
    <rule>,
    rule-action,
    rule-target,
    has-permission?;

  // Storage
  export
    *storage*,
    <storage>,
    <git-storage>,
    <storage-error>,
    initialize-storage-for-reads,
    initialize-storage-for-writes,
    load,
    load-all,
    find-or-load-pages-with-tags,
    store,
    delete,
    rename,
    standard-meta-data;
    
  // Groups
  export
    *groups*, $group-lock,
    <wiki-group>,
    group-name,
    group-owner,
    group-members,
    group-description;

  // Pages
  export
    *pages*, $page-lock,
    <wiki-page>,
    page-title,
    page-content,
    page-comment,
    page-owner,
    page-author,
    page-tags,
    page-access-controls,
    page-revision;

  // Users
  export
    *users*, $user-lock,
    <wiki-user>,
    user-real-name,
    user-name,
    user-password,
    user-email,
    administrator?,
    user-activation-key,
    user-activated?,
    *admin-user*;

end module %wiki;

