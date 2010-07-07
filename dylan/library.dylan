Module: dylan-user
Author: turbo24prg

define library wiki
  use collection-extensions,
    import: { sequence-diff };
  use collections;
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
    import: { locators, threads, date, file-system };
  use regular-expressions;
  use uri;
  use web-framework;
  use xml-parser;
  use xml-rpc-client;

  use source-location;
  use grammar;
  use simple-parser;
  use regular;

  use uncommon-dylan;

  export
    wiki,
    wiki-internal;   // for the test suite
end library wiki;

define module wiki
  create
    add-wiki-responders;
end;

define module wiki-internal
  use changes,
    rename: { published => date-published,
              label => category-label },
    exclude: { <uri> };
  use sequence-diff;
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
  use permission;
  use simple-xml;
  use smtp-client;
  use storage;
  use streams;
  use strings,
    import: { trim };
  use substring-search;
  use table-extensions;
  use threads;
  use regular-expressions;
  use uncommon-dylan;
  use uri;
  use users;
  use web-framework,
    prefix: "wf/",
    exclude: { slot-type };
  use wiki;
  use xml-parser,
    prefix: "xml/";
  use xml-rpc-client;

  // for the parser
  use simple-parser;
  use source-location;
  use source-location-rangemap;
  use grammar;
  use simple-lexical-scanner;

  use graphviz-renderer,
    prefix: "gvr/";

  export
    // ACLs
    <acls>,
    $view-content, $modify-content, $modify-acls,
    $anyone, $trusted, $owner,
    $default-access-controls,
    has-permission?,
    
    <wiki-user>,
    <wiki-page>;

end module wiki-internal;

